import SwiftUI

struct ChatView: View {
    @StateObject private var connectionManager = AgentConnectionManager.shared
    @State private var inputText: String = ""
    @State private var isDrawerOpen: Bool = false
    @AppStorage("pref_enable_haptics") private var enableHaptics: Bool = true
    
    var body: some View {
        ZStack {
            AppTheme.pageGradient
                .ignoresSafeArea()

            VStack(spacing: 10) {
            // Status Bar
            HStack {
                Button(action: {
                    withAnimation { isDrawerOpen.toggle() }
                    if isDrawerOpen { connectionManager.fetchSessions() }
                    triggerHaptic(style: .light)
                }) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(AppTheme.accent)
                        .font(.title3)
                }
                .padding(.trailing, 4)

                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundColor(statusColor)
                    .font(.caption.weight(.semibold))
                Text(connectionManager.agentState.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()

                Button(action: {
                    connectionManager.clearSession()
                    triggerHaptic(style: .light)
                }) {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(AppTheme.accent)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(AppTheme.subtleBorder, lineWidth: 1)
            )
            .padding(.horizontal)
            
            // Chat History
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(spacing: 10) {
                        ForEach(connectionManager.messages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .onChange(of: connectionManager.messages.count) {
                        withAnimation {
                            if let lastId = connectionManager.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Permission Alert Overlay
            if let req = connectionManager.pendingPermissionRequest {
                ActionApprovalCard(
                    title: "⚠️ 高危操作拦截",
                    subtitle: "Agent 请求使用工具：\(req.tool)",
                    detail: "描述：\(req.desc)",
                    rejectText: "拒绝",
                    approveText: "允许执行",
                    onReject: {
                        connectionManager.resolvePermission(allow: false)
                        triggerNotificationHaptic(type: .error)
                    },
                    onApprove: {
                        connectionManager.resolvePermission(allow: true)
                        triggerNotificationHaptic(type: .success)
                    }
                )
                .transition(.move(edge: .bottom))
                .animation(.spring(), value: connectionManager.pendingPermissionRequest != nil)
            }
            
            // Input Area
            HStack {
                TextField("跟老友聊点什么...", text: $inputText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.95))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(AppTheme.subtleBorder, lineWidth: 1)
                    )
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(AppTheme.heroGradient)
                        .clipShape(Circle())
                }
                .disabled(inputText.isEmpty || connectionManager.pendingPermissionRequest != nil)
                .opacity(inputText.isEmpty || connectionManager.pendingPermissionRequest != nil ? 0.5 : 1)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            }
            .disabled(isDrawerOpen)
            
            // Drawer Overlay
            if isDrawerOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { isDrawerOpen = false }
                    }
                
                HStack(spacing: 0) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("历史会话")
                                .font(.title2)
                                .bold()
                            Spacer()
                            Button(action: {
                                withAnimation { isDrawerOpen = false }
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(connectionManager.sessions) { session in
                                    Button(action: {
                                        connectionManager.loadSession(id: session.id)
                                        withAnimation { isDrawerOpen = false }
                                        triggerHaptic(style: .light)
                                    }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(session.title)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Text(session.formattedDate)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(UIColor.systemBackground))
                                    }
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
                    .frame(width: 280)
                    .background(Color(UIColor.systemBackground))
                    .ignoresSafeArea(.all, edges: .bottom)
                    
                    Spacer()
                }
                .transition(.move(edge: .leading))
            }
        }
    }
    
    private var statusColor: Color {
        switch connectionManager.agentState.status {
        case "IDLE": return .green
        case "WORKING": return .orange
        case "SUSPENDED": return .red
        default: return .gray
        }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        connectionManager.sendMessage(inputText)
        inputText = ""
        triggerHaptic(style: .medium)
    }
    
    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enableHaptics else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    private func triggerNotificationHaptic(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard enableHaptics else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
