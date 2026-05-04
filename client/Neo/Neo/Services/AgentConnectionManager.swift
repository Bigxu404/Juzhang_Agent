import Foundation
import Combine

class AgentConnectionManager: ObservableObject {
    static let shared = AgentConnectionManager()
    
    @Published var messages: [UIChatMessage] = []
    @Published var agentState: OldAgentState = OldAgentState(status: "DISCONNECTED", description: "正在连接...")
    @Published var pendingPermissionRequest: PermissionRequest? = nil
    @Published var sessions: [ChatSession] = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    
    // Server URL
    private let serverURL = URL(string: "ws://localhost:3000/socket.io/?EIO=4&transport=websocket")!
    
    private init() {
        // Do not connect automatically, wait for AuthManager
    }
    
    func connect(token: String) {
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: serverURL)
        webSocketTask?.resume()
        agentState = OldAgentState(status: "IDLE", description: "正在连接...")
        receiveMessage(token: token)
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        messages.removeAll()
        agentState = OldAgentState(status: "DISCONNECTED", description: "已断开连接")
    }
    
    private func receiveMessage(token: String) {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("WebSocket Error: \(error)")
                DispatchQueue.main.async {
                    self?.agentState = OldAgentState(status: "ERROR", description: "连接中断，正在重试...")
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
            DispatchQueue.main.async {
                self.fetchSessions()
            }
            return
        }
        
        // Handle Socket.IO Connect Error packet
        if text.starts(with: "44") {
            print("Socket.IO Connect Error: \(text)")
            DispatchQueue.main.async {
                self.agentState = OldAgentState(status: "ERROR", description: "认证失败，请重新登录")
            }
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
            print("Received SESSIONS_LIST payload: \(payload)")
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
                          let title = s["title"] as? String else {
                        print("Failed to parse session: \(s)")
                        return nil
                    }
                    let updatedAt = s["updatedAt"] as? String ?? ""
                    return ChatSession(id: id, title: title, updatedAt: updatedAt)
                }
            } else {
                print("Could not parse SESSIONS_LIST payload as array or dict")
            }
            print("Parsed sessions count: \(self.sessions.count)")
            
                case "SESSION_LOADED":
            if let dict = payload as? [String: Any], let loadedMessages = dict["messages"] as? [[String: Any]] {
                self.messages = loadedMessages.compactMap { m in
                    guard let roleStr = m["role"] as? String,
                          let content = m["content"] as? String else { return nil }
                    let role: MessageRole = roleStr == "user" ? .user : (roleStr == "system" ? .system : .agent)
                    var newMsg = UIChatMessage(text: content, type: role == .user ? .user : .agent, state: nil)
                    newMsg.components = MessageParser.parse(content)
                    return newMsg
                }
            }

        case "AGENT_STATE":
            guard let dict = payload as? [String: Any] else { return }
            if let status = dict["status"] as? String, let desc = dict["description"] as? String {
                self.agentState = OldAgentState(status: status, description: desc)
                
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
            
        case "DONE":
            // 取消 loading / isStreaming 标记
            if let lastIndex = self.messages.lastIndex(where: { $0.type == .agent }) {
                self.messages[lastIndex].isStreaming = false
            }
            
        case "AGENT_ASK_HUMAN":
            guard let dict = payload as? [String: Any] else { return }
            if let question = dict["question"] as? String {
                let options = dict["options"] as? [String] ?? []
                // 创建一个特殊的选项卡片气泡
                var msg = UIChatMessage(text: question, type: .agent, state: nil, isStreaming: false)
                msg.components = [.choice(question: question, options: options)]
                self.messages.append(msg)
                
                self.agentState = OldAgentState(status: "SUSPENDED", description: "等待你的选择...")
            }
            
        case "PERMISSION_REQ":
            guard let dict = payload as? [String: Any] else { return }
            if let tool = dict["tool"] as? String, let desc = dict["desc"] as? String {
                // Pause UI and show request
                self.pendingPermissionRequest = PermissionRequest(tool: tool, desc: desc)
                self.agentState = OldAgentState(status: "SUSPENDED", description: "等待你的授权决策...")
            }
            
        default:
            print("Unhandled event: \(event)")
        }
    }
    
    func sendMessage(_ text: String, attachments: [String] = []) {
        let newMsg = UIChatMessage(text: text, type: .user, state: nil)
        self.messages.append(newMsg)
        
        // Prepare empty agent message for streaming chunks
        var loadingMsg = UIChatMessage(text: "", type: .agent, state: nil, isStreaming: true)
        loadingMsg.components = [.text("")]
        self.messages.append(loadingMsg)
        
        var payload: [String: Any] = ["content": text]
        if !attachments.isEmpty {
            payload["attachments"] = attachments
        }
        
        if let loc = LocationManager.shared.currentLocationName {
            payload["location"] = loc
        }
        
        sendSocketIOEvent(event: "MESSAGE", payload: payload)
    }
    
    func uploadFile(fileURL: URL, sessionId: String?, completion: @escaping (Result<String, Error>) -> Void) {
        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else {
            completion(.failure(NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No token"])))
            return
        }
        
        let requestURL = URL(string: "http://localhost:3000/api/files/upload")!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        if let sessionId = sessionId {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"sessionId\"\r\n\r\n".data(using: .utf8)!)
            data.append("\(sessionId)\r\n".data(using: .utf8)!)
        }
        
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        let filename = fileURL.lastPathComponent
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        
        guard let fileData = try? Data(contentsOf: fileURL) else {
            completion(.failure(NSError(domain: "File", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot read file"])))
            return
        }
        data.append(fileData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        let task = URLSession.shared.uploadTask(with: request, from: data) { responseData, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let responseData = responseData,
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let fileDict = json["file"] as? [String: Any],
               let url = fileDict["url"] as? String {
                completion(.success(url))
            } else {
                completion(.failure(NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
            }
        }
        task.resume()
    }
    
    func stopGeneration() {
        sendSocketIOEvent(event: "STOP_GENERATION", payload: [:])
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
        self.messages.append(UIChatMessage(text: allow ? "✅ [Authorized] Allowed tool execution" : "❌ [Denied] Rejected tool execution", type: .agent, state: nil))
        self.messages.append(UIChatMessage(text: "", type: .agent, state: nil)) // Prepare for next agent response
    }
    
    func sendHumanAnswer(_ answer: String) {
        let payload: [String: Any] = ["answer": answer]
        sendSocketIOEvent(event: "HUMAN_ANSWER", payload: payload)
        
        // 自己发一条消息记录
        let newMsg = UIChatMessage(text: answer, type: .user, state: nil)
        self.messages.append(newMsg)
        
        // 准备下一个气泡
        var loadingMsg = UIChatMessage(text: "", type: .agent, state: nil, isStreaming: true)
        loadingMsg.components = [.text("")]
        self.messages.append(loadingMsg)
    }
    
    private func appendToLastAgentMessage(_ text: String) {
        if let lastIndex = self.messages.lastIndex(where: { $0.type == .agent }) {
            self.messages[lastIndex].text += text
            self.messages[lastIndex].components = MessageParser.parse(self.messages[lastIndex].text)
            
            // 确保组件不是空的，如果因为 parser 返回空导致气泡消失，强行插入一个空文本组件以便渲染 loading
            if self.messages[lastIndex].components.isEmpty {
                 self.messages[lastIndex].components = [.text("")]
            }
        } else {
            var newMsg = UIChatMessage(text: text, type: .agent, state: nil)
            newMsg.components = MessageParser.parse(text)
            if newMsg.components.isEmpty {
                 newMsg.components = [.text("")]
            }
            self.messages.append(newMsg)
        }
    }
    
    private func appendToolCallToLastAgentMessage(desc: String) {
        if let lastIndex = self.messages.lastIndex(where: { $0.type == .agent }) {
            let toolText = "\n<tool>\(desc)</tool>\n"
            self.messages[lastIndex].text += toolText
            self.messages[lastIndex].components = MessageParser.parse(self.messages[lastIndex].text)
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
