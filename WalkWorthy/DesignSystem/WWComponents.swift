import SwiftUI

struct WWPrimaryButtonStyle: ButtonStyle {
    var background: Color = WWColor.growGreen
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WWTypography.heading(34))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(background)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct WWCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(WWColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.black.opacity(0.03), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

struct TendPillButton: View {
    let title: String
    var selected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(WWTypography.heading(35))
                .foregroundStyle(selected ? WWColor.nearBlack : WWColor.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(WWColor.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(selected ? WWColor.growGreen : .clear, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}
