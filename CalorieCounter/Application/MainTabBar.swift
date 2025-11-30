import SwiftUI

struct MainTabBar: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
            AddView()
                .tabItem {
                    Image(systemName: "plus.circle")
                    Text("Add")
                }
            ContentView()
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("Chat")
                }
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }
        }
    }
}

#Preview {
    MainTabBar()
}
