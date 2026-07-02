import SwiftUI

struct StudentShellView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    @State private var selectedTab: StudentTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            StudentHomeView()
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

            SupportView(
                onOpenPractice: {
                    selectedTab = .practice
                },
                onOpenHome: {
                    selectedTab = .home
                }
            )
                .tabItem {
                    Label("支持", systemImage: "heart")
                }
                .tag(StudentTab.support)

            StudentLearningMapView()
                .tabItem {
                    Label("地圖", systemImage: "map")
                }
                .tag(StudentTab.map)
        }
        .onChange(of: selectedTab) { _, tab in
            guard tab == .practice else { return }
            learningRepository.enterFreePracticeMode()
        }
    }
}

private enum StudentTab: Hashable {
    case home
    case practice
    case support
    case map
}
