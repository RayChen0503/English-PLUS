import SwiftUI

struct TeacherShellView: View {
    var body: some View {
        TabView {
            TeacherHomeView()
                .tabItem {
                    Label("今日", systemImage: "tray.full")
                }

            Text("學生名單")
                .font(.title.bold())
                .tabItem {
                    Label("學生", systemImage: "person.3")
                }

            Text("待回應求助")
                .font(.title.bold())
                .tabItem {
                    Label("求助", systemImage: "bubble.left.and.bubble.right")
                }
        }
    }
}
