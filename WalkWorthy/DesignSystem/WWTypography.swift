import SwiftUI
import UIKit

enum WWTypography {
    static func display(_ size: CGFloat = 52) -> Font {
        preferredFont(
            names: ["PlusJakartaSans-Bold", "PlusJakartaSansRoman-Bold"],
            size: size,
            fallbackWeight: .bold
        )
    }

    static func heading(_ size: CGFloat = 34) -> Font {
        preferredFont(
            names: ["PlusJakartaSans-Medium", "PlusJakartaSansRoman-Medium"],
            size: size,
            fallbackWeight: .medium
        )
    }

    static func body(_ size: CGFloat = 17) -> Font {
        preferredFont(
            names: ["Inter-Regular", "Inter"],
            size: size,
            fallbackWeight: .regular
        )
    }

    static func caption(_ size: CGFloat = 14) -> Font {
        preferredFont(
            names: ["Inter-Regular", "Inter"],
            size: size,
            fallbackWeight: .regular
        )
    }

    static func title(_ size: CGFloat = 34) -> Font {
        display(size)
    }

    static func section(_ size: CGFloat = 24) -> Font {
        heading(size)
    }

    static func detail(_ size: CGFloat = 14) -> Font {
        caption(size)
    }

    private static func preferredFont(
        names: [String],
        size: CGFloat,
        fallbackWeight: Font.Weight
    ) -> Font {
        for name in names where UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: fallbackWeight)
    }
}
