// UserProfile.swift
import Foundation

/// Firestore: /users/{uid}
/// Minden mező opcionális; az app a ProfileStore-on át kezeli.
struct UserProfile: Codable, Equatable {
    var id: String?                    // doc ID (ált. uid)
    var name: String?
    var age: Int?
    var sex: String?                   // "male" | "female"

    var weightKg: Double?
    var heightCm: Double?
    var startingWeightKg: Double?
    var goalWeightKg: Double?

    var weightUnit: String?            // "kg" | "lbs"
    var heightUnit: String?            // "cm" | "ftIn"

    var activity: String?              // "Moderately active" stb.
    var goal: String?                  // "Lose weight" | "Maintain" | "Gain muscle"
    var weeklyDeltaKg: Double?

    // Onboarding
    var onboardingCompleted: Bool?
    var createdAt: Date?               // szerver időbélyeg (map-elve Timestamp-ből)
}

extension UserProfile {
    /// Íráshoz: csak a nem-nil mezőket tesszük be a dokumentumba.
    var asDict: [String: Any] {
        var d: [String: Any] = [:]
        if let name { d["name"] = name }
        if let age { d["age"] = age }
        if let sex { d["sex"] = sex }

        if let weightKg { d["weightKg"] = weightKg }
        if let heightCm { d["heightCm"] = heightCm }
        if let startingWeightKg { d["startingWeightKg"] = startingWeightKg }
        if let goalWeightKg { d["goalWeightKg"] = goalWeightKg }

        if let weightUnit { d["weightUnit"] = weightUnit }
        if let heightUnit { d["heightUnit"] = heightUnit }

        if let activity { d["activity"] = activity }
        if let goal { d["goal"] = goal }
        if let weeklyDeltaKg { d["weeklyDeltaKg"] = weeklyDeltaKg }

        if let onboardingCompleted { d["onboardingCompleted"] = onboardingCompleted }
        if let createdAt { d["createdAt"] = createdAt }
        return d
    }
}

// MARK: - Calorie helpers

extension UserProfile {

    /// Mifflin–St Jeor BMR (kcal/nap)
    /// Visszatér nil-lel, ha hiányzik valamelyik adat.
    var bmrEstimate: Double? {
        guard
            let weightKg,
            let heightCm,
            let age,
            let sex
        else {
            return nil
        }

        let w = weightKg
        let h = heightCm
        let a = Double(age)

        if sex.lowercased() == "male" {
            // férfi
            return 10.0 * w + 6.25 * h - 5.0 * a + 5.0
        } else {
            // nő
            return 10.0 * w + 6.25 * h - 5.0 * a - 161.0
        }
    }

    /// Aktivitási szorzó (ugyanaz, mint a SettingsView-ban)
    private var activityFactor: Double {
        switch activity {
        case "Sedentary":         return 1.2
        case "Lightly active":    return 1.375
        case "Moderately active": return 1.55
        case "Very active":       return 1.725
        case "Athlete":           return 1.9
        default:                  return 1.55
        }
    }

    /// TDEE = BMR * aktivitási faktor
    var tdeeEstimate: Double? {
        guard let bmrEstimate else { return nil }
        return bmrEstimate * activityFactor
    }

    /// Javasolt napi kalória a heti súlyváltozás alapján.
    /// Pontosan ugyanaz a logika, mint a SettingsView-ban az adjustedCalories():
    ///   tdee + (weeklyDeltaKg * 7700) / 7
    var suggestedDailyCalories: Int? {
        guard let tdeeEstimate else { return nil }

        let weeklyDelta = weeklyDeltaKg ?? 0.0
        let adjusted = tdeeEstimate + (weeklyDelta * 7700.0) / 7.0

        return Int(adjusted.rounded())
    }
}
