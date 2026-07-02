import SwiftUI

struct TeacherShellView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        TabView {
            TeacherHomeView()
                .tabItem {
                    Label("首頁", systemImage: "tray.full")
                }

            TeacherClassAssignmentView()
                .tabItem {
                    Label("班級", systemImage: "person.3.sequence")
                }

            TeacherHandoffView()
                .tabItem {
                    Label("接力", systemImage: "arrow.triangle.2.circlepath")
                }
                .badge(learningRepository.staffDashboardMetrics.waitingHelpCount)

            TeacherReportView()
                .tabItem {
                    Label("報告", systemImage: "doc.text.magnifyingglass")
                }
        }
    }
}
