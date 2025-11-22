import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn
import FirebaseAuth

@main
struct CalorieCounterApp: App {
    // Firebase init AppDelegate-ben (ELÉG ITT, ne hívd még egyszer init-ben)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // ProfileStore a teljes appnak
    @StateObject private var profileStore = ProfileStore()

    // SwiftData container (maradhat ahogy volt)
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([ FoodItem.self ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView() // auth-alapú router
                .environmentObject(profileStore)
        }
        .modelContainer(sharedModelContainer)
    }
}

// Firebase setup – ELÓG ITT a configure()
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
        return GIDSignIn.sharedInstance.handle(url)
    }
}
