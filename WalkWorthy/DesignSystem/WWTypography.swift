import SwiftUI

enum WWTypography {
    static func display(_ size: CGFloat = 52) -> Font {
        .custom("PlusJakartaSans-Bold", size: size)
    }

    static func heading(_ size: CGFloat = 34) -> Font {
        .custom("PlusJakartaSans-Medium", size: size)
    }

    static func body(_ size: CGFloat = 17) -> Font {
        .custom("Inter-Regular", size: size)
    }

    static func caption(_ size: CGFloat = 14) -> Font {
        .custom("Inter-Regular", size: size)
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
}
