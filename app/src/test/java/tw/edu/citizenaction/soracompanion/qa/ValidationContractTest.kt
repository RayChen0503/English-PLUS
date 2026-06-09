package tw.edu.citizenaction.soracompanion.qa

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

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
}
