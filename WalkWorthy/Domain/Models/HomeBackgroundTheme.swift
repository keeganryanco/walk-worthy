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
}
