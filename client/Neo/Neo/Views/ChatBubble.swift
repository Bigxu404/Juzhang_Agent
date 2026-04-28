import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                if message.role == .user {
                    Text(message.content)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .font(.body)
                } else if message.role == .system {
                    Text(message.content)
                        .padding(12)
                        .background(Color.clear)
                        .foregroundColor(.gray)
                        .cornerRadius(16)
                        .font(.footnote)
                } else {
                    // Agent message with components
                    if message.components.isEmpty {
                        // Fallback or empty state
                        if message.content.isEmpty {
                            ProgressView()
                                .padding(12)
                        } else {
                            Text(message.content)
                                .padding(12)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(16)
                                .font(.body)
                        }
                    } else {
                        ForEach(Array(message.components.enumerated()), id: \.offset) { _, component in
                            renderComponent(component)
                        }
                    }
                }
            }
            
            if message.role == .agent || message.role == .system { Spacer() }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func renderComponent(_ component: MessageComponent) -> some View {
        switch component {
        case .text(let text):
            Text(text)
                .padding(12)
                .background(Color.gray.opacity(0.15))
                .foregroundColor(.primary)
                .cornerRadius(16)
                .font(.body)
            
        case .thinking(let content, let isFinished):
            CollapsibleThinkingBlock(content: content, isFinished: isFinished)
            
        case .toolCall(let name, let status, let description):
            ToolActionBlock(name: name, status: status, description: description)
        }
    }
}

struct CollapsibleThinkingBlock: View {
    let content: String
    let isFinished: Bool
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    if #available(iOS 17.0, *) {
                        Image(systemName: isFinished ? "brain" : "brain.head.profile")
                            .foregroundColor(.gray)
                            .symbolEffect(.pulse, isActive: !isFinished)
                    } else {
                        Image(systemName: isFinished ? "brain" : "brain.head.profile")
                            .foregroundColor(.gray)
                    }
                    
                    Text(isFinished ? "思考完成" : "正在思考...")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
            }
            
            if isExpanded {
                Text(content)
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(12)
                    .background(Color.gray.opacity(0.05))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ToolActionBlock: View {
    let name: String
    let status: ToolStatus
    let description: String
    
    var isSubagent: Bool {
        name == "Subagent"
    }
    
    var themeColor: Color {
        isSubagent ? .purple : .blue
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZShapeIcon(status: status, themeColor: themeColor, isSubagent: isSubagent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(description)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(status == .running ? "执行中..." : "执行完成")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(12)
        .background(themeColor.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeColor.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ZShapeIcon: View {
    let status: ToolStatus
    let themeColor: Color
    let isSubagent: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(status == .running ? themeColor.opacity(0.2) : Color.green.opacity(0.2))
                .frame(width: 32, height: 32)
            
            if status == .running {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: isSubagent ? "network" : "checkmark")
                    .foregroundColor(isSubagent ? themeColor : .green)
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
    }
}
