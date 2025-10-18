// UserProfile.swift
import Foundation

/// Firestore-ban a /users/{uid} dokumentum tartalma.
/// Nincs szükség FirebaseFirestoreSwift-re; minden mező opcionális.
struct UserProfile: Codable, Equatable {
    var id: String?            // Firestore doc ID (általában az uid)
    var name: String?
    var age: Int?
    var sex: String?           // "male" | "female" | stb.

    var weightKg: Double?
    var heightCm: Double?
    var startingWeightKg: Double?
    var goalWeightKg: Double?

    var weightUnit: String?    // "kg" | "lbs"
    var heightUnit: String?    // "cm" | "ftIn"

    var activity: String?      // pl. "Moderately active"
    var goal: String?          // pl. "Maintain"
    var weeklyDeltaKg: Double?
}

/// Íráshoz: csak a nem-nil mezőket tesszük be a Firestore dokumentumba.
extension UserProfile {
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
        return d
    }
}
