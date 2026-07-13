import SwiftUI

struct VolunteerShellView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        TabView {
            VolunteerHomeView()
                .tabItem {
                    Label("首頁", systemImage: "heart.text.square")
                }

            VolunteerServiceClassesView()
                .tabItem {
                    Label("班級", systemImage: "person.3")
                }
                .badge(appStatePendingServiceCount)

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

    @EnvironmentObject private var appState: AppState

    private var appStatePendingServiceCount: Int {
        appState.volunteerServices.filter { $0.status == .pendingApproval }.count
    }
}
