import SwiftUI

enum AppTheme {
    static let brand = Color(red: 0.13, green: 0.45, blue: 0.96)
    static let brandDark = Color(red: 0.09, green: 0.31, blue: 0.78)
    static let accent = Color(red: 0.40, green: 0.33, blue: 0.93)
    static let pageBackground = Color(red: 0.95, green: 0.97, blue: 1.0)
    static let cardBackground = Color.white.opacity(0.85)
    static let subtleBorder = Color.black.opacity(0.06)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [brand, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var pageGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white, pageBackground],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct CardSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.subtleBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 6)
    }
}

extension View {
    func cardSurface() -> some View {
        modifier(CardSurfaceModifier())
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [AppTheme.brand, AppTheme.brandDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
