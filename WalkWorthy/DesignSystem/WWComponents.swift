import SwiftUI

struct WWPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WWTypography.body(17).weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(WWColor.sapphire)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(WWColor.sage.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}
