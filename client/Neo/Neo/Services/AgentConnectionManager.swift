import Foundation
import Combine

class AgentConnectionManager: ObservableObject {
    static let shared = AgentConnectionManager()
    
    @Published var messages: [ChatMessage] = []
    @Published var agentState: AgentState = AgentState(status: "DISCONNECTED", description: "正在连接...")
    @Published var pendingPermissionRequest: PermissionRequest? = nil
    @Published var sessions: [ChatSession] = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    
    // Server URL (Change to your local IP or production server later)
    private let serverURL = URL(string: "ws://localhost:3000/socket.io/?EIO=4&transport=websocket")!
    
    private init() {
        // Do not connect automatically, wait for AuthManager
    }
    
    func connect(token: String) {
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: serverURL)
        webSocketTask?.resume()
        agentState = AgentState(status: "IDLE", description: "正在连接...")
        receiveMessage(token: token)
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        messages.removeAll()
        agentState = AgentState(status: "DISCONNECTED", description: "已断开连接")
    }
    
    private func receiveMessage(token: String) {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("WebSocket Error: \(error)")
                DispatchQueue.main.async {
                    self?.agentState = AgentState(status: "ERROR", description: "连接中断，正在重试...")
                    // 如果发生错误，过 2 秒后尝试重连
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self?.connect(token: token)
                    }
                }
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleSocketIOMessage(text, token: token)
                case .data(_):
                    break
                @unknown default:
                    break
                }
                // Continue listening
                self?.receiveMessage(token: token)
            }
        }
    }
    
    // Very basic socket.io protocol parsing (format: "42[\"event_name\", payload]")
    private func handleSocketIOMessage(_ text: String, token: String) {
        // Handle Engine.IO Open packet
        if text.starts(with: "0") {
            // Must send Socket.IO Connect packet "40" to join the default namespace
            // With auth payload for v4
            let authPayload = ["token": token]
            if let authData = try? JSONSerialization.data(withJSONObject: authPayload),
               let authString = String(data: authData, encoding: .utf8) {
                webSocketTask?.send(.string("40\(authString)")) { _ in }
            } else {
                webSocketTask?.send(.string("40")) { _ in }
            }
            return
        }
        
        // Socket.IO sends heartbeat "2", reply with "3"
        if text == "2" {
            webSocketTask?.send(.string("3")) { _ in }
            return
        }
        
        // Handle Socket.IO Connect success packet
        if text.starts(with: "40") {
            print("Socket.IO Namespace Connected")
            return
        }
        
        guard text.starts(with: "42") else { return }
        
        let jsonString = String(text.dropFirst(2))
        guard let data = jsonString.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [Any],
              jsonArray.count >= 2,
              let event = jsonArray[0] as? String else {
            return
        }
        
        let payload = jsonArray[1]
        
        DispatchQueue.main.async {
            self.processEvent(event, payload: payload)
        }
    }
    
    private func processEvent(_ event: String, payload: Any) {
        switch event {
        case "SESSIONS_LIST":
            if let dict = payload as? [String: Any], let sessionsArray = dict["sessions"] as? [[String: Any]] {
                self.sessions = sessionsArray.compactMap { s in
                    guard let id = s["id"] as? String,
                          let title = s["title"] as? String else { return nil }
                    let updatedAt = s["updatedAt"] as? String ?? ""
                    return ChatSession(id: id, title: title, updatedAt: updatedAt)
                }
            } else if let sessionsArray = payload as? [[String: Any]] { // Fallback for older backend
                self.sessions = sessionsArray.compactMap { s in
                    guard let id = s["id"] as? String,
                          let title = s["title"] as? String else { return nil }
                    let updatedAt = s["updatedAt"] as? String ?? ""
                    return ChatSession(id: id, title: title, updatedAt: updatedAt)
                }
            }
            
        case "SESSION_LOADED":
            if let dict = payload as? [String: Any], let loadedMessages = dict["messages"] as? [[String: Any]] {
                self.messages = loadedMessages.compactMap { m in
                    guard let roleStr = m["role"] as? String,
                          let content = m["content"] as? String else { return nil }
                    let role: MessageRole = roleStr == "user" ? .user : (roleStr == "system" ? .system : .agent)
                    var newMsg = ChatMessage(role: role, content: content)
                    newMsg.components = MessageParser.parse(content)
                    return newMsg
                }
            }

        case "AGENT_STATE":
            guard let dict = payload as? [String: Any] else { return }
            if let status = dict["status"] as? String, let desc = dict["description"] as? String {
                self.agentState = AgentState(status: status, description: desc)
                
                // If working on a tool, append it as a tool component
                if status == "WORKING" {
                    self.appendToolCallToLastAgentMessage(desc: desc)
                }
            }
            
        case "CHUNK":
            guard let dict = payload as? [String: Any] else { return }
            if let text = dict["text"] as? String {
                self.appendToLastAgentMessage(text)
            }
            
        case "PERMISSION_REQ":
            guard let dict = payload as? [String: Any] else { return }
            if let tool = dict["tool"] as? String, let desc = dict["desc"] as? String {
                // Pause UI and show request
                self.pendingPermissionRequest = PermissionRequest(tool: tool, desc: desc)
                self.agentState = AgentState(status: "SUSPENDED", description: "等待你的授权决策...")
            }
            
        default:
            print("Unhandled event: \(event)")
        }
    }
    
    func sendMessage(_ text: String) {
        let newMsg = ChatMessage(role: .user, content: text, components: [])
        self.messages.append(newMsg)
        
        // Prepare empty agent message for streaming chunks
        self.messages.append(ChatMessage(role: .agent, content: "", components: []))
        
        let payload: [String: Any] = ["content": text]
        sendSocketIOEvent(event: "MESSAGE", payload: payload)
    }
    
    func clearSession() {
        self.messages.removeAll()
        let payload: [String: Any] = [:]
        sendSocketIOEvent(event: "CLEAR_CHAT", payload: payload)
        
        // Refresh sessions list after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.fetchSessions()
        }
    }
    
    func fetchSessions() {
        sendSocketIOEvent(event: "GET_SESSIONS", payload: [:])
    }
    
    func loadSession(id: String) {
        self.messages.removeAll()
        sendSocketIOEvent(event: "LOAD_SESSION", payload: ["sessionId": id])
    }
    
    func resolvePermission(allow: Bool) {
        self.pendingPermissionRequest = nil
        let payload: [String: Any] = ["action": allow ? "ALLOW" : "DENY"]
        sendSocketIOEvent(event: "PERMISSION_RES", payload: payload)
        
        // Log user decision
        self.messages.append(ChatMessage(role: .system, content: allow ? "✅ [Authorized] Allowed tool execution" : "❌ [Denied] Rejected tool execution"))
        self.messages.append(ChatMessage(role: .agent, content: "", components: [])) // Prepare for next agent response
    }
    
    private func appendToLastAgentMessage(_ text: String) {
        if let lastIndex = self.messages.lastIndex(where: { $0.role == .agent }) {
            self.messages[lastIndex].content += text
            self.messages[lastIndex].components = MessageParser.parse(self.messages[lastIndex].content)
        } else {
            var newMsg = ChatMessage(role: .agent, content: text)
            newMsg.components = MessageParser.parse(text)
            self.messages.append(newMsg)
        }
    }
    
    private func appendToolCallToLastAgentMessage(desc: String) {
        if let lastIndex = self.messages.lastIndex(where: { $0.role == .agent }) {
            // For now, we will just append it to the content as a system note, and the parser will pick it up if we format it nicely,
            // OR we can just inject a special tag like <tool>desc</tool> into the content so the parser handles it.
            let toolText = "\n<tool>\(desc)</tool>\n"
            self.messages[lastIndex].content += toolText
            self.messages[lastIndex].components = MessageParser.parse(self.messages[lastIndex].content)
        }
    }

    private func sendSocketIOEvent(event: String, payload: [String: Any]) {
        let messageArr: [Any] = [event, payload]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: messageArr, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let socketIOPacket = "42\(jsonString)"
        webSocketTask?.send(.string(socketIOPacket)) { error in
            if let error = error {
                print("Send error: \(error)")
            }
        }
    }
}
