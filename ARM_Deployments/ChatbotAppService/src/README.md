# Node.js Chatbot with LLM Sidecar

## Overview
This is a Node.js chatbot service that integrates with a local LLM (Large Language Model) running in a sidecar container using Ollama.

## Architecture
- **Main App**: Express.js API server (Port 3000)
- **LLM Sidecar**: Ollama service with TinyLlama model (Port 11434)
- **Communication**: HTTP requests between containers

## Local Development

### Prerequisites
- Node.js 18+ 
- Docker and Docker Compose
- Git

### Quick Start

1. **Clone and setup**
   ```bash
   cd src
   npm install
   ```

2. **Environment setup**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Run with Docker Compose**
   ```bash
   docker-compose up -d
   ```

4. **Test the API**
   ```bash
   # Health check
   curl http://localhost:3000/health

   # Chat endpoint
   curl -X POST http://localhost:3000/api/chat \
     -H "Content-Type: application/json" \
     -d '{"message": "Hello, how are you?"}'
   ```

## API Endpoints

### Health Check
```
GET /health
```
Returns service health status and LLM connectivity.

### Chat
```
POST /api/chat
Content-Type: application/json

{
  "message": "Your message here",
  "conversationId": "optional-uuid",
  "context": {
    "temperature": 0.7,
    "maxTokens": 1000
  }
}
```

### Get Conversation History
```
GET /api/conversations/{conversationId}
```

### Available Models
```
GET /api/models
```

## Configuration

### Environment Variables
- `NODE_ENV`: Environment (development/production)
- `PORT`: API server port (default: 3000)
- `LLM_ENDPOINT`: Ollama service URL (default: http://localhost:11434)
- `LLM_MODEL`: Model name (default: tinyllama:latest)
- `LLM_TIMEOUT`: Request timeout in ms (default: 30000)
- `MAX_CONVERSATION_LENGTH`: Max messages per conversation (default: 20)

### LLM Configuration
The service uses Ollama with TinyLlama model by default. You can:
- Change the model in environment variables
- Pull additional models via the Ollama API
- Adjust temperature and other parameters per request

## Features

### Chat Service
- Conversation memory management
- Message history tracking
- Automatic conversation cleanup
- Context-aware responses

### LLM Service
- Health monitoring
- Retry logic with exponential backoff
- Multiple model support
- Token usage estimation

### Security
- Rate limiting
- Input validation
- CORS protection
- Helmet security headers
- Request size limits

### Monitoring
- Health check endpoint
- Request/response logging
- Error tracking
- Performance metrics

## Production Deployment

### Azure App Service
Deploy using the provided Bicep template:
```bash
az deployment group create \
  --resource-group your-rg \
  --template-file ChatbotAppService.bicep \
  --parameters @ChatbotAppService.bicepparam
```

### Environment-Specific Configuration
- **Development**: Relaxed rate limits, detailed logging
- **Staging**: Production-like settings with debug info
- **Production**: Strict limits, secure configuration

## Troubleshooting

### Common Issues

1. **LLM Service Unavailable**
   - Check if Ollama container is running
   - Verify network connectivity between containers
   - Check if the model is downloaded

2. **Slow Responses**
   - Increase LLM_TIMEOUT
   - Use a smaller/faster model
   - Check container resources

3. **Memory Issues**
   - Reduce MAX_CONVERSATION_LENGTH
   - Implement persistent storage for conversations
   - Monitor container memory usage

### Logs
```bash
# View application logs
docker-compose logs chatbot-app

# View Ollama logs  
docker-compose logs ollama-sidecar

# Follow logs in real-time
docker-compose logs -f
```

## Development

### Project Structure
```
src/
├── server.js              # Main Express server
├── package.json            # Dependencies and scripts
├── services/
│   ├── llmService.js      # LLM integration service
│   └── chatService.js     # Chat logic and conversation management
├── Dockerfile             # Container definition
└── docker-compose.yml     # Local development setup
```

### Adding Features
1. **New Endpoints**: Add routes in `server.js`
2. **LLM Features**: Extend `llmService.js`
3. **Chat Logic**: Modify `chatService.js`
4. **Middleware**: Add Express middleware as needed

### Testing
```bash
npm test           # Run tests
npm run lint       # Check code style
npm run dev        # Development with auto-reload
```

## Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License
MIT License - see LICENSE file for details.