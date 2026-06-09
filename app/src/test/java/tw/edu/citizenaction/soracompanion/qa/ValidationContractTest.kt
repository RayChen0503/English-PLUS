package tw.edu.citizenaction.soracompanion.qa

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class ValidationContractTest {
    @Test
    fun automatedChecksCoverTestsAndBothApkBuilds() {
        val commands = ValidationContract.automatedChecks().map { it.gradleTask }

        assertTrue(commands.contains(":app:testDebugUnitTest"))
        assertTrue(commands.contains(":app:assembleDebug"))
        assertTrue(commands.contains(":app:assembleRelease"))
    }

    @Test
    fun smokeTestTouchesCorePrototypeFlows() {
        val flows = ValidationContract.manualSmokeTest().map { it.flowId }

        assertEquals(10, flows.size)
        assertTrue(flows.contains("student-home-next-action"))
        assertTrue(flows.contains("teacher-handoff"))
        assertTrue(flows.contains("ai-security-fallback"))
        assertTrue(flows.contains("sync-center"))
        assertTrue(flows.contains("question-bank"))
        assertTrue(flows.contains("report-export"))
    }

    @Test
    fun releaseGateBlocksLaunchUntilManualDeviceTestingIsComplete() {
        val gate = ValidationContract.releaseReadinessGate(
            automatedChecksPassed = true,
            manualSmokeTestPassed = false,
            physicalDeviceTested = false
        )

        assertFalse(gate.readyForStore)
        assertTrue(gate.blockers.contains("manual smoke test"))
        assertTrue(gate.blockers.contains("physical device test"))
    }

    @Test
    fun releaseGateAllowsClassroomPrototypeWhenRequiredChecksPass() {
        val gate = ValidationContract.releaseReadinessGate(
            automatedChecksPassed = true,
            manualSmokeTestPassed = true,
            physicalDeviceTested = true
        )

        assertTrue(gate.readyForStore)
        assertEquals(emptyList<String>(), gate.blockers)
    }

    @Test
    fun fullQaMatrixCoversAllRequiredRolePathsFromEntryToExit() {
        val matrix = ValidationContract.fullQaMatrix()
        val flowIds = matrix.map { it.flowId }

        assertEquals(
            listOf("student-happy-path", "student-free-practice", "student-support-path", "teacher-path", "volunteer-path"),
            flowIds
        )
        matrix.forEach { flow ->
            assertTrue(flow.entryScreen.isNotBlank())
            assertTrue(flow.exitEvidence.isNotBlank())
            assertTrue(flow.steps.size >= 4)
            assertFalse(flow.exposesInternalCopy)
            assertFalse(flow.hasDuplicateBottomNav)
            assertFalse(flow.hasRoleMixedActions)
        }
    }

    @Test
    fun fullQaAuditBlocksCompletionWhenHighImpactIssuesRemain() {
        val issue = QaIssue("qa-1", "student-support-path", "High", "Support route loops back unexpectedly.", true)
        val blocked = ValidationContract.fullQaCompletionGate(
            flowsWalked = true,
            highImpactIssues = listOf(issue),
            fullGradleVerificationPassed = true,
            githubCleanAfterPush = true
        )
        val ready = ValidationContract.fullQaCompletionGate(
            flowsWalked = true,
            highImpactIssues = emptyList(),
            fullGradleVerificationPassed = true,
            githubCleanAfterPush = true
        )

        assertFalse(blocked.ready)
        assertTrue(blocked.blockers.contains("high-impact issues"))
        assertTrue(ready.ready)
        assertEquals(emptyList<String>(), ready.blockers)
    }

    @Test
    fun round16RealityInventorySeparatesDoneWorkFromExternalDependencies() {
        val inventory = ValidationContract.productRealityInventory()
        val byId = inventory.associateBy { it.id }

        assertTrue(byId.getValue("local-learning-records").implementedInApp)
        assertFalse(byId.getValue("firebase-auth").implementedInApp)
        assertFalse(byId.getValue("cross-device-sync").implementedInApp)
        assertFalse(byId.getValue("secure-ai-proxy").implementedInApp)
        assertFalse(byId.getValue("formal-question-bank-license").implementedInApp)

        inventory.forEach { item ->
            assertTrue(item.userSafeStatus.isNotBlank())
            assertFalse(item.userSafeStatus.contains("demo", ignoreCase = true))
            assertFalse(item.userSafeStatus.contains("prototype", ignoreCase = true))
            assertFalse(item.userSafeStatus.contains("API"))
            if (!item.implementedInApp) {
                assertTrue(item.requiresExternalDecision)
                assertTrue(item.nextOwner in setOf("user", "school", "team"))
            }
        }
    }

    @Test
    fun round16NormalAppScreensDoNotExposePrototypeOrSetupCopy() {
        val mainActivity = File("src/main/java/tw/edu/citizenaction/soracompanion/MainActivity.kt")
            .takeIf { it.exists() }
            ?: File("app/src/main/java/tw/edu/citizenaction/soracompanion/MainActivity.kt")
        val source = mainActivity.readText()
        val forbiddenNormalScreenCopy = listOf(
            "本機展示帳號",
            "展示登入",
            "展示同步",
            "展示清單",
            "本機備援",
            "demo mode",
            "正式版",
            "尚未設定正式登入端點",
            "尚未設定雲端後端",
            "尚未設定協作後端",
            "尚未接雲端"
        )

        forbiddenNormalScreenCopy.forEach { phrase ->
            assertFalse("Normal app screens should not expose '$phrase'", source.contains(phrase))
        }
    }
}
