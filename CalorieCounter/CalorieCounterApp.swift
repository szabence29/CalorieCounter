import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn
import Firebase

@main
struct CalorieCounterApp: App {
    // Connect the UIKit app delegate to SwiftUI for Firebase initialization
    // This allows Firebase to be properly initialized at app launch
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Setup the database container for SwiftData
    // Defines the database scheme
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FoodItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)") //If fail the app crashes
        }
    }()

    // Define the app's UI structure
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(sharedModelContainer) // Make the database container available throughout the app
    }
}

// App delegate for Firebase setup
// Initialize Firebase with settings from GoogleService-Info.plist
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
