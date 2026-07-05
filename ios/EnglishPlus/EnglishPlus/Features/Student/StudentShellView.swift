import SwiftUI

struct StudentShellView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: StudentTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            StudentHomeView(
                onOpenSupport: {
                    selectedTab = .support
                },
                onOpenPractice: {
                    selectedTab = .practice
                }
            )
            .tabItem {
                Label("首頁", systemImage: "house")
            }
            .tag(StudentTab.home)

            PracticeCenterView(
                onOpenSupport: {
                    selectedTab = .support
                }
            )
            .tabItem {
                Label("練習", systemImage: "pencil.and.list.clipboard")
            }
            .tag(StudentTab.practice)

            StudentClassroomView(
                onOpenHome: {
                    selectedTab = .home
                }
            )
            .tabItem {
                Label("班級", systemImage: "person.3")
            }
            .badge(pendingAssignmentCount)
            .tag(StudentTab.classroom)

            SupportView()
            .tabItem {
                Label("支持", systemImage: "heart")
            }
            .tag(StudentTab.support)

            StudentLearningMapView(
                onOpenHome: {
                    selectedTab = .home
                }
            )
            .tabItem {
                Label("地圖", systemImage: "map")
            }
            .tag(StudentTab.map)
        }
        .onChange(of: selectedTab) { _, tab in
            guard tab == .practice else { return }
            Task { @MainActor in
                learningRepository.enterFreePracticeMode()
            }
        }
    }

    private var pendingAssignmentCount: Int {
        let studentUid = appState.currentUser?.id ?? appState.currentProfile?.id
        guard let studentUid else { return 0 }
        return learningRepository.assignedPracticeTasks
            .filter { $0.studentUid == studentUid && ($0.status == .pending || $0.status == .active) }
            .count
    }
}

private enum StudentTab: Hashable {
    case home
    case practice
    case classroom
    case support
    case map
}
