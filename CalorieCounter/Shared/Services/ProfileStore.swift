// ProfileStore.swift
import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Egyetlen igazságforrás a felhasználói profilhoz.
/// - Betöltés & realtime figyelés a /users/{uid} dokumentumra
/// - Mentés: teljes (save) vagy részleges (update(fields:))
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profile = UserProfile()
    @Published private(set) var isLoaded = false
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    deinit { listener?.remove() }

    private func ref(uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    /// Indításkor betölti és feliratkozik változásokra.
    func start() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Nincs bejelentkezett felhasználó."
            return
        }

        // Ha a dokumentum nem létezik, hozzunk létre egy üreset (később mezőnként frissítünk).
        do {
            let snap = try await ref(uid: uid).getDocument()
            if !snap.exists {
                try await ref(uid: uid).setData([:])
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

    /// Teljes modell mentése (merge: true, hogy a hiányzó mezők ne töröljenek).
    func save(_ new: UserProfile) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do { try await ref(uid: uid).setData(new.asDict, merge: true) }
        catch { errorMessage = error.localizedDescription }
    }

    /// Részleges frissítés 1-2 mezőre.
    func update(fields: [String: Any]) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do { try await ref(uid: uid).setData(fields, merge: true) }
        catch { errorMessage = error.localizedDescription }
    }

    /// Dict -> Modell leképezés (FirestoreSwift nélkül).
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
        return p
    }
}
