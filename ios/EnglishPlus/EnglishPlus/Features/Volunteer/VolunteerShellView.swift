import SwiftUI

struct VolunteerShellView: View {
    var body: some View {
        TabView {
            VolunteerHomeView()
                .tabItem {
                    Label("今日", systemImage: "heart.text.square")
                }

            VolunteerHandoffView()
                .tabItem {
                    Label("接力", systemImage: "flag")
                }

            VolunteerStudentBriefsView()
                .tabItem {
                    Label("學生", systemImage: "person.crop.circle.badge.questionmark")
                }

            VolunteerRecordView()
                .tabItem {
                    Label("紀錄", systemImage: "list.bullet.rectangle")
                }

            VolunteerScriptView()
                .tabItem {
                    Label("腳本", systemImage: "text.bubble")
                }
        }
    }
}
