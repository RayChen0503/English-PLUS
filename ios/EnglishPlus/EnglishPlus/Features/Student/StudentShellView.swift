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

            NavigationStack {
                Text("學習地圖")
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(EPTheme.background)
            }
            .tabItem {
                Label("地圖", systemImage: "map")
            }
        }
    }
}
