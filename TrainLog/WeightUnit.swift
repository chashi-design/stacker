import Foundation
import SwiftUI

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg
    case lb

    static let storageKey = "weightUnit"

    var id: String { rawValue }

    var unitLabel: String { rawValue }

    var conversionFactor: Double {
        switch self {
        case .kg:
            return 1.0
        case .lb:
            return 2.2046226218
        }
    }

    func displayValue(fromKg value: Double) -> Double {
        value * conversionFactor
    }

    func kgValue(fromDisplay value: Double) -> Double {
        value / conversionFactor
    }

    func formattedValue(
        fromKg value: Double,
        locale: Locale,
        maximumFractionDigits: Int,
        minimumFractionDigits: Int = 0
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = minimumFractionDigits
        let displayValue = displayValue(fromKg: value)
        return formatter.string(from: NSNumber(value: displayValue)) ?? String(displayValue)
    }
}

private struct WeightUnitKey: EnvironmentKey {
    static let defaultValue: WeightUnit = .kg
}

extension EnvironmentValues {
    var weightUnit: WeightUnit {
        get { self[WeightUnitKey.self] }
        set { self[WeightUnitKey.self] = newValue }
    }
}
