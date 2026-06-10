package tw.edu.citizenaction.soracompanion.qa

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ProductReadinessContractTest {
    @Test
    fun defaultLocalPrototypeIsReadyForClassroomDemoButNotPublicLaunch() {
        val snapshot = ProductReadinessContract.defaultLocalPrototypeSnapshot()
        val report = ProductReadinessContract.evaluate(snapshot)

        assertTrue(report.readyForClassroomDemo)
        assertFalse(report.readyForInternalPilot)
        assertFalse(report.readyForPublicLaunch)
        assertTrue(report.statusLabel.contains("課堂展示"))
        assertTrue(report.blockersForInternalPilot.contains("test device"))
        assertTrue(report.blockersForPublicLaunch.contains("backend deployment"))
        assertTrue(report.blockersForPublicLaunch.contains("privacy policy URL"))
        assertTrue(report.blockersForPublicLaunch.contains("signed release"))
        assertFalse(report.honestSummary.contains("已上架"))
        assertFalse(report.honestSummary.contains("正式完成"))
    }

    @Test
    fun internalPilotRequiresQaConsentEvidenceAndTestDeviceButNotPublicBackend() {
        val snapshot = ProductReadinessContract.defaultLocalPrototypeSnapshot().copy(
            manualSmokeTestPassed = true,
            physicalDeviceTested = true,
            teacherBriefReady = true,
            classroomConsentReady = true,
            demoEvidenceAccepted = true
        )

        val report = ProductReadinessContract.evaluate(snapshot)

        assertTrue(report.readyForClassroomDemo)
        assertTrue(report.readyForInternalPilot)
        assertFalse(report.readyForPublicLaunch)
        assertEquals(emptyList<String>(), report.blockersForInternalPilot)
        assertTrue(report.nextAction.contains("後端"))
        assertTrue(report.blockersForPublicLaunch.contains("backend deployment"))
    }

    @Test
    fun publicLaunchRequiresExternalCredentialsSigningPrivacyPolicyAndQuestionBankLicense() {
        val snapshot = ProductReadinessContract.defaultLocalPrototypeSnapshot().copy(
            manualSmokeTestPassed = true,
            physicalDeviceTested = true,
            teacherBriefReady = true,
            classroomConsentReady = true,
            demoEvidenceAccepted = true,
            signedRelease = true,
            privacyPolicyUrlReady = true,
            backendDeployed = true,
            productionBackendGatePassed = true,
            questionBankLicenseReady = true,
            playDataSafetyReviewed = true
        )

        val report = ProductReadinessContract.evaluate(snapshot)

        assertTrue(report.readyForClassroomDemo)
        assertTrue(report.readyForInternalPilot)
        assertTrue(report.readyForPublicLaunch)
        assertEquals(emptyList<String>(), report.blockersForPublicLaunch)
        assertTrue(report.nextAction.contains("封閉測試名單"))
    }

    @Test
    fun readinessChecklistLinksToExistingContractsWithoutDuplicateRules() {
        val checklist = ProductReadinessContract.readinessChecklist()
        val ids = checklist.map { it.id }.toSet()

        assertTrue(ids.contains("qa-verification"))
        assertTrue(ids.contains("showcase-evidence"))
        assertTrue(ids.contains("privacy-consent"))
        assertTrue(ids.contains("backend-gate"))
        assertTrue(ids.contains("store-release"))
        assertTrue(ids.contains("question-bank-license"))
        checklist.forEach { item ->
            assertTrue(item.sourceContract.isNotBlank())
            assertTrue(item.acceptanceEvidence.isNotBlank())
            assertFalse(item.acceptanceEvidence.contains("TODO", ignoreCase = true))
            assertFalse(item.acceptanceEvidence.contains("debug", ignoreCase = true))
        }
    }
}
