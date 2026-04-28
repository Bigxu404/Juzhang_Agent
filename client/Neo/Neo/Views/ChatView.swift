import SwiftUI

/// 消息模型
struct UIChatMessage: Identifiable {
    let id = UUID()
    var text: String
    let type: MessageType
    let state: AgentState?
    var isStreaming: Bool = false
}

/// 主聊天界面
struct ChatView: View {
    @State private var inputText = ""
    @State private var currentState: AgentState = .idle
    @State private var isProcessExpanded = false
    
    // 模拟对话历史
    @State private var messages: [UIChatMessage] = [
        UIChatMessage(text: "上午好，小胖。昨晚没睡好吗？", type: .agent, state: .idle, isStreaming: false),
        UIChatMessage(text: "帮我查一下明天北京的天气，然后写一封邮件给客户约下午的会议。", type: .user, state: nil, isStreaming: false)
    ]
    
    var body: some View {
        ZStack {
            // 全局背景 (奶油雾白)
            AppTheme.bgBase.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // 1. Top StatusBar (顶部状态条)
                HStack(spacing: 12) {
                    StatusAvatarView(state: currentState, size: 32)
                    
                    Text(statusText(for: currentState))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    // 模拟切换状态的调试按钮
                    Menu {
                        ForEach(AgentState.allCases, id: \.self) { state in
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    currentState = state
                                    if state == .working || state == .thinking {
                                        isProcessExpanded = true
                                    } else if state == .success {
                                        isProcessExpanded = false
                                    }
                                }
                            }) {
                                Text(state.rawValue)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(AppTheme.surface1.opacity(0.95))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(AppTheme.strokeLighter),
                    alignment: .bottom
                )
                .zIndex(10)
                
                // 2. Message ListView (对话流)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            
                            // 历史消息列表
                            ForEach(messages) { msg in
                                ChatBubble(text: msg.text, type: msg.type, state: msg.state, isStreaming: msg.isStreaming)
                                    .padding(.top, msg.id == messages.first?.id ? 24 : 0)
                            }
                            
                            // 过程总览卡片 (模拟思考/工具调用)
                            if currentState == .thinking || currentState == .working {
                                ProcessTimelineView(
                                    title: "正在处理",
                                    subtitle: currentState == .thinking ? "思考中..." : "工具调用 3 项",
                                    isExpanded: isProcessExpanded,
                                    state: currentState
                                )
                                .onTapGesture {
                                    withAnimation {
                                        isProcessExpanded.toggle()
                                    }
                                }
                            }
                            
                            // 底部留白给 BottomNav
                            Color.clear.frame(height: 100).id("bottom")
                        }
                    }
                    .onChange(of: messages.count) { oldValue, newValue in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: currentState) { oldValue, newValue in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                
                // 3. Input Bar (输入区)
                VStack(spacing: 0) {
                    Divider().background(AppTheme.strokeLighter)
                    
                    HStack(spacing: 12) {
                        // 附件按钮 (加号)
                        Button(action: {}) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        
                        // 输入框 (Surface-2)
                        TextField("给橘长递纸条...", text: $inputText)
                            .font(.system(size: 16, weight: .regular))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppTheme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.rS, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.rS, style: .continuous)
                                    .stroke(AppTheme.strokeSoft, lineWidth: 1)
                            )
                        
                        // 发送按钮 (橘色点睛)
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(AppTheme.brandOrange)
                                .clipShape(Circle())
                                .shadow(color: AppTheme.brandOrange.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .disabled(inputText.isEmpty)
                        .opacity(inputText.isEmpty ? 0.5 : 1.0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppTheme.surface1)
                }
            }
        }
    }
    
    // 模拟发送消息和回复逻辑
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let userText = inputText
        inputText = ""
        
        // 1. 添加用户消息
        messages.append(UIChatMessage(text: userText, type: .user, state: nil, isStreaming: false))
        
        // 2. 状态切换为思考
        withAnimation {
            currentState = .thinking
            isProcessExpanded = true
        }
        
        // 3. 模拟思考 1 秒后切换为工作中 (调用工具)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                currentState = .working
            }
            
            // 4. 模拟工作 2 秒后完成并回复
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    currentState = .success
                    isProcessExpanded = false
                }
                
                // 5. 延迟 0.5 秒后开始流式输出回复
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let isThanks = userText.contains("谢谢") || userText.contains("好")
                    let replyText = isThanks ? "不客气，这是我应该做的~" : "好的，北京明天晴，最高气温 22°C。邮件草稿已经帮你写好啦，你看一下有没有需要修改的？"
                    
                    withAnimation {
                        currentState = isThanks ? .happy : .idle
                    }
                    
                    messages.append(UIChatMessage(text: replyText, type: .agent, state: currentState, isStreaming: true))
                }
            }
        }
    }
    
    // 辅助方法：根据状态返回文案
    private func statusText(for state: AgentState) -> String {
        switch state {
        case .idle: return "橘长在安静地待机"
        case .thinking: return "橘长正在想一想..."
        case .working: return "橘长正在翻找资料..."
        case .success: return "橘长把毛线球理顺啦"
        case .happy: return "橘长很开心"
        }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
    }
}
