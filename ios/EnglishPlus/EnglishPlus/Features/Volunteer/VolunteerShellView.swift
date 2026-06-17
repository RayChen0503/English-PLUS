import SwiftUI

struct VolunteerShellView: View {
    var body: some View {
        TabView {
            VolunteerHomeView()
                .tabItem {
                    Label("接力", systemImage: "flag")
                }

            VolunteerWaitingView()
                .tabItem {
                    Label("學生", systemImage: "person.crop.circle.badge.questionmark")
                }

            VolunteerRecordsView()
                .tabItem {
                    Label("紀錄", systemImage: "clock")
                }
        }
    }
}
