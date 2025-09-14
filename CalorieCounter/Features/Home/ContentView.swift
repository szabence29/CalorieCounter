import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        MainTabBar()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
