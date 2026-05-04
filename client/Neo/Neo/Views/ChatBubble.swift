import SwiftUI

struct MessageComponentWrapper: View {
    let component: MessageComponent
    let message: UIChatMessage
    let index: Int
    let avState: AgentState
    let showAv: Bool
    
    @State private var isExpanded = true
    
    var body: some View {
        switch component {
        case .text(let t):
            ChatBubble(text: t, type: message.type, state: avState, isStreaming: message.isStreaming && index == message.components.count - 1, showAvatar: showAv)
                .padding(.top, (message.id == AgentConnectionManager.shared.messages.first?.id && index == 0) ? 24 : 0)
                
            case .thinking(let content, let isFinished):
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isFinished ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundColor(isFinished ? .green : AppTheme.textTertiary)
                            Text(isFinished ? "橘长领悟了" : "橘长正在思考...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textTertiary)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                        .padding(.leading, 64) // 和普通消息文字左侧对齐
                        .padding(.trailing, 16)
                        .padding(.vertical, 8)
                    }
                .onChange(of: isFinished) { _, newValue in
                    if newValue {
                        withAnimation {
                            isExpanded = false
                        }
                    }
                }
                
                if isExpanded {
                    ChatBubble(text: content, type: message.type, state: avState, isStreaming: !isFinished, showAvatar: false, isThinking: true)
                }
            }
            .padding(.top, (message.id == AgentConnectionManager.shared.messages.first?.id && index == 0) ? 24 : 0)
            
        case .toolCall(let name, let status, let desc):
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("🐾")
                            .font(.system(size: 14))
                        Text("橘长挥舞了爪子: \(name)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .padding(.leading, 64) // 和普通消息文字左侧对齐
                    .padding(.trailing, 16)
                    .padding(.vertical, 8)
                }
                
                if isExpanded {
                    ChatBubble(text: desc, type: message.type, state: avState, isStreaming: false, showAvatar: false, isToolCall: true)
                }
            }
            .padding(.top, (message.id == AgentConnectionManager.shared.messages.first?.id && index == 0) ? 24 : 0)
            
        case .file(let url, let name):
            HStack {
                if message.type == .user { Spacer() }
                
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.brandOrange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Text("轻点预览文件")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(width: 220)
                .background(AppTheme.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .onTapGesture {
                    if let validUrl = URL(string: url) {
                        UIApplication.shared.open(validUrl)
                    }
                }
                
                if message.type == .agent { Spacer() }
            }
            .padding(.top, (message.id == AgentConnectionManager.shared.messages.first?.id && index == 0) ? 24 : 0)
        case .choice(let question, let options):
            ChoiceCardView(question: question, options: options, messageId: message.id, index: index)
        }
    }
}

/// 意图澄清/选项卡片视图
struct ChoiceCardView: View {
    let question: String
    let options: [String]
    let messageId: UUID
    let index: Int
    
