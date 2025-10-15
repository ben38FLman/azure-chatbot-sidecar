class ChatService {
  constructor(llmService) {
    this.llmService = llmService;
    this.conversations = new Map(); // In-memory storage (use Redis/DB in production)
    this.maxConversationLength = parseInt(process.env.MAX_CONVERSATION_LENGTH) || 20;
    this.systemPrompt = process.env.SYSTEM_PROMPT || this._getDefaultSystemPrompt();
  }

  /**
   * Generate a response for a chat message
   * @param {Object} params - Chat parameters
   * @returns {Promise<Object>} Chat response
   */
  async generateResponse({ message, conversationId, context = {} }) {
    try {
      // Get or create conversation
      let conversation = this.conversations.get(conversationId) || {
        id: conversationId,
        messages: [],
        createdAt: new Date(),
        lastActivity: new Date(),
        metadata: context
      };

      // Add user message to conversation
      const userMessage = {
        role: 'user',
        content: message,
        timestamp: new Date()
      };
      conversation.messages.push(userMessage);

      // Trim conversation if too long
      if (conversation.messages.length > this.maxConversationLength) {
        conversation.messages = conversation.messages.slice(-this.maxConversationLength);
      }

      // Prepare messages for LLM (include system prompt)
      const messages = [
        { role: 'system', content: this.systemPrompt },
        ...conversation.messages
      ];

      // Generate response from LLM
      const llmResponse = await this.llmService.generateChatResponse(messages, {
        temperature: context.temperature || 0.7,
        maxTokens: context.maxTokens || 1000,
        model: context.model
      });

      // Add assistant response to conversation
      const assistantMessage = {
        role: 'assistant',
        content: llmResponse.text,
        timestamp: new Date(),
        metadata: llmResponse.metadata
      };
      conversation.messages.push(assistantMessage);

      // Update conversation metadata
      conversation.lastActivity = new Date();
      this.conversations.set(conversationId, conversation);

      // Clean up old conversations periodically
      this._cleanupOldConversations();

      return {
        text: llmResponse.text,
        model: llmResponse.model,
        tokensUsed: llmResponse.tokensUsed,
        responseTime: llmResponse.responseTime,
        conversationLength: conversation.messages.length
      };

    } catch (error) {
      console.error('Chat service error:', error);
      throw new Error(`Failed to generate chat response: ${error.message}`);
    }
  }

  /**
   * Get conversation history
   * @param {string} conversationId - Conversation ID
   * @returns {Array} Array of messages
   */
  async getConversationHistory(conversationId) {
    const conversation = this.conversations.get(conversationId);
    return conversation ? conversation.messages : [];
  }

  /**
   * Clear conversation history
   * @param {string} conversationId - Conversation ID
   * @returns {boolean} Success status
   */
  async clearConversation(conversationId) {
    return this.conversations.delete(conversationId);
  }

  /**
   * Get all active conversations
   * @returns {Array} Array of conversation summaries
   */
  getActiveConversations() {
    const conversations = [];
    for (const [id, conv] of this.conversations) {
      conversations.push({
        id,
        messageCount: conv.messages.length,
        createdAt: conv.createdAt,
        lastActivity: conv.lastActivity,
        metadata: conv.metadata
      });
    }
    return conversations.sort((a, b) => b.lastActivity - a.lastActivity);
  }

  /**
   * Get conversation statistics
   * @returns {Object} Statistics object
   */
  getStatistics() {
    const conversations = Array.from(this.conversations.values());
    const totalMessages = conversations.reduce((sum, conv) => sum + conv.messages.length, 0);
    const averageLength = conversations.length > 0 ? totalMessages / conversations.length : 0;

    return {
      totalConversations: conversations.length,
      totalMessages,
      averageConversationLength: Math.round(averageLength * 100) / 100,
      oldestConversation: conversations.length > 0 
        ? Math.min(...conversations.map(c => c.createdAt)) 
        : null,
      newestConversation: conversations.length > 0 
        ? Math.max(...conversations.map(c => c.lastActivity)) 
        : null
    };
  }

  /**
   * Update system prompt
   * @param {string} newPrompt - New system prompt
   */
  updateSystemPrompt(newPrompt) {
    this.systemPrompt = newPrompt;
    console.log('System prompt updated');
  }

  /**
   * Get default system prompt
   * @private
   */
  _getDefaultSystemPrompt() {
    return `You are a helpful AI assistant. You are knowledgeable, friendly, and concise in your responses. 

Key guidelines:
- Provide accurate and helpful information
- Be conversational and engaging
- Keep responses focused and relevant
- If you're unsure about something, say so
- Be respectful and professional
- For technical questions, provide clear explanations
- If asked about harmful or inappropriate topics, politely decline

Current date: ${new Date().toLocaleDateString()}`;
  }

  /**
   * Clean up old conversations (older than 24 hours)
   * @private
   */
  _cleanupOldConversations() {
    const maxAge = 24 * 60 * 60 * 1000; // 24 hours
    const cutoff = Date.now() - maxAge;
    
    let cleaned = 0;
    for (const [id, conv] of this.conversations) {
      if (conv.lastActivity.getTime() < cutoff) {
        this.conversations.delete(id);
        cleaned++;
      }
    }

    if (cleaned > 0) {
      console.log(`Cleaned up ${cleaned} old conversations`);
    }
  }

  /**
   * Export conversation data (for backup/analysis)
   * @param {string} conversationId - Optional specific conversation ID
   * @returns {Object} Conversation data
   */
  exportConversations(conversationId = null) {
    if (conversationId) {
      return this.conversations.get(conversationId) || null;
    }
    
    return Object.fromEntries(this.conversations);
  }

  /**
   * Import conversation data (for restore)
   * @param {Object} data - Conversation data to import
   * @returns {number} Number of conversations imported
   */
  importConversations(data) {
    let imported = 0;
    
    for (const [id, conv] of Object.entries(data)) {
      // Validate conversation structure
      if (conv.messages && Array.isArray(conv.messages)) {
        // Convert date strings back to Date objects
        conv.createdAt = new Date(conv.createdAt);
        conv.lastActivity = new Date(conv.lastActivity);
        conv.messages.forEach(msg => {
          msg.timestamp = new Date(msg.timestamp);
        });
        
        this.conversations.set(id, conv);
        imported++;
      }
    }
    
    console.log(`Imported ${imported} conversations`);
    return imported;
  }
}

module.exports = ChatService;