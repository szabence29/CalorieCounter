import SwiftUI
import FirebaseAuth

enum AuthPhase { case loading, signedOut, signedIn }

struct RootView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @State private var phase: AuthPhase = .loading
    @State private var authHandle: AuthStateDidChangeListenerHandle?

    var body: some View {
        Group {
            switch phase {
            case .loading:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Checking session…").foregroundStyle(.secondary).font(.footnote)
                }

            case .signedOut:
                LoginView()

            case .signedIn:
                MainTabBar()
                    .task {
                        // Belépés után biztosítjuk, hogy a profil egyszer be legyen töltve.
                        if !profileStore.isLoaded { await profileStore.start() }
                    }
                    // Onboarding akkor jelenik meg, ha van user + betöltött profil + hiányos core adatok / nincs kész.
                    .fullScreenCover(
                        isPresented: Binding(
                            get: {
                                Auth.auth().currentUser != nil &&
                                profileStore.isLoaded &&
                                shouldShowOnboarding()
                            },
                            set: { _ in }
                        )
                    ) {
                        OnboardingView()
                    }
            }
        }
        .onAppear {
            // Auth listener frissíti a fázist login/logout eseményekre.
            guard authHandle == nil else { return }
            phase = .loading
            authHandle = Auth.auth().addStateDidChangeListener { _, user in
                if user != nil {
                    phase = .signedIn
                } else {
                    profileStore.logoutReset()
                    phase = .signedOut
                }
            }
        }
        .onDisappear {
            if let h = authHandle {
                Auth.auth().removeStateDidChangeListener(h)
                authHandle = nil
            }
        }
    }

    private func shouldShowOnboarding() -> Bool {
        // Minimal “kötelező” mezők: név + életkor, illetve onboardingCompleted flag.
        let p = profileStore.profile
        let missingCore =
            (p.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ||
            ((p.age ?? 0) <= 0)
        return (p.onboardingCompleted != true) || missingCore
    }
}
