import XCTest

final class EnglishPlusCriticalFlowsUITests: XCTestCase {
    private var app: XCUIApplication!
    private let uiTestPassword = "not-a-real-secret"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-EnglishPlusUITesting",
            "-EnglishPlusResetState"
        ]
    }

    func testColdLaunchShowsRoleChoiceAndLegalEntryPoints() {
        app.launch()

        XCTAssertTrue(app.buttons["role.student"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["role.teacher"].exists)
        XCTAssertTrue(app.buttons["role.volunteer"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["閱讀完整隱私政策"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["支援與聯絡"].exists)
    }

    func testStudentCanSignInAcceptConsentAndReachStudentNavigation() {
        launchAndEnterHome(
            roleIdentifier: "role.student",
            email: "student@ui-test.invalid",
            password: uiTestPassword,
            requiresGuardianConsent: true
        )

        assertTabBarContains(["首頁", "練習", "班級", "支持", "地圖"])
    }

    func testTeacherCanSignInAcceptConsentAndReachTeacherNavigation() {
        launchAndEnterHome(
            roleIdentifier: "role.teacher",
            email: "teacher@ui-test.invalid",
            password: uiTestPassword
        )

        assertTabBarContains(["首頁", "班級", "接力", "報告"])
    }

    func testVolunteerCanSignInAcceptConsentAndReachVolunteerNavigation() {
        launchAndEnterHome(
            roleIdentifier: "role.volunteer",
            email: "volunteer@ui-test.invalid",
            password: uiTestPassword
        )

        assertTabBarContains(["首頁", "班級", "接力", "紀錄"])
    }

    func testDarkModeAndAccessibilityTextKeepRoleChoiceUsable() {
        app.launchArguments.append(contentsOf: [
            "-AppleInterfaceStyle", "Dark",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
        ])
        app.launch()

        let studentButton = app.buttons["role.student"]
        XCTAssertTrue(studentButton.waitForExistence(timeout: 5))
        XCTAssertTrue(studentButton.isHittable)
        XCTAssertTrue(app.buttons["role.teacher"].exists)
        XCTAssertTrue(app.buttons["role.volunteer"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["閱讀完整隱私政策"].exists)
    }

    func testTeacherWorkspaceKeepsDailyActionsSeparateFromSettingsAndReportDetail() {
        launchAndEnterHome(
            roleIdentifier: "role.teacher",
            email: "teacher@ui-test.invalid",
            password: uiTestPassword
        )

        app.tabBars.buttons["班級"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["teacher.class.settings"].waitForExistence(timeout: 5))

        app.tabBars.buttons["報告"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["teacher.report.preview"].waitForExistence(timeout: 5))
    }

    func testOfflineStudentStillReachesNavigationAndSeesRecoveryAction() {
        app.launchArguments.append("-EnglishPlusStartOffline")
        launchAndEnterHome(
            roleIdentifier: "role.student",
            email: "student@ui-test.invalid",
            password: uiTestPassword,
            requiresGuardianConsent: true
        )

        XCTAssertTrue(app.staticTexts["目前為離線模式"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["重試"].exists)
        assertTabBarContains(["首頁", "練習", "班級", "支持", "地圖"])
    }

    func testDarkModeLargeTextStudentFlowKeepsPrimaryActionsReachable() {
        app.launchArguments.append(contentsOf: [
            "-AppleInterfaceStyle", "Dark",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraLarge",
        ])
        launchAndEnterHome(
            roleIdentifier: "role.student",
            email: "student@ui-test.invalid",
            password: uiTestPassword,
            requiresGuardianConsent: true
        )

        assertTabBarContains(["首頁", "練習", "班級", "支持", "地圖"])
        app.tabBars.buttons["練習"].tap()
        XCTAssertTrue(app.buttons["請 AI 推薦練習"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["開始這組練習"].exists)
    }

    func testStudentNewJourneyKeepsOnePrimaryActionAndOptionalPractice() {
        launchAndEnterHome(
            roleIdentifier: "role.student",
            email: "student@ui-test.invalid",
            password: uiTestPassword,
            requiresGuardianConsent: true
        )

        XCTAssertTrue(app.staticTexts["今天先從四題開始"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["產生今日任務"].exists)
        XCTAssertFalse(app.staticTexts["先完成心情檢測"].exists)

        app.tabBars.buttons["練習"].tap()
        XCTAssertTrue(app.staticTexts["不知道要練什麼？"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["請 AI 推薦練習"].exists)
        XCTAssertTrue(app.buttons["開始這組練習"].exists)

        app.tabBars.buttons["地圖"].tap()
        XCTAssertTrue(app.buttons["前往心情檢測"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["選用"].exists)
    }

    func testStudentEveryPrimaryWorkspaceHasAReachablePurpose() {
        launchAndEnterHome(
            roleIdentifier: "role.student",
            email: "student@ui-test.invalid",
            password: uiTestPassword,
            requiresGuardianConsent: true
        )

        XCTAssertTrue(app.descendants(matching: .any)["student.home.header"].waitForExistence(timeout: 5))
        capture("student-01-home")

        app.tabBars.buttons["練習"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["student.practice.selectionHeader"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["student.practice.filters"].exists)
        capture("student-02-practice")

        app.tabBars.buttons["班級"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["student.classroom.header"].waitForExistence(timeout: 5)
                || app.descendants(matching: .any)["student.classroom.personalMode"].waitForExistence(timeout: 2)
        )
        capture("student-03-classroom")

        app.tabBars.buttons["支持"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["student.support.inbox"].waitForExistence(timeout: 5))
        capture("student-04-support")

        app.tabBars.buttons["地圖"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["student.map.primaryAction"].waitForExistence(timeout: 5))
        capture("student-05-map")
    }

    func testTeacherEveryPrimaryWorkspaceHasAReachablePurpose() {
        launchAndEnterHome(
            roleIdentifier: "role.teacher",
            email: "teacher@ui-test.invalid",
            password: uiTestPassword
        )

        XCTAssertTrue(app.descendants(matching: .any)["teacher.home.workspace"].waitForExistence(timeout: 5))
        capture("teacher-01-home")

        app.tabBars.buttons["班級"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["teacher.class.workspace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["teacher.class.settings"].exists)
        capture("teacher-02-class")

        app.tabBars.buttons["接力"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["teacher.handoff.workspace"].waitForExistence(timeout: 5))
        capture("teacher-03-handoff")

        app.tabBars.buttons["報告"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["teacher.report.workspace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["teacher.report.preview"].exists)
        capture("teacher-04-report")
    }

    func testVolunteerEveryPrimaryWorkspaceHasAReachablePurpose() {
        launchAndEnterHome(
            roleIdentifier: "role.volunteer",
            email: "volunteer@ui-test.invalid",
            password: uiTestPassword
        )

        XCTAssertTrue(app.descendants(matching: .any)["volunteer.home.workspace"].waitForExistence(timeout: 5))
        capture("volunteer-01-home")

        app.tabBars.buttons["班級"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["volunteer.service.workspace"].waitForExistence(timeout: 5))
        capture("volunteer-02-service-classes")

        app.tabBars.buttons["接力"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["volunteer.handoff.workspace"].waitForExistence(timeout: 5))
        capture("volunteer-03-handoff")

        app.tabBars.buttons["紀錄"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["volunteer.records.workspace"].waitForExistence(timeout: 5))
        capture("volunteer-04-records")
    }

    private func launchAndEnterHome(
        roleIdentifier: String,
        email: String,
        password: String,
        requiresGuardianConsent: Bool = false
    ) {
        app.launch()
        let roleButton = app.buttons[roleIdentifier]
        XCTAssertTrue(roleButton.waitForExistence(timeout: 5))
        roleButton.tap()

        let authenticationScreen = app.scrollViews["auth.screen"]
        XCTAssertTrue(authenticationScreen.waitForExistence(timeout: 8))

        let emailField = app.textFields["auth.email"]
        scrollUntilHittable(emailField, in: authenticationScreen)
        emailField.tap()
        emailField.typeText(email)
        emailField.typeText("\n")

        let passwordField = app.secureTextFields["auth.password"]
        scrollUntilHittable(passwordField, in: authenticationScreen)
        passwordField.tap()
        passwordField.typeText(password)

        let dismissKeyboardButton = app.buttons["auth.keyboard.dismiss"]
        if dismissKeyboardButton.waitForExistence(timeout: 2) {
            dismissKeyboardButton.tap()
        }

        tapWhenHittable(app.buttons["auth.submit"])

        let privacyConsent = app.buttons["consent.privacy"]
        acceptConsent(privacyConsent)
        acceptConsent(app.buttons["consent.ai"])
        if requiresGuardianConsent {
            acceptConsent(app.buttons["consent.guardian"])
        }

        let continueButton = app.buttons["consent.continue"]
        waitUntilEnabled(continueButton)
        tapWhenHittable(continueButton)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }

    private func acceptConsent(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        tapWhenHittable(element, file: file, line: line)
        let accepted = NSPredicate(format: "value == %@", "已同意")
        let expectation = XCTNSPredicateExpectation(predicate: accepted, object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 5),
            .completed,
            file: file,
            line: line
        )
    }

    private func waitUntilEnabled(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        let enabled = NSPredicate(format: "enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: enabled, object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 8),
            .completed,
            file: file,
            line: line
        )
    }

    private func tapWhenHittable(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        for _ in 0..<6 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, file: file, line: line)
        element.tap()
    }

    private func scrollUntilHittable(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for _ in 0..<8 {
            if element.exists && element.isHittable {
                return
            }
            scrollView.swipeUp()
        }
        XCTAssertTrue(element.exists, file: file, line: line)
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }

    private func assertTabBarContains(_ labels: [String]) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists)
        for label in labels {
            XCTAssertTrue(tabBar.buttons[label].exists, "Missing tab: \(label)")
        }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
