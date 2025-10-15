// Global variables
let currentSessionId = null;
let sessions = [];

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 Chatbot Sidecar App initialized');
    
    // Initialize UI elements
    initializeEventListeners();
    
    // Check system health
    checkSystemHealth();
    
    // Load existing sessions
    loadSessions();
    
    // Setup keyboard shortcuts
    setupKeyboardShortcuts();
});

// Event listeners
function initializeEventListeners() {
    const newSessionBtn = document.getElementById('newSessionBtn');
    const sendBtn = document.getElementById('sendBtn');
    const deleteSessionBtn = document.getElementById('deleteSessionBtn');
    const messageInput = document.getElementById('messageInput');
    
    newSessionBtn?.addEventListener('click', createNewSession);
    sendBtn?.addEventListener('click', sendMessage);
    deleteSessionBtn?.addEventListener('click', deleteCurrentSession);
    
    // Auto-resize textarea
    messageInput?.addEventListener('input', function() {
        this.style.height = 'auto';
        this.style.height = Math.min(this.scrollHeight, 120) + 'px';
    });
}

// Keyboard shortcuts
function setupKeyboardShortcuts() {
    document.addEventListener('keydown', function(e) {
        // Ctrl+Enter to send message
        if (e.ctrlKey && e.key === 'Enter') {
            e.preventDefault();
            sendMessage();
        }
        
        // Escape to clear input
        if (e.key === 'Escape') {
            const messageInput = document.getElementById('messageInput');
            if (messageInput) {
                messageInput.value = '';
                messageInput.style.height = 'auto';
            }
        }
    });
}

// System health checks
async function checkSystemHealth() {
    try {
        // Check app health
        const appResponse = await fetch('/health');
        const appData = await appResponse.json();
        updateStatusIndicator('appStatus', appResponse.ok, appData.status || 'unknown');
        
        // Check sidecar health
        const sidecarResponse = await fetch('/api/sidecar/health');
        const sidecarData = await sidecarResponse.json();
        updateStatusIndicator('sidecarStatus', sidecarResponse.ok, sidecarData.sidecarStatus || 'unknown');
        
        if (!sidecarResponse.ok) {
            showToast('Warning: AI service is not available. Some features may not work.', 'error');
        }
        
    } catch (error) {
        console.error('Health check failed:', error);
        updateStatusIndicator('appStatus', false, 'error');
        updateStatusIndicator('sidecarStatus', false, 'error');
        showToast('System health check failed', 'error');
    }
}

// Update status indicators
function updateStatusIndicator(indicatorId, isHealthy, status) {
    const indicator = document.getElementById(indicatorId);
    const statusText = document.getElementById(indicatorId.replace('Status', 'StatusText'));
    
    if (indicator && statusText) {
        indicator.className = 'status-indicator ' + (isHealthy ? 'healthy' : 'unhealthy');
        statusText.textContent = status.charAt(0).toUpperCase() + status.slice(1);
    }
}

// Session management
async function loadSessions() {
    try {
        const response = await fetch('/api/chat/sessions');
        const data = await response.json();
        
        sessions = data.sessions || [];
        renderSessionList();
        
    } catch (error) {
        console.error('Failed to load sessions:', error);
        showToast('Failed to load chat sessions', 'error');
    }
}

function renderSessionList() {
    const sessionList = document.getElementById('sessionList');
    if (!sessionList) return;
    
    if (sessions.length === 0) {
        sessionList.innerHTML = `
            <div style="padding: 1rem; text-align: center; color: #a0aec0; font-style: italic;">
                No chat sessions yet.<br>
                Click "New Chat" to start!
            </div>
        `;
        return;
    }
    
    sessionList.innerHTML = sessions.map(session => `
        <div class="session-item ${session.id === currentSessionId ? 'active' : ''}" 
             onclick="selectSession('${session.id}')">
            <div class="session-item-title">${escapeHtml(session.title)}</div>
            <div class="session-item-time">${formatTime(session.createdAt)}</div>
        </div>
    `).join('');
}

async function createNewSession() {
    try {
        const response = await fetch('/api/chat/sessions', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                title: `Chat ${new Date().toLocaleDateString()}`
            })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            sessions.unshift(data.session);
            await selectSession(data.sessionId);
            renderSessionList();
            showToast('New chat session created!', 'success');
        } else {
            throw new Error(data.error || 'Failed to create session');
        }
        
    } catch (error) {
        console.error('Failed to create session:', error);
        showToast('Failed to create new chat session', 'error');
    }
}

async function selectSession(sessionId) {
    try {
        const response = await fetch(`/api/chat/sessions/${sessionId}`);
        const session = await response.json();
        
        if (response.ok) {
            currentSessionId = sessionId;
            document.getElementById('currentSessionTitle').textContent = session.title;
            
            // Show input container and hide welcome message
            document.getElementById('inputContainer').style.display = 'block';
            document.getElementById('deleteSessionBtn').style.display = 'block';
            
            // Render messages
            renderMessages(session.messages || []);
            renderSessionList(); // Update active state
            
        } else {
            throw new Error(session.error || 'Failed to load session');
        }
        
    } catch (error) {
        console.error('Failed to select session:', error);
        showToast('Failed to load chat session', 'error');
    }
}

