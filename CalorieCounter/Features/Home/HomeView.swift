import SwiftUI
import SwiftData

struct HomeView: View {
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            if isShowingSplash {
                SplashScreen()
                    .transition(.opacity)
                    .zIndex(1)
            } else {
                MainTabBar()
                    .transition(.opacity)
                    .zIndex(0)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isShowingSplash = false
                }
            }
        }
    }
}

struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.accentColor
                .ignoresSafeArea()
            
            Image("apple")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
        }
    }
}


#Preview {
    HomeView()
        .modelContainer(for: Item.self, inMemory: true)
}
