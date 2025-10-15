const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const axios = require('axios');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
// Configuration - Use 127.0.0.1 instead of 'localhost' to avoid IPv6 resolution issues
// Following Azure-Samples/ai-slm-in-app-service-sidecar pattern
const SIDECAR_ENDPOINT = 'http://127.0.0.1:11434';

// Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://cdnjs.cloudflare.com"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'"]
    }
  }
}));
app.use(cors());
app.use(compression());
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(express.static('public'));

// In-memory store for chat sessions (use Redis in production)
const chatSessions = new Map();

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    sidecarEndpoint: SIDECAR_ENDPOINT
  });
});

// Sidecar health check
app.get('/api/sidecar/health', async (req, res) => {
  try {
    const response = await axios.get(`${SIDECAR_ENDPOINT}/api/tags`, {
      timeout: 5000
    });
    res.status(200).json({
      status: 'healthy',
      sidecarStatus: 'connected',
      availableModels: response.data.models || [],
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Sidecar health check failed:', error.message);
    res.status(503).json({
      status: 'unhealthy',
      sidecarStatus: 'disconnected',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Create new chat session
app.post('/api/chat/sessions', (req, res) => {
  const sessionId = uuidv4();
  const session = {
    id: sessionId,
    createdAt: new Date().toISOString(),
    messages: [],
    title: req.body.title || 'New Chat Session'
  };
  
  chatSessions.set(sessionId, session);
  
  res.status(201).json({
    sessionId,
    message: 'Chat session created successfully',
    session
  });
});

// Get chat session
app.get('/api/chat/sessions/:sessionId', (req, res) => {
  const { sessionId } = req.params;
  const session = chatSessions.get(sessionId);
  
  if (!session) {
    return res.status(404).json({
      error: 'Chat session not found',
      sessionId
    });
  }
  
  res.json(session);
});

// List all chat sessions
app.get('/api/chat/sessions', (req, res) => {
  const sessions = Array.from(chatSessions.values())
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
    .slice(0, 20); // Limit to last 20 sessions
  
  res.json({
    sessions,
    total: chatSessions.size
  });
});

// Send message to chat
app.post('/api/chat/sessions/:sessionId/messages', async (req, res) => {
  const { sessionId } = req.params;
  const { message, model = 'phi4' } = req.body;
  
  if (!message || !message.trim()) {
    return res.status(400).json({
      error: 'Message content is required'
    });
  }
  
  const session = chatSessions.get(sessionId);
  if (!session) {
    return res.status(404).json({
      error: 'Chat session not found',
      sessionId
    });
  }
  
  // Add user message to session
  const userMessage = {
    id: uuidv4(),
    role: 'user',
    content: message.trim(),
    timestamp: new Date().toISOString()
  };
  session.messages.push(userMessage);
  
  try {
    // Format conversation for OpenAI-compatible API (following Azure-Samples pattern)
    const messages = [
      { role: 'system', content: 'You are a helpful assistant.' }
    ];
    
    // Add conversation history to messages (keep last 10 for context)
    session.messages.slice(-10).forEach(msg => {
      messages.push({
        role: msg.role,
        content: msg.content
      });
    });
    
    // Add current user message
    messages.push({
      role: 'user',
      content: message
    });
    
    // Call the sidecar AI model using OpenAI-compatible endpoint
    console.log(`Calling sidecar at ${SIDECAR_ENDPOINT}/v1/chat/completions`);
    const aiResponse = await axios.post(`${SIDECAR_ENDPOINT}/v1/chat/completions`, {
      messages: messages,
      stream: false,
      cache_prompt: false,
      n_predict: 2048
    }, {
      timeout: 30000, // 30 second timeout
      headers: {
        'Content-Type': 'application/json'
      }
    });
    
    // Extract response content (OpenAI format)
    const aiContent = aiResponse.data.choices?.[0]?.message?.content || 'I apologize, but I was unable to generate a response.';
    
    // Add AI response to session
    const aiMessage = {
      id: uuidv4(),
      role: 'assistant',
      content: aiContent.trim(),
      timestamp: new Date().toISOString(),
      model: model,
      tokens: aiResponse.data.eval_count || 0
    };
    session.messages.push(aiMessage);
    
    // Update session
    chatSessions.set(sessionId, session);
    
    res.json({
      userMessage,
      aiMessage,
      sessionId,
      messageCount: session.messages.length
    });
    
  } catch (error) {
    console.error('Error calling sidecar AI:', error.message);
    
    // Add error response to session
    const errorMessage = {
      id: uuidv4(),
      role: 'assistant',
      content: 'I apologize, but I\'m experiencing technical difficulties. Please try again in a moment.',
      timestamp: new Date().toISOString(),
      error: true,
      errorDetails: error.message
    };
    session.messages.push(errorMessage);
    chatSessions.set(sessionId, session);
    
    res.status(500).json({
      error: 'Failed to get AI response',
      details: error.message,
      userMessage,
      errorMessage,
      sessionId
    });
  }
});

// Delete chat session
app.delete('/api/chat/sessions/:sessionId', (req, res) => {
  const { sessionId } = req.params;
  const deleted = chatSessions.delete(sessionId);
  
  if (!deleted) {
    return res.status(404).json({
      error: 'Chat session not found',
      sessionId
    });
  }
  
  res.json({
    message: 'Chat session deleted successfully',
    sessionId
  });
});

// List available AI models
app.get('/api/models', async (req, res) => {
  try {
    const response = await axios.get(`${SIDECAR_ENDPOINT}/api/tags`, {
      timeout: 5000
    });
    
    res.json({
      models: response.data.models || [],
      sidecarEndpoint: SIDECAR_ENDPOINT,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Failed to fetch models:', error.message);
    res.status(503).json({
      error: 'Unable to fetch available models',
      details: error.message,
      sidecarEndpoint: SIDECAR_ENDPOINT
    });
  }
});

// API info endpoint
app.get('/api/info', (req, res) => {
  res.json({
    name: 'Chatbot Sidecar App',
    version: '1.0.0',
    description: 'AI Chatbot with Phi-4 Sidecar Extension',
    endpoints: {
      health: '/health',
      sidecarHealth: '/api/sidecar/health',
      createSession: 'POST /api/chat/sessions',
      getSession: 'GET /api/chat/sessions/:sessionId',
      listSessions: 'GET /api/chat/sessions',
      sendMessage: 'POST /api/chat/sessions/:sessionId/messages',
      deleteSession: 'DELETE /api/chat/sessions/:sessionId',
      listModels: 'GET /api/models'
    },
    environment: process.env.NODE_ENV || 'development',
    sidecarEndpoint: SIDECAR_ENDPOINT,
    timestamp: new Date().toISOString()
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: err.message,
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Route not found',
    path: req.path,
    method: req.method,
    timestamp: new Date().toISOString()
  });
});

// Start server
const server = app.listen(PORT, () => {
  console.log(`🚀 Chatbot Sidecar App running on port ${PORT}`);
  console.log(`📍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🤖 Sidecar endpoint: ${SIDECAR_ENDPOINT}`);
  console.log(`🌐 Health check: http://localhost:${PORT}/health`);
  console.log(`📖 API info: http://localhost:${PORT}/api/info`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM. Shutting down gracefully...');
  server.close(() => {
    console.log('Server closed.');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('Received SIGINT. Shutting down gracefully...');
  server.close(() => {
    console.log('Server closed.');
    process.exit(0);
  });
});

module.exports = app;