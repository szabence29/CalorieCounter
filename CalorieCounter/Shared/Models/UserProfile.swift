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
