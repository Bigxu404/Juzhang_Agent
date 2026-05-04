import SwiftUI

enum TabSelection {
    case chat
    case settings
}

struct MainTabView: View {
    @State private var selection: TabSelection = .chat
    @State private var showDrawer = false
    @ObservedObject private var connectionManager = AgentConnectionManager.shared
    
    var body: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                // 1. 页面内容区
                Group {
                    switch selection {
                    case .chat:
                        ChatView(showDrawer: $showDrawer)
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 2. 底部 TabBar
                CustomBottomNav(selection: $selection)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            
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
                    .frame(maxHeight: .infinity)
                    .background(AppTheme.bgBase.ignoresSafeArea())
                    .transition(.move(edge: .leading))
                    .zIndex(101)
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
}

struct CustomBottomNav: View {
    @Binding var selection: TabSelection
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TabBarItem(
                    icon: selection == .chat ? "chat1" : "chat2",
                    title: "对话",
                    isSelected: selection == .chat,
                    action: { selection = .chat }
                )
                
                TabBarItem(
                    icon: "setting",
                    title: "设置",
                    isSelected: selection == .settings,
                    action: { selection = .settings }
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .background(AppTheme.bgBase.ignoresSafeArea(.all, edges: .bottom))
    }
}

struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
