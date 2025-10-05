import SwiftUI
import SwiftData

struct HomeView: View {
    var body: some View {
        MainTabBar()
    }
}

#Preview {
    HomeView()
        .modelContainer(for: Item.self, inMemory: true)
}
