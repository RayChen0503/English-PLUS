package tw.edu.citizenaction.soracompanion.qa

data class AutomatedCheck(
    val name: String,
    val gradleTask: String,
    val purpose: String
)

data class SmokeTestStep(
    val flowId: String,
    val screen: String,
    val expectedEvidence: String
)

data class ReleaseReadinessGate(
    val readyForStore: Boolean,
    val blockers: List<String>
)

data class FullQaFlow(
    val flowId: String,
    val role: String,
    val entryScreen: String,
    val steps: List<String>,
    val exitEvidence: String,
    val exposesInternalCopy: Boolean,
    val hasDuplicateBottomNav: Boolean,
    val hasRoleMixedActions: Boolean
)

data class QaIssue(
    val issueId: String,
    val flowId: String,
    val severity: String,
    val description: String,
    val requiresFixBeforePilot: Boolean
)

data class FullQaGate(
    val ready: Boolean,
    val blockers: List<String>
)

object ValidationContract {
    const val VALIDATION_SCHEMA_VERSION = 8

    fun automatedChecks(): List<AutomatedCheck> {
        return listOf(
            AutomatedCheck(
                name = "Unit tests",
                gradleTask = ":app:testDebugUnitTest",
                purpose = "Validate data contracts, auth, cloud sync, question bank, API security, and design system rules."
            ),
            AutomatedCheck(
                name = "Debug APK",
                gradleTask = ":app:assembleDebug",
                purpose = "Confirm Android Studio runnable prototype builds for emulator or phone demos."
            ),
            AutomatedCheck(
                name = "Release APK",
                gradleTask = ":app:assembleRelease",
                purpose = "Confirm a release variant can be produced before store-readiness work."
            )
        )
    }

    fun manualSmokeTest(): List<SmokeTestStep> {
        return listOf(
            SmokeTestStep("student-home-next-action", "Home", "Today-first action is visible without hunting."),
            SmokeTestStep("student-check-in", "CheckIn", "Mood changes produce short, low-pressure tasks."),
            SmokeTestStep("lesson-answer-flow", "Lesson", "Correct and wrong answers update learning state."),
            SmokeTestStep("ai-security-fallback", "AiLab", "No secure proxy falls back to local simulated support."),
            SmokeTestStep("teacher-handoff", "Handoff", "Teacher or volunteer can see evidence and next action."),
            SmokeTestStep("collaboration-sync", "Handoff", "Remote collaboration push/fetch entry is visible."),
            SmokeTestStep("sync-center", "SyncCenter", "Pending and synced states are understandable."),
            SmokeTestStep("question-bank", "QuestionBank", "Level, skill, source, and review state render."),
            SmokeTestStep("report-export", "Report", "Text/HTML/share report flow is reachable."),
            SmokeTestStep("design-system", "DesignSystem", "Tokens and component rules are visible in app.")
        )
    }

    fun releaseReadinessGate(
        automatedChecksPassed: Boolean,
        manualSmokeTestPassed: Boolean,
        physicalDeviceTested: Boolean
    ): ReleaseReadinessGate {
        val blockers = buildList {
            if (!automatedChecksPassed) add("automated checks")
            if (!manualSmokeTestPassed) add("manual smoke test")
            if (!physicalDeviceTested) add("physical device test")
        }
        return ReleaseReadinessGate(
            readyForStore = blockers.isEmpty(),
            blockers = blockers
        )
    }

    fun fullQaMatrix(): List<FullQaFlow> {
        return listOf(
            FullQaFlow(
                flowId = "student-happy-path",
                role = "student",
                entryScreen = "Role choice / student login",
                steps = listOf(
                    "Choose student track",
                    "Complete four-question check-in",
                    "Review today's mission",
                    "Answer assigned practice items",
                    "See mission completion encouragement"
                ),
                exitEvidence = "Student can tell today's task is complete and can continue optional practice.",
                exposesInternalCopy = false,
                hasDuplicateBottomNav = false,
                hasRoleMixedActions = false
            ),
            FullQaFlow(
                flowId = "student-free-practice",
                role = "student",
                entryScreen = "Student home / practice center",
                steps = listOf(
                    "Skip daily mission path",
                    "Open practice center",
                    "Choose level or question type",
                    "Answer one item",
                    "Return to support or map without being forced into check-in"
                ),
                exitEvidence = "Free practice remains optional and does not display daily-mission progress.",
                exposesInternalCopy = false,
                hasDuplicateBottomNav = false,
                hasRoleMixedActions = false
            ),
            FullQaFlow(
                flowId = "student-support-path",
                role = "student",
                entryScreen = "Student support center",
                steps = listOf(
                    "Open support center",
                    "Choose a low-pressure help reason",
                    "Send help request",
                    "View teacher reply thread",
                    "Return to one small practice item"
                ),
                exitEvidence = "Student sees support as a next step, not a staff-only workflow.",
                exposesInternalCopy = false,
                hasDuplicateBottomNav = false,
                hasRoleMixedActions = false
            ),
            FullQaFlow(
                flowId = "teacher-path",
                role = "teacher",
                entryScreen = "Teacher home",
                steps = listOf(
                    "Open class priority dashboard",
                    "Review high-risk and pending help counts",
                    "Open student detail",
                    "Write or review reply",
                    "Open report export"
                ),
                exitEvidence = "Teacher can identify the next student and action within one minute.",
                exposesInternalCopy = false,
                hasDuplicateBottomNav = false,
                hasRoleMixedActions = false
            ),
            FullQaFlow(
                flowId = "volunteer-path",
                role = "volunteer",
                entryScreen = "Volunteer handoff home",
                steps = listOf(
                    "Open handoff queue",
                    "Review one student request",
                    "Read suggested script",
                    "Leave internal handoff note",
                    "Return to volunteer home"
                ),
                exitEvidence = "Volunteer sees only support and handoff work, not teacher admin tools.",
                exposesInternalCopy = false,
                hasDuplicateBottomNav = false,
                hasRoleMixedActions = false
            )
        )
    }

    fun fullQaCompletionGate(
        flowsWalked: Boolean,
        highImpactIssues: List<QaIssue>,
        fullGradleVerificationPassed: Boolean,
        githubCleanAfterPush: Boolean
    ): FullQaGate {
        val unresolvedHighImpact = highImpactIssues.any {
            it.requiresFixBeforePilot && it.severity.equals("High", ignoreCase = true)
        }
        val blockers = buildList {
            if (!flowsWalked) add("required role flows")
            if (unresolvedHighImpact) add("high-impact issues")
            if (!fullGradleVerificationPassed) add("full Gradle verification")
            if (!githubCleanAfterPush) add("GitHub clean status")
        }
        return FullQaGate(ready = blockers.isEmpty(), blockers = blockers)
    }
}
