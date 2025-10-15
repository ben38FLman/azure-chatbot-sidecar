const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config();

const LLMService = require('./services/llmService');
const ChatService = require('./services/chatService');

const app = express();
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';

// Initialize services
const llmService = new LLMService();
const chatService = new ChatService(llmService);

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
  max: NODE_ENV === 'production' ? 100 : 1000, // limit each IP to 100 requests per windowMs in prod
  message: {
    error: 'Too many requests from this IP, please try again later.',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(limiter);

// Middleware
app.use(compression());
app.use(cors({
  origin: NODE_ENV === 'production' ? 
    ['https://your-domain.com'] : // Replace with your actual domain
    ['http://localhost:3000', 'http://localhost:3001'],
  credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(morgan(NODE_ENV === 'production' ? 'combined' : 'dev'));

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    const llmHealth = await llmService.healthCheck();
    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0',
      environment: NODE_ENV,
      services: {
        llm: llmHealth,
        api: 'healthy'
      },
      uptime: process.uptime()
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message,
      services: {
        llm: 'unhealthy',
        api: 'healthy'
      }
    });
  }
});

// Chat endpoint
app.post('/api/chat', 
  [
    body('message')
      .trim()
      .isLength({ min: 1, max: 4000 })
      .withMessage('Message must be between 1 and 4000 characters'),
    body('conversationId')
      .optional()
      .isUUID()
      .withMessage('Conversation ID must be a valid UUID'),
    body('context')
      .optional()
      .isObject()
      .withMessage('Context must be an object')
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

      const { message, conversationId = uuidv4(), context = {} } = req.body;
      
      // Generate response using chat service
      const response = await chatService.generateResponse({
        message,
        conversationId,
        context
      });

      res.json({
        success: true,
        conversationId,
        response: response.text,
        timestamp: new Date().toISOString(),
        metadata: {
          model: response.model,
          tokensUsed: response.tokensUsed,
          responseTime: response.responseTime
        }
      });

    } catch (error) {
      console.error('Chat endpoint error:', error);
      res.status(500).json({
        error: 'Failed to generate response',
        message: NODE_ENV === 'development' ? error.message : 'Internal server error',
        timestamp: new Date().toISOString()
      });
    }
  }
);

// Get conversation history
app.get('/api/conversations/:conversationId', async (req, res) => {
  try {
    const { conversationId } = req.params;
    
    if (!conversationId || !conversationId.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i)) {
      return res.status(400).json({
        error: 'Invalid conversation ID format'
      });
    }

    const history = await chatService.getConversationHistory(conversationId);
    
    res.json({
      success: true,
      conversationId,
      messages: history,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Get conversation error:', error);
    res.status(500).json({
      error: 'Failed to retrieve conversation',
      message: NODE_ENV === 'development' ? error.message : 'Internal server error'
    });
  }
});

// LLM models endpoint
app.get('/api/models', async (req, res) => {
  try {
    const models = await llmService.getAvailableModels();
    res.json({
      success: true,
      models,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Models endpoint error:', error);
    res.status(500).json({
      error: 'Failed to retrieve models',
      message: NODE_ENV === 'development' ? error.message : 'Internal server error'
    });
  }
});

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
  
  // Test LLM connection on startup
  try {
    await llmService.healthCheck();
    console.log('✅ LLM service connection established');
  } catch (error) {
    console.warn('⚠️  LLM service not immediately available:', error.message);
    console.log('🔄 Will retry connections automatically...');
  }
});

module.exports = app;