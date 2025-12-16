import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn
import FirebaseAuth

@main
struct CalorieCounterApp: App {
    // Firebase init + Google Sign-In URL callback miatt kell AppDelegate.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // App-szintű profil/session store (EnvironmentObjectként megy le a view hierarchián).
    @StateObject private var profileStore = ProfileStore()

    // SwiftData perzisztencia (FoodItem, FoodLogEntry). App-wide, egy konténer példány.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FoodItem.self,
            FoodLogEntry.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView() // belépési állapot alapján router: Login vs Main
                .environmentObject(profileStore)
        }
        .modelContainer(sharedModelContainer)
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }

    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // OAuth redirect URL kezelése Google Sign-In-nál.
        return GIDSignIn.sharedInstance.handle(url)
    }
}
