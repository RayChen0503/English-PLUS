import SwiftUI

struct StudentShellView: View {
    var body: some View {
        TabView {
            StudentHomeView()
                .tabItem {
                    Label("首頁", systemImage: "house")
                }

            PracticeCenterView()
                .tabItem {
                    Label("練習", systemImage: "pencil.and.list.clipboard")
                }

            SupportView()
                .tabItem {
                    Label("支持", systemImage: "heart")
                }

            StudentLearningMapView()
            .tabItem {
                Label("地圖", systemImage: "map")
            }
        }
    }
}
