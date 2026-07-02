import SwiftUI

struct VolunteerShellView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        TabView {
            VolunteerHomeView()
                .tabItem {
                    Label("首頁", systemImage: "heart.text.square")
                }

            VolunteerHandoffWorkspaceView()
                .tabItem {
                    Label("接力", systemImage: "flag")
                }
                .badge(learningRepository.volunteerDashboardMetrics.waitingCount)

            VolunteerRecordView()
                .tabItem {
                    Label("紀錄", systemImage: "list.bullet.rectangle")
                }
        }
    }
}
