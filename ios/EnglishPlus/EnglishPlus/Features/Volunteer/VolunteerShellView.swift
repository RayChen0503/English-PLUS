import SwiftUI

struct VolunteerShellView: View {
    var body: some View {
        TabView {
            VolunteerHomeView()
                .tabItem {
                    Label("今日", systemImage: "heart.text.square")
                }

            VolunteerHandoffWorkspaceView()
                .tabItem {
                    Label("接力", systemImage: "flag")
                }

            VolunteerRecordView()
                .tabItem {
                    Label("紀錄", systemImage: "list.bullet.rectangle")
                }
        }
    }
}
