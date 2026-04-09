import Foundation
import SwiftUI

enum HomeBackgroundTheme: String, CaseIterable, Identifiable {
    case none = "None (Solid)"
    case morningGarden = "Morning Garden"
    case greenhouse = "Greenhouse Oasis"
    case mountain = "Mountain Dawn"

    var id: String { rawValue }

    var assetName: String? {
        switch self {
        case .none: return nil
        case .morningGarden: return "home_plant_background_morning_garden"
        case .greenhouse: return "home_plant_background_greenhouse"
        case .mountain: return "home_plant_background_mountain"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .none:
            return L10n.string(
                "settings.appearance.home_background.none",
                default: "None (Solid)"
            )
        case .morningGarden:
            return L10n.string(
                "settings.appearance.home_background.morning_garden",
                default: "Morning Garden"
            )
        case .greenhouse:
            return L10n.string(
                "settings.appearance.home_background.greenhouse_oasis",
                default: "Greenhouse Oasis"
            )
        case .mountain:
            return L10n.string(
                "settings.appearance.home_background.mountain_dawn",
                default: "Mountain Dawn"
            )
        }
    }
}
