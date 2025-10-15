const axios = require('axios');

class LLMService {
  constructor() {
    this.baseUrl = process.env.LLM_ENDPOINT || 'http://localhost:11434';
    this.model = process.env.LLM_MODEL || 'tinyllama:latest';
    this.timeout = parseInt(process.env.LLM_TIMEOUT) || 30000; // 30 seconds
    this.maxRetries = parseInt(process.env.LLM_MAX_RETRIES) || 3;
    
    // Configure axios instance
    this.client = axios.create({
      baseURL: this.baseUrl,
      timeout: this.timeout,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Add response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error) => {
        console.error('LLM Service Error:', {
          message: error.message,
          status: error.response?.status,
          data: error.response?.data,
          url: error.config?.url
        });
        return Promise.reject(error);
      }
    );
  }

  /**
   * Check if the LLM service is healthy
   * @returns {Promise<string>} Health status
   */
  async healthCheck() {
    try {
      const response = await this.client.get('/api/tags', { timeout: 5000 });
      return 'healthy';
    } catch (error) {
      throw new Error(`LLM service unhealthy: ${error.message}`);
    }
  }

  /**
   * Get available models from the LLM service
   * @returns {Promise<Array>} List of available models
   */
  async getAvailableModels() {
    try {
      const response = await this.client.get('/api/tags');
      return response.data.models || [];
    } catch (error) {
      console.error('Failed to get available models:', error.message);
      return [];
    }
  }

  /**
   * Generate a response from the LLM
   * @param {string} prompt - The input prompt
   * @param {Object} options - Additional options
   * @returns {Promise<Object>} Response object
   */
  async generateResponse(prompt, options = {}) {
    const startTime = Date.now();
    
    const payload = {
      model: options.model || this.model,
      prompt: prompt,
      stream: false,
      options: {
        temperature: options.temperature || 0.7,
        max_tokens: options.maxTokens || 1000,
        top_p: options.topP || 0.9,
        frequency_penalty: options.frequencyPenalty || 0.0,
        presence_penalty: options.presencePenalty || 0.0,
        ...options.modelOptions
      }
    };

    let lastError;
    
    // Retry logic
    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        console.log(`LLM Request attempt ${attempt}/${this.maxRetries}:`, {
          model: payload.model,
          promptLength: prompt.length,
          temperature: payload.options.temperature
        });

        const response = await this.client.post('/api/generate', payload);
        const responseTime = Date.now() - startTime;

        const result = {
          text: response.data.response || '',
          model: payload.model,
          tokensUsed: this._estimateTokens(prompt + response.data.response),
          responseTime: responseTime,
          metadata: {
            attempt: attempt,
            totalTime: response.data.total_duration,
            loadTime: response.data.load_duration,
            promptEvalCount: response.data.prompt_eval_count,
            evalCount: response.data.eval_count
          }
        };

        console.log(`LLM Response successful:`, {
          responseLength: result.text.length,
          tokensUsed: result.tokensUsed,
          responseTime: responseTime + 'ms'
        });

        return result;

      } catch (error) {
        lastError = error;
        console.warn(`LLM Request attempt ${attempt} failed:`, error.message);
        
        if (attempt < this.maxRetries) {
          const delay = Math.min(1000 * Math.pow(2, attempt - 1), 5000); // Exponential backoff, max 5s
          console.log(`Retrying in ${delay}ms...`);
          await this._sleep(delay);
        }
      }
    }

    // If all retries failed
    throw new Error(`LLM service failed after ${this.maxRetries} attempts: ${lastError.message}`);
  }

  /**
   * Generate a chat response with conversation context
   * @param {Array} messages - Array of message objects
   * @param {Object} options - Additional options
   * @returns {Promise<Object>} Response object
   */
  async generateChatResponse(messages, options = {}) {
    // Convert messages to a single prompt
    const prompt = this._formatMessagesAsPrompt(messages);
    return await this.generateResponse(prompt, options);
  }

  /**
   * Check if a specific model is available
   * @param {string} modelName - Name of the model to check
   * @returns {Promise<boolean>} True if model is available
   */
  async isModelAvailable(modelName) {
    try {
      const models = await this.getAvailableModels();
      return models.some(model => model.name === modelName);
    } catch (error) {
      console.error('Failed to check model availability:', error.message);
      return false;
    }
  }

  /**
   * Pull/download a model
   * @param {string} modelName - Name of the model to pull
   * @returns {Promise<boolean>} True if successful
   */
  async pullModel(modelName) {
    try {
      console.log(`Pulling model: ${modelName}`);
      await this.client.post('/api/pull', { 
        name: modelName,
        stream: false 
      }, { 
        timeout: 300000 // 5 minutes for model download
      });
      
      console.log(`Model ${modelName} pulled successfully`);
      return true;
    } catch (error) {
      console.error(`Failed to pull model ${modelName}:`, error.message);
      return false;
    }
  }

  /**
   * Format messages array as a single prompt
   * @private
   */
  _formatMessagesAsPrompt(messages) {
    return messages.map(msg => {
      const role = msg.role === 'user' ? 'Human' : 'Assistant';
      return `${role}: ${msg.content}`;
    }).join('\n\n') + '\n\nAssistant:';
  }

  /**
   * Simple token estimation (rough approximation)
   * @private
   */
  _estimateTokens(text) {
    // Rough estimation: ~4 characters per token for English text
    return Math.ceil(text.length / 4);
  }

  /**
   * Sleep utility for retry delays
   * @private
   */
  _sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = LLMService;