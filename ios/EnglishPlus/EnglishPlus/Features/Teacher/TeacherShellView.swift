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

            TeacherHandoffView()
                .tabItem {
                    Label("接力", systemImage: "arrow.triangle.2.circlepath")
                }

            TeacherReportView()
                .tabItem {
                    Label("報告", systemImage: "doc.text.magnifyingglass")
                }

            TeacherQuestionBankView()
                .tabItem {
                    Label("題庫", systemImage: "books.vertical")
                }
        }
    }
}