async function deleteCurrentSession() {
    if (!currentSessionId) return;
    
    if (!confirm('Are you sure you want to delete this chat session? This action cannot be undone.')) {
        return;
    }
    
    try {
        const response = await fetch(`/api/chat/sessions/${currentSessionId}`, {
            method: 'DELETE'
        });
        
        if (response.ok) {
            // Remove from local sessions array
            sessions = sessions.filter(s => s.id !== currentSessionId);
            
            // Reset UI
            currentSessionId = null;
            document.getElementById('currentSessionTitle').textContent = 'Select or create a chat session';
            document.getElementById('inputContainer').style.display = 'none';
            document.getElementById('deleteSessionBtn').style.display = 'none';
            
            // Show welcome message
            const messagesContainer = document.getElementById('messagesContainer');
            messagesContainer.innerHTML = `
                <div class="welcome-message">
                    <div class="welcome-content">
                        <i class="fas fa-robot fa-3x"></i>
                        <h2>Chat session deleted</h2>
                        <p>Create a new chat session or select an existing one to continue.</p>
                    </div>
                </div>
            `;
            
            renderSessionList();
            showToast('Chat session deleted', 'success');
            
        } else {
            throw new Error('Failed to delete session');
        }
        
    } catch (error) {
        console.error('Failed to delete session:', error);
        showToast('Failed to delete chat session', 'error');
    }
}

// Message handling
function renderMessages(messages) {
    const messagesContainer = document.getElementById('messagesContainer');
    if (!messagesContainer) return;
    
    messagesContainer.innerHTML = messages.map(message => `
        <div class="message ${message.role}">
            <div class="message-avatar">
                <i class="fas ${message.role === 'user' ? 'fa-user' : 'fa-robot'}"></i>
            </div>
            <div class="message-content">
                <div class="message-bubble">
                    ${formatMessageContent(message.content)}
                </div>
                <div class="message-time">
                    ${formatTime(message.timestamp)}
                    ${message.model ? ` • ${message.model}` : ''}
                    ${message.tokens ? ` • ${message.tokens} tokens` : ''}
                </div>
            </div>
        </div>
    `).join('');
    
    // Scroll to bottom
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
}

async function sendMessage() {
    const messageInput = document.getElementById('messageInput');
    const sendBtn = document.getElementById('sendBtn');
    
    if (!messageInput || !currentSessionId) return;
    
    const message = messageInput.value.trim();
    if (!message) {
        showToast('Please enter a message', 'error');
        return;
    }
    
    // Disable input while sending
    messageInput.disabled = true;
    sendBtn.disabled = true;
    showLoadingOverlay(true);
    
    try {
        const response = await fetch(`/api/chat/sessions/${currentSessionId}/messages`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                message: message,
                model: 'phi4'
            })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            // Clear input
            messageInput.value = '';
            messageInput.style.height = 'auto';
            
            // Reload session to get updated messages
            await selectSession(currentSessionId);
            
        } else {
            throw new Error(data.error || 'Failed to send message');
        }
        
    } catch (error) {
        console.error('Failed to send message:', error);
        showToast('Failed to send message. Please try again.', 'error');
        
        // Re-enable input on error
        messageInput.disabled = false;
        sendBtn.disabled = false;
        messageInput.focus();
    } finally {
        showLoadingOverlay(false);
        messageInput.disabled = false;
        sendBtn.disabled = false;
        messageInput.focus();
    }
}

// UI utilities
function showLoadingOverlay(show) {
    const overlay = document.getElementById('loadingOverlay');
    if (overlay) {
        overlay.style.display = show ? 'flex' : 'none';
    }
}

function showToast(message, type = 'info') {
    const toastContainer = document.getElementById('toastContainer');
    if (!toastContainer) return;
    
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <i class="fas ${getToastIcon(type)}"></i>
        ${escapeHtml(message)}
    `;
    
    toastContainer.appendChild(toast);
    
    // Auto remove after 5 seconds
    setTimeout(() => {
        if (toast.parentNode) {
            toast.parentNode.removeChild(toast);
        }
    }, 5000);
}

function getToastIcon(type) {
    switch (type) {
        case 'success': return 'fa-check-circle';
        case 'error': return 'fa-exclamation-circle';
        case 'info': return 'fa-info-circle';
        default: return 'fa-info-circle';
    }
}

// Utility functions
function formatTime(timestamp) {
    try {
        const date = new Date(timestamp);
        const now = new Date();
        const diff = now - date;
        
        // Less than 1 minute
        if (diff < 60000) {
            return 'Just now';
        }
        
        // Less than 1 hour
        if (diff < 3600000) {
            const minutes = Math.floor(diff / 60000);
            return `${minutes} minute${minutes !== 1 ? 's' : ''} ago`;
        }
        
        // Less than 24 hours
        if (diff < 86400000) {
            const hours = Math.floor(diff / 3600000);
            return `${hours} hour${hours !== 1 ? 's' : ''} ago`;
        }
        
        // More than 24 hours
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { 
            hour: '2-digit', 
            minute: '2-digit' 
        });
        
    } catch (error) {
        return 'Unknown time';
    }
}

function formatMessageContent(content) {
    // Simple formatting - convert newlines to <br> and escape HTML
    return escapeHtml(content).replace(/\n/g, '<br>');
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Health check interval
setInterval(checkSystemHealth, 30000); // Check every 30 seconds

// Export for debugging
window.ChatbotApp = {
    currentSessionId,
    sessions,
    createNewSession,
    selectSession,
    sendMessage,
    checkSystemHealth
};