import SwiftUI

/// 消息来源类型
enum MessageType {
    case user
    case agent
}

/// 极简聊天气泡组件
struct ChatBubble: View {
    let text: String
    let type: MessageType
    let state: AgentState? // 仅当 type == .agent 时传入
    var isStreaming: Bool = false // 是否启用打字机效果
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            
            // 助手头像 (靠左)
            if type == .agent {
                StatusAvatarView(state: state ?? .idle, size: 36)
                    .padding(.top, 4)
            } else {
                Spacer(minLength: 40) // 用户消息左侧留白
            }
            
            // 气泡主体
            VStack(alignment: type == .user ? .trailing : .leading, spacing: 4) {
                if isStreaming && type == .agent {
                    TypewriterTextView(fullText: text, speed: 0.03, isUser: false)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                } else {
                    Text(text)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(type == .user ? .white : AppTheme.textPrimary)
                        .lineSpacing(4) // 行高 1.35-1.45
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
            .background(
                type == .user
                    ? AppTheme.brandOrange // 用户气泡：橘色
                    : AppTheme.surface2    // 助手气泡：次级底色
            )
            .clipShape(
                RoundedRectangle(cornerRadius: AppTheme.rS, style: .continuous)
            )
            .overlay(
                // 助手气泡加轻描边
                type == .agent ?
                RoundedRectangle(cornerRadius: AppTheme.rS, style: .continuous)
                    .stroke(AppTheme.strokeSoft, lineWidth: 1)
                : nil
            )
            // 限制气泡最大宽度 (屏宽的 76-82%)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.76, alignment: type == .user ? .trailing : .leading)
            
            // 用户头像占位 (靠右)
            if type == .user {
                // 不显示用户头像
            } else {
                Spacer(minLength: 40) // 助手消息右侧留白
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct ChatBubble_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            ChatBubble(text: "帮我查一下明天北京的天气，然后写一封邮件给客户约下午的会议。", type: .user, state: nil)
            
            ChatBubble(text: "好的，北京明天晴，最高气温 22°C。邮件草稿已经帮你写好啦，你看一下有没有需要修改的？", type: .agent, state: .idle)
            
            ChatBubble(text: "太棒了，谢谢橘长！", type: .user, state: nil)
            
            ChatBubble(text: "不客气，这是我应该做的~", type: .agent, state: .happy, isStreaming: true)
        }
        .padding(.vertical, 20)
        .background(AppTheme.bgBase)
    }
}
