// ProfileStore.swift
import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Egyetlen igazságforrás a felhasználói profilhoz.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profile = UserProfile()
    @Published private(set) var isLoaded = false
    @Published private(set) var isNewUser = false
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    deinit { listener?.remove() }

    private func ref(uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    /// Bejelentkezett user esetén betölt és feliratkozik a /users/{uid} dokumentumra.
    func start() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Nincs bejelentkezett felhasználó."
            return
        }

        do {
            let r = ref(uid: uid)
            let snap = try await r.getDocument()
            if !snap.exists {
                // Új user: hozzunk létre egy kezdő dokumentumot
                isNewUser = true
                try await r.setData([
                    "onboardingCompleted": false,
                    "createdAt": FieldValue.serverTimestamp()
                ], merge: true)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        listener?.remove()
        listener = ref(uid: uid).addSnapshotListener { [weak self] snap, err in
            Task { @MainActor in
                if let err {
                    self?.errorMessage = err.localizedDescription
                    return
                }
                guard let snap, let data = snap.data() else { return }
                self?.profile = Self.map(dict: data, id: snap.documentID)
                self?.isLoaded = true
            }
        }
    }

    /// Teljes modell írása (merge: true).
    func save(_ new: UserProfile) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do { try await ref(uid: uid).setData(new.asDict, merge: true) }
        catch { errorMessage = error.localizedDescription }
    }

    /// Részleges frissítés.
    func update(fields: [String: Any]) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do { try await ref(uid: uid).setData(fields, merge: true) }
        catch { errorMessage = error.localizedDescription }
    }

    /// Onboarding flag beállítása true-ra (kényelmi).
    func markOnboardingCompleted() async {
        await update(fields: ["onboardingCompleted": true])
        isNewUser = false
    }

    /// Kilépés után a store ürítése (villanás elkerülésére).
    func logoutReset() {
        listener?.remove(); listener = nil
        profile = UserProfile()
        isLoaded = false
        isNewUser = false
        errorMessage = nil
    }

    // MARK: - Mapping

    private static func map(dict: [String: Any], id: String?) -> UserProfile {
        var p = UserProfile()
        p.id = id
        p.name = dict["name"] as? String
        p.age = dict["age"] as? Int
        p.sex = dict["sex"] as? String
        p.weightKg = dict["weightKg"] as? Double
        p.heightCm = dict["heightCm"] as? Double
        p.startingWeightKg = dict["startingWeightKg"] as? Double
        p.goalWeightKg = dict["goalWeightKg"] as? Double
        p.weightUnit = dict["weightUnit"] as? String
        p.heightUnit = dict["heightUnit"] as? String
        p.activity = dict["activity"] as? String
        p.goal = dict["goal"] as? String
        p.weeklyDeltaKg = dict["weeklyDeltaKg"] as? Double
        p.onboardingCompleted = dict["onboardingCompleted"] as? Bool

        if let ts = dict["createdAt"] as? Timestamp {
            p.createdAt = ts.dateValue()
        }
        return p
    }
}
