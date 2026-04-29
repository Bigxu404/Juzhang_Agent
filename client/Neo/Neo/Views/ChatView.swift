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
    @StateObject private var connectionManager = AgentConnectionManager.shared
    @State private var isProcessExpanded = false
    
    @State private var showDrawer = false
    
    private var currentState: AgentState {
        switch connectionManager.agentState.status {
        case "IDLE", "DISCONNECTED": return .idle
        case "THINKING": return .thinking
        case "WORKING": return .working
        case "SUCCESS": return .success
        default: return .idle
        }
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // 原有的内容被包装在主界面层
            mainContent
            
            // 抽屉遮罩层
            if showDrawer {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring()) {
                            showDrawer = false
                        }
                    }
                    .zIndex(100)
            }
            
            // 左侧抽屉内容
            if showDrawer {
                sideDrawer
                    .frame(width: UIScreen.main.bounds.width * 0.75)
                    .background(AppTheme.surface1)
                    .transition(.move(edge: .leading))
                    .zIndex(101)
                    .ignoresSafeArea(.all, edges: .bottom)
            }
        }
        .onAppear {
            connectionManager.fetchSessions()
        }
    }
    
    // 主界面内容抽取出来
    private var mainContent: some View {
        ZStack {
            // 全局背景 (奶油雾白)
            AppTheme.bgBase.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. 顶部导航栏 (标准 iOS 风格)
                HStack {
                    Button(action: {
                        withAnimation { showDrawer = true }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    
                    Spacer()
                    
                    Text("对话")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        connectionManager.clearSession()
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(
                    AppTheme.bgBase.opacity(0.95)
                        .ignoresSafeArea(.all, edges: .top)
                )
                .zIndex(10)
                
                // 2. Message ListView (对话流)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            
                            // 历史消息列表
                            ForEach(connectionManager.messages) { msg in
                                ChatBubble(text: msg.text, type: msg.type, state: msg.state, isStreaming: msg.isStreaming)
                                    .padding(.top, msg.id == connectionManager.messages.first?.id ? 24 : 0)
                            }
                            
                            // 过程总览卡片 (模拟思考/工具调用)
                            if currentState == .thinking || currentState == .working {
                                // 橘长状态提示
                                HStack(spacing: 12) {
                                    StatusAvatarView(state: currentState, size: 28)
                                    Text(statusText(for: currentState))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(AppTheme.textSecondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 8)
                                
                                ProcessTimelineView(
                                    title: "正在处理",
                                    subtitle: connectionManager.agentState.description,
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
                            Color.clear.frame(height: 20).id("bottom")
                        }
                    }
                    .onChange(of: connectionManager.messages.count) { oldValue, newValue in
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
                
                // 3. Input Bar (悬浮胶囊风格)
                HStack(spacing: 12) {
                    // 附件按钮 (加号)
                    Button(action: {}) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    
                    // 输入框
                    TextField("给橘长递纸条...", text: $inputText)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    // 发送按钮 (橘色点睛)
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.brandOrange)
                            .clipShape(Circle())
                            .shadow(color: AppTheme.brandOrange.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .disabled(inputText.isEmpty)
                    .opacity(inputText.isEmpty ? 0.5 : 1.0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 4)
                .padding(.horizontal, 20)
                .padding(.bottom, 96) // 把悬浮胶囊推到 TabBar 上方
            }
        }
    }
    
    // 左侧抽屉视图
    private var sideDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 抽屉头部
            HStack {
                Text("历史记录")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button(action: {
                    withAnimation(.spring()) { showDrawer = false }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
            .padding(24)
            .padding(.top, 40)
            
            Divider().background(AppTheme.strokeSoft)
            
            // 会话列表
            ScrollView {
                VStack(spacing: 12) {
                    if connectionManager.sessions.isEmpty {
                        Text("暂无历史记录")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(connectionManager.sessions) { session in
                            Button(action: {
                                connectionManager.loadSession(id: session.id)
                                withAnimation(.spring()) { showDrawer = false }
                            }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(session.title)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(AppTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(session.formattedDate)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textTertiary)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.rM))
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }
    
    // 实际发送消息逻辑
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let userText = inputText
        inputText = ""
        
        // 调用 AgentConnectionManager 实际发送请求到后端
        connectionManager.sendMessage(userText)
        
        withAnimation {
            isProcessExpanded = true
        }
    }
    
    // 辅助方法：根据状态返回文案
    private func statusText(for state: AgentState) -> String {
        return connectionManager.agentState.description
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
    }
}
