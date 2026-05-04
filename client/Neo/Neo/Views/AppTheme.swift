import SwiftUI

enum AppTheme {
    // MARK: - Colors (基于设计规范)
    
    /// BG / 背景底色 (奶油雾白)
    static let bgBase = Color(red: 251/255, green: 245/255, blue: 233/255)
    
    /// TabBar 背景色 (提取自切图背景)
    static let tabBg = Color(red: 251/255, green: 245/255, blue: 233/255)
    
    /// Surface-1 / 卡片底 (纯白)
    static let surface1 = Color.white
    
    /// Surface-2 / 次级底 (更暖的浅底)
    static let surface2 = Color(red: 251/255, green: 247/255, blue: 241/255)
    
    /// Input Bg / 输入框底色
    static let inputBg = Color(red: 238/255, green: 232/255, blue: 218/255)
    
    /// Text-Primary (深暖灰)
    static let textPrimary = Color(red: 31/255, green: 35/255, blue: 40/255)
    
    /// Text-Secondary
    static let textSecondary = Color(red: 91/255, green: 97/255, blue: 106/255)
    
    /// Text-Tertiary
    static let textTertiary = Color(red: 139/255, green: 146/255, blue: 156/255)
    
    /// Stroke-Soft (轻描边)
    static let strokeSoft = Color(red: 31/255, green: 35/255, blue: 40/255).opacity(0.08)
    static let strokeLighter = Color(red: 31/255, green: 35/255, blue: 40/255).opacity(0.06)
    
    /// Brand-Orange (橘长橘)
    static let brandOrange = Color(red: 245/255, green: 158/255, blue: 88/255)
    
    /// Brand-Orange-Soft (橘色浅底)
    static let brandOrangeSoft = Color(red: 255/255, green: 240/255, blue: 227/255)
    
    // MARK: - Radius Tokens
    static let rXS: CGFloat = 10
    static let rS: CGFloat = 14
    static let rM: CGFloat = 16
    static let rL: CGFloat = 20

    // MARK: - Gradients
    static var pageGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white, bgBase],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 255/255, green: 149/255, blue: 0/255), Color(red: 255/255, green: 94/255, blue: 58/255)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Modifiers

// MARK: - View Modifiers

/// 核心卡片样式：圆角 + 轻描边 + 轻阴影
struct SoftCardStyle: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.rM
    var backgroundColor: Color = AppTheme.surface1
    
    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.strokeLighter, lineWidth: 1)
            )
            .shadow(color: Color(red: 31/255, green: 35/255, blue: 40/255).opacity(0.06), radius: 24, x: 0, y: 8)
            .shadow(color: Color(red: 31/255, green: 35/255, blue: 40/255).opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

extension View {
    func softCard(cornerRadius: CGFloat = AppTheme.rM, backgroundColor: Color = AppTheme.surface1) -> some View {
        modifier(SoftCardStyle(cornerRadius: cornerRadius, backgroundColor: backgroundColor))
    }
}

// MARK: - Button Styles

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(AppTheme.brandOrange)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.rS, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
