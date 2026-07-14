import XCTest

final class EnglishPlusCriticalFlowsUITests: XCTestCase {
    private var app: XCUIApplication!

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
            email: "student.demo@englishplus.test",
            password: "EnglishPlusStudent2026!",
            requiresGuardianConsent: true
        )

        assertTabBarContains(["首頁", "練習", "班級", "支持", "地圖"])
    }

    func testTeacherCanSignInAcceptConsentAndReachTeacherNavigation() {
        launchAndEnterHome(
            roleIdentifier: "role.teacher",
            email: "teacher.demo@englishplus.test",
            password: "EnglishPlusTeacher2026!"
        )

        assertTabBarContains(["首頁", "班級", "接力", "報告"])
    }

    func testVolunteerCanSignInAcceptConsentAndReachVolunteerNavigation() {
        launchAndEnterHome(
            roleIdentifier: "role.volunteer",
            email: "volunteer.demo@englishplus.test",
            password: "EnglishPlusVolunteer2026!"
        )

        assertTabBarContains(["首頁", "班級", "接力", "紀錄"])
    }

    func testOfflineStudentStillReachesNavigationAndSeesRecoveryAction() {
        app.launchArguments.append("-EnglishPlusStartOffline")
        launchAndEnterHome(
            roleIdentifier: "role.student",
            email: "student.demo@englishplus.test",
            password: "EnglishPlusStudent2026!",
            requiresGuardianConsent: true
        )

        XCTAssertTrue(app.staticTexts["目前為離線模式"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["重試"].exists)
        assertTabBarContains(["首頁", "練習", "班級", "支持", "地圖"])
    }

    func testStudentNewJourneyKeepsOnePrimaryActionAndOptionalPractice() {
        launchAndEnterHome(
            roleIdentifier: "role.student",
            email: "student.demo@englishplus.test",
            password: "EnglishPlusStudent2026!",
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

        let emailField = app.textFields["auth.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["auth.password"]
        XCTAssertTrue(passwordField.exists)
        passwordField.tap()
        passwordField.typeText(password)

        tapWhenHittable(app.buttons["auth.submit"])

        let privacyConsent = app.buttons["consent.privacy"]
        tapWhenHittable(privacyConsent)
        tapWhenHittable(app.buttons["consent.ai"])
        if requiresGuardianConsent {
            tapWhenHittable(app.buttons["consent.guardian"])
        }

        let continueButton = app.buttons["consent.continue"]
        XCTAssertTrue(continueButton.isEnabled)
        tapWhenHittable(continueButton)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
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

    private func assertTabBarContains(_ labels: [String]) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists)
        for label in labels {
            XCTAssertTrue(tabBar.buttons[label].exists, "Missing tab: \(label)")
        }
    }
}