    @State private var selectedOptions: Set<String> = []
    @State private var textInput: String = ""
    @State private var isSubmitted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 头部
            HStack(spacing: 8) {
                Image(systemName: "list.clipboard.fill")
                    .foregroundColor(AppTheme.brandOrange)
                Text("补充信息")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Text(question)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
                .lineSpacing(4)
            
            if isSubmitted {
                // 已提交状态展示
                VStack(alignment: .leading, spacing: 8) {
                    Text("已回复：")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textTertiary)
                    
                    let submittedAnswers = options.isEmpty ? [textInput] : Array(selectedOptions).sorted()
                    ForEach(submittedAnswers, id: \.self) { ans in
                        HStack(alignment: .top) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .padding(.top, 2)
                            Text(ans)
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                .padding(.top, 4)
            } else {
                if options.isEmpty {
                    // 开放式输入框
                    TextField("请输入回复...", text: $textInput)
                        .font(.system(size: 15))
                        .padding(12)
                        .background(AppTheme.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.strokeLighter, lineWidth: 1)
                        )
                    
                    // 提交按钮 (输入框模式)
                    Button(action: {
                        let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            isSubmitted = true
                            AgentConnectionManager.shared.sendHumanAnswer(trimmed)
                        }
                    }) {
                        Text("确认提交")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppTheme.strokeSoft : AppTheme.brandOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.top, 4)
                    
                } else {
                    // 选项列表 (多选/单选)
                    VStack(spacing: 10) {
                        ForEach(options, id: \.self) { option in
                            Button(action: {
                                if selectedOptions.contains(option) {
                                    selectedOptions.remove(option)
                                } else {
                                    selectedOptions.insert(option)
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedOptions.contains(option) ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 18))
                                        .foregroundColor(selectedOptions.contains(option) ? AppTheme.brandOrange : AppTheme.strokeSoft)
                                    
                                    Text(option)
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(selectedOptions.contains(option) ? AppTheme.brandOrange : AppTheme.textPrimary)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(selectedOptions.contains(option) ? AppTheme.brandOrange.opacity(0.1) : AppTheme.surface1)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(selectedOptions.contains(option) ? AppTheme.brandOrange.opacity(0.5) : AppTheme.strokeLighter, lineWidth: 1)
                                )
                            }
                        }
                    }
                    
                    // 提交按钮 (选项模式)
                    Button(action: {
                        if !selectedOptions.isEmpty {
                            isSubmitted = true
                            let answer = Array(selectedOptions).sorted().joined(separator: ", ")
                            AgentConnectionManager.shared.sendHumanAnswer(answer)
                        }
                    }) {
                        Text("确认提交")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedOptions.isEmpty ? AppTheme.strokeSoft : AppTheme.brandOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(selectedOptions.isEmpty)
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(AppTheme.surface2) // 卡片底色
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.strokeLighter, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, (messageId == AgentConnectionManager.shared.messages.first?.id && index == 0) ? 24 : 0)
    }
}

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
    var showAvatar: Bool = true // 是否显示头像（用于分段消息排版）
    var isThinking: Bool = false // 是否为思考块
    var isToolCall: Bool = false // 是否为工具调用块
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            
            // 助手头像 (靠左)
            if type == .agent {
                if showAvatar {
                    StatusAvatarView(state: state ?? .idle, size: 36)
                        .padding(.top, 4)
                } else {
                    Color.clear.frame(width: 36, height: 36)
                        .padding(.top, 4)
                }
            } else {
                Spacer(minLength: 40) // 用户消息左侧留白
            }
            
            // 气泡主体
            VStack(alignment: type == .user ? .trailing : .leading, spacing: 4) {
                if isStreaming && type == .agent && text.isEmpty {
                    // Loading 动画状态：三个跳动的点，没有背景，靠左与头像垂直对齐
                    HStack(spacing: 4) {
                        Circle().frame(width: 6, height: 6).foregroundColor(AppTheme.textTertiary).opacity(0.5)
                            .modifier(BouncingAnimation(delay: 0))
                        Circle().frame(width: 6, height: 6).foregroundColor(AppTheme.textTertiary).opacity(0.5)
                            .modifier(BouncingAnimation(delay: 0.2))
                        Circle().frame(width: 6, height: 6).foregroundColor(AppTheme.textTertiary).opacity(0.5)
                            .modifier(BouncingAnimation(delay: 0.4))
                    }
                    .padding(.top, 14)
                    .padding(.leading, 8)
                } else if isStreaming && type == .agent {
                    let cleanedText = text.cleaningMarkdown()
                    TypewriterTextView(fullText: cleanedText, speed: 0.03, isUser: false)
                        .padding(.horizontal, 16)
                        .padding(.vertical, isThinking || isToolCall ? 8 : 12)
                        .background(AppTheme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.rS, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.rS, style: .continuous)
                                .stroke(isThinking || isToolCall ? AppTheme.strokeLighter : AppTheme.strokeSoft, lineWidth: 1)
                        )
                } else {
                    let cleanedText = text.cleaningMarkdown()
                    Text(LocalizedStringKey(cleanedText))
                        .font(.system(size: isThinking || isToolCall ? 14 : 16, weight: .regular))
                        .foregroundColor(type == .user ? .white : (isThinking || isToolCall ? AppTheme.textSecondary : AppTheme.textPrimary))
                        .lineSpacing(4) // 行高 1.35-1.45
                        .padding(.horizontal, 16)
                        .padding(.vertical, isThinking || isToolCall ? 8 : 12)
                        .background(
                            type == .user
                                ? AppTheme.brandOrange // 用户气泡：橘色
                                : (isThinking || isToolCall ? Color.clear : AppTheme.surface2)    // 助手气泡：次级底色，思考/工具用透明
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.rS, style: .continuous))
                        .overlay(
                            // 助手气泡加轻描边
                            type == .agent ?
                            RoundedRectangle(cornerRadius: AppTheme.rS, style: .continuous)
                                .stroke(isThinking || isToolCall ? AppTheme.strokeLighter : AppTheme.strokeSoft, lineWidth: 1)
                            : nil
                        )
                }
            }
            // 限制气泡最大宽度 (屏宽的 76-82%)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.76, alignment: type == .user ? .trailing : .leading)
            .onTapGesture {
                UIPasteboard.general.string = text
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            
            // 用户头像占位 (靠右)
            if type == .user {
                // 不显示用户头像
            } else {
                Spacer(minLength: 40) // 助手消息右侧留白
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4) // 减小垂直间距
    }
}

// 辅助跳动动画修饰器
struct BouncingAnimation: ViewModifier {
    let delay: Double
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.6).repeatForever().delay(delay)) {
                    offset = -6
                }
            }
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

extension String {
    /// 简单的 Markdown 格式清理：将原生不支持的 Headers 转为加粗
    func cleaningMarkdown() -> String {
        var result = self
        // 匹配 ### Title，将其转换为 **Title**
        if let regex = try? NSRegularExpression(pattern: "(?m)^#{1,6}\\s+(.*)$") {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "**$1**")
        }
        
        // 匹配粗体的错误解析 (防范性修正)
        // 有些模型返回的加粗前后可能带有奇怪空格，但一般不用处理
        
        return result
    }
}
