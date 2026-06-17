import SwiftUI

struct TeacherShellView: View {
    var body: some View {
        TabView {
            TeacherHomeView()
                .tabItem {
                    Label("今日", systemImage: "tray.full")
                }

            TeacherStudentsView()
                .tabItem {
                    Label("學生", systemImage: "person.3")
                }

            TeacherRequestsView()
                .tabItem {
                    Label("求助", systemImage: "bubble.left.and.bubble.right")
                }
        }
    }
}
