import SwiftUI

/// 橘长的 5 种核心状态
enum AgentState: String, CaseIterable {
    case idle = "闲聊"
    case thinking = "思考"
    case working = "工作中"
    case success = "完成"
    case happy = "开心"
    
    /// 对应的 Assets 图片名称
    var imageName: String {
        switch self {
        case .idle: return "avatar_idle"
        case .thinking: return "avatar_thinking"
        case .working: return "avatar_working"
        case .success: return "avatar_done"
        case .happy: return "avatar_happy"
        }
    }
}

/// 动态头像组件
struct StatusAvatarView: View {
    let state: AgentState
    let size: CGFloat
    
    @State private var isBreathing = false
    
    var body: some View {
        ZStack {
            // 背景底座 (可选，增加一点层次感)
            Circle()
                .fill(AppTheme.surface1)
                .shadow(color: AppTheme.strokeSoft, radius: 4, x: 0, y: 2)
            
            // 头像图片
            Image(state.imageName)
                .resizable()
                .scaledToFit()
                // 稍微缩小一点，避免贴边
                .padding(size * 0.1)
                // 状态切换时的过渡动画
                .id(state.imageName)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 1.1).combined(with: .opacity)
                ))
                // 呼吸动效 (缩放 < 3%)
                .scaleEffect(isBreathing ? 1.02 : 0.98)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: state)
        .onAppear {
            // 开启轻微的呼吸动效，周期 2.5 秒
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

struct StatusAvatarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            ForEach(AgentState.allCases, id: \.self) { state in
                HStack(spacing: 16) {
                    StatusAvatarView(state: state, size: 64)
                    Text(state.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 40)
            }
        }
        .padding(.vertical, 40)
        .background(AppTheme.bgBase)
    }
}
