import SwiftUI

enum WWTypography {
    static func title(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static func section(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static func body(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    static func detail(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
}
