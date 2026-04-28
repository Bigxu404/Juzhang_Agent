import SwiftUI

enum TabSelection {
    case chat
    case memory
    case settings
}

struct MainTabView: View {
    @State private var selection: TabSelection = .chat
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. 页面内容区
            Group {
                switch selection {
                case .chat:
                    ChatView()
                case .memory:
                    MemoryVaultView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 2. 自定义底部导航栏 (Bottom Nav)
            CustomBottomNav(selection: $selection)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct CustomBottomNav: View {
    @Binding var selection: TabSelection
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarItem(
                icon: "message.fill",
                title: "对话",
                isSelected: selection == .chat,
                action: { selection = .chat }
            )
            
            TabBarItem(
                icon: "archivebox.fill",
                title: "藏宝库",
                isSelected: selection == .memory,
                action: { selection = .memory }
            )
            
            TabBarItem(
                icon: "gearshape.fill",
                title: "设置",
                isSelected: selection == .settings,
                action: { selection = .settings }
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, safeAreaBottom + 8)
        .background(
            AppTheme.surface1.opacity(0.95)
                .shadow(color: AppTheme.strokeSoft, radius: 16, x: 0, y: -4)
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppTheme.strokeLighter),
            alignment: .top
        )
    }
    
    private var safeAreaBottom: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        return window?.safeAreaInsets.bottom ?? 0
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
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                
                // 选中态：橘色小圆点点睛
                Circle()
                    .fill(isSelected ? AppTheme.brandOrange : Color.clear)
                    .frame(width: 4, height: 4)
                    .padding(.top, 2)
            }
            .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textTertiary)
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
