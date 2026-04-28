import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    var content: String // For backward compatibility / raw string
    var components: [MessageComponent] = []
}

enum MessageRole {
    case user
    case agent
    case system
}

enum ToolStatus: String, Equatable {
    case running = "Running"
    case success = "Success"
    case failed = "Failed"
    case suspended = "Suspended"
}

enum MessageComponent: Equatable {
    case text(String)
    case thinking(content: String, isFinished: Bool)
    case toolCall(name: String, status: ToolStatus, description: String)
}

struct OldAgentState: Equatable {
    var status: String
    var description: String
}

struct PermissionRequest: Equatable {
    let tool: String
    let desc: String
}

struct ChatSession: Identifiable, Equatable {
    let id: String
    let title: String
    let updatedAt: String
    
    var formattedDate: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: updatedAt) ?? ISO8601DateFormatter().date(from: updatedAt) {
            let outFormatter = DateFormatter()
            outFormatter.dateFormat = "MM-dd HH:mm"
            return outFormatter.string(from: date)
        }
        return String(updatedAt.prefix(10))
    }
}

struct MemoryItem: Identifiable, Decodable, Equatable {
    let id: String
    let content: String
    let createdAt: String
}

struct SkillItem: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    let description: String
    let content: String
    let isActive: Bool
    let updatedAt: String
}

struct McpProvider: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    let description: String
    let connected: Bool
}

struct McpProvidersResponse: Equatable {
    let providers: [McpProvider]
}

struct McpAuthorizeResponse: Equatable {
    let success: Bool
    let connected: Bool
    let message: String
}
