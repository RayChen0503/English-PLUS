import SwiftUI

struct VolunteerShellView: View {
    var body: some View {
        TabView {
            VolunteerHomeView()
                .tabItem {
                    Label("接力", systemImage: "flag")
                }

            Text("等待陪伴")
                .font(.title.bold())
                .tabItem {
                    Label("學生", systemImage: "person.crop.circle.badge.questionmark")
                }

            Text("回覆紀錄")
                .font(.title.bold())
                .tabItem {
                    Label("紀錄", systemImage: "clock")
                }
        }
    }
}
