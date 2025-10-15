const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const axios = require('axios');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;
const NODE_ENV = process.env.NODE_ENV || 'development';

// AI Sidecar Configuration (following Microsoft's pattern)
const AI_SIDECAR_ENDPOINT = process.env.AI_SIDECAR_ENDPOINT || 'http://localhost:11434/v1/chat/completions';
const AI_MODEL_NAME = process.env.AI_MODEL_NAME || 'phi-4';

console.log('🤖 Starting Chatbot with AI Sidecar');
console.log(`📍 AI Sidecar Endpoint: ${AI_SIDECAR_ENDPOINT}`);
console.log(`🧠 AI Model: ${AI_MODEL_NAME}`);

// Configure axios for AI sidecar requests
const aiClient = axios.create({
  baseURL: AI_SIDECAR_ENDPOINT,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: NODE_ENV === 'production' ? 50 : 1000,
  message: {
    error: 'Too many requests from this IP, please try again later.',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(limiter);

// Middleware
app.use(cors({
  origin: NODE_ENV === 'production' ? 
    ['https://your-domain.com'] : 
    ['http://localhost:8080', 'http://localhost:3000'],
  credentials: true
}));
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true, limit: '5mb' }));
app.use(morgan(NODE_ENV === 'production' ? 'combined' : 'dev'));

// Serve static files (for the chat UI)
app.use(express.static('public'));

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    // Test AI sidecar connectivity
    const sidecarHealth = await testSidecarConnection();
    
    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
      environment: NODE_ENV,
      services: {
        api: 'healthy',
        aiSidecar: sidecarHealth ? 'healthy' : 'unavailable'
      },
      uptime: process.uptime(),
      aiEndpoint: AI_SIDECAR_ENDPOINT
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message,
      services: {
        api: 'healthy',
        aiSidecar: 'unhealthy'
      }
    });
  }
});

// Chat endpoint (following Microsoft's OpenAI-compatible pattern)
app.post('/api/chat', 
  [
    body('message')
      .trim()
      .isLength({ min: 1, max: 2000 })
      .withMessage('Message must be between 1 and 2000 characters'),
    body('conversationId')
      .optional()
      .isUUID()
      .withMessage('Conversation ID must be a valid UUID')
  ],
  async (req, res) => {
    try {
      // Validate request
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          error: 'Validation failed',
          details: errors.array()
        });
      }

      const { message, conversationId = uuidv4() } = req.body;
      
      // Prepare request for AI sidecar (OpenAI-compatible format)
      const sidecarRequest = {
        messages: [
          {
            role: "system",
            content: "You are a helpful AI assistant. Be concise, accurate, and friendly in your responses."
          },
          {
            role: "user",
            content: message
          }
        ],
        stream: false,
        cache_prompt: false,
        n_predict: 1024
      };

      console.log(`💬 Processing chat request for conversation: ${conversationId}`);

      // Send request to AI sidecar
      const startTime = Date.now();
      const sidecarResponse = await aiClient.post('', sidecarRequest);
      const responseTime = Date.now() - startTime;

      // Extract response from sidecar (following OpenAI format)
      let aiResponse = '';
      if (sidecarResponse.data && sidecarResponse.data.choices && sidecarResponse.data.choices.length > 0) {
        aiResponse = sidecarResponse.data.choices[0].message?.content || 'No response generated';
      } else {
        aiResponse = 'Unable to generate response';
      }

      res.json({
        success: true,
        conversationId,
        response: aiResponse,
        timestamp: new Date().toISOString(),
        metadata: {
          model: AI_MODEL_NAME,
          responseTime: responseTime,
          endpoint: 'sidecar'
        }
      });

    } catch (error) {
      console.error('Chat endpoint error:', error.message);
      
      // Provide fallback response if sidecar is unavailable
      if (error.code === 'ECONNREFUSED' || error.code === 'TIMEOUT') {
        res.json({
          success: true,
          conversationId: req.body.conversationId || uuidv4(),
          response: "I'm sorry, the AI service is currently unavailable. Please try again later or contact support if the issue persists.",
          timestamp: new Date().toISOString(),
          metadata: {
            model: 'fallback',
            responseTime: 0,
            endpoint: 'fallback',
            error: 'sidecar_unavailable'
          }
        });
      } else {
        res.status(500).json({
          error: 'Failed to generate response',
          message: NODE_ENV === 'development' ? error.message : 'Internal server error',
          timestamp: new Date().toISOString()
        });
      }
    }
  }
);

// Test sidecar connection
async function testSidecarConnection() {
  try {
    const testRequest = {
      messages: [
        {
          role: "user",
          content: "Hello"
        }
      ],
      stream: false,
      n_predict: 10
    };

    const response = await aiClient.post('', testRequest, { timeout: 5000 });
    return response.status === 200;
  } catch (error) {
    console.warn('Sidecar connection test failed:', error.message);
    return false;
  }
}

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: NODE_ENV === 'development' ? err.message : 'Something went wrong',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    path: req.originalUrl,
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
    process.exit(0);
  });
});

// Start server
const server = app.listen(PORT, '0.0.0.0', async () => {
  console.log(`🚀 Chatbot API server running on port ${PORT}`);
  console.log(`🌍 Environment: ${NODE_ENV}`);
  console.log(`🔗 Health check: http://localhost:${PORT}/health`);
  console.log(`💬 Chat endpoint: http://localhost:${PORT}/api/chat`);
  
  // Test sidecar connection on startup
  console.log('🔄 Testing AI sidecar connection...');
  const sidecarAvailable = await testSidecarConnection();
  if (sidecarAvailable) {
    console.log('✅ AI sidecar connection established');
  } else {
    console.warn('⚠️  AI sidecar not immediately available (this is normal during initial deployment)');
    console.log('📝 Remember to add the Phi-4 sidecar extension via Azure Portal after deployment');
  }
});

module.exports = app;