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
                Label("首頁", systemImage: selectedTab == .home ? "house.fill" : "house")
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
                Label("班級", systemImage: selectedTab == .classroom ? "person.3.fill" : "person.3")
            }
            .badge(pendingAssignmentCount)
            .tag(StudentTab.classroom)

            SupportView()
            .tabItem {
                Label("支持", systemImage: selectedTab == .support ? "heart.fill" : "heart")
            }
            .badge(unreadSupportReplyCount)
            .tag(StudentTab.support)

            StudentLearningMapView(
                onOpenHome: {
                    selectedTab = .home
                }
            )
            .tabItem {
                Label("地圖", systemImage: selectedTab == .map ? "map.fill" : "map")
            }
            .tag(StudentTab.map)
        }
        .tint(EPTheme.primary)
    }

    private var pendingAssignmentCount: Int {
        let studentUid = appState.currentUser?.id ?? appState.currentProfile?.id
        guard let studentUid else { return 0 }
        return learningRepository.assignedPracticeTasks
            .filter { $0.studentUid == studentUid && ($0.status == .pending || $0.status == .active) }
            .count
    }

    private var unreadSupportReplyCount: Int {
        let studentUid = appState.currentUser?.id ?? appState.currentProfile?.id
        return learningRepository.supportRequests(forStudentUid: studentUid)
            .filter(\.hasStudentUnreadReply)
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
