package tw.edu.citizenaction.soracompanion.qa

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StoreReleaseContractTest {
    @Test
    fun playStoreListingContainsRequiredEnglishPlusMetadata() {
        val listing = StoreReleaseContract.playStoreListing()

        assertEquals("English+", listing.appName)
        assertTrue(listing.shortDescription.length in 20..80)
        assertTrue(listing.shortDescription.contains("偏鄉"))
        assertTrue(listing.shortDescription.contains("英語"))
        assertTrue(listing.fullDescription.contains("情緒"))
        assertTrue(listing.fullDescription.contains("老師"))
        assertTrue(listing.fullDescription.contains("志工"))
        assertFalse(hasPrivateUseCharacter(listing.fullDescription))
        assertFalse(listing.fullDescription.contains('\uFFFD'))
        assertTrue(listing.contactEmail.contains("@"))
    }

    @Test
    fun privacyDeclarationCoversStudentLearningDataAndAiProxy() {
        val privacy = StoreReleaseContract.privacyDeclaration()

        assertTrue(privacy.dataTypes.contains("student learning records"))
        assertTrue(privacy.dataTypes.contains("class collaboration notes"))
        assertTrue(privacy.dataTypes.contains("AI support context"))
        assertEquals("server-side proxy", privacy.aiKeyLocation)
        assertFalse(privacy.allowsProductionKeyOnDevice)
    }

    @Test
    fun releaseChecklistBlocksStoreUntilSigningAndBackendAreReady() {
        val gate = StoreReleaseContract.storeReadinessGate(
            signedRelease = false,
            privacyPolicyUrlReady = true,
            backendDeployed = false,
            classroomConsentReady = true
        )

        assertFalse(gate.readyForStore)
        assertTrue(gate.blockers.contains("signed release"))
        assertTrue(gate.blockers.contains("backend deployment"))
    }

    @Test
    fun classroomPilotCanProceedBeforePublicStoreLaunch() {
        val gate = StoreReleaseContract.classroomPilotGate(
            debugApkBuilt = true,
            teacherBriefReady = true,
            testDeviceReady = true
        )

        assertTrue(gate.readyForPilot)
        assertEquals(emptyList<String>(), gate.blockers)
    }

    @Test
    fun buildArtifactInstructionsCoverApkAndAabOutputs() {
        val artifacts = StoreReleaseContract.buildArtifactInstructions()

        assertTrue(artifacts.any { it.kind == BuildArtifactKind.DebugApk && it.gradleTask == ":app:assembleDebug" })
        assertTrue(artifacts.any { it.kind == BuildArtifactKind.ReleaseAab && it.gradleTask == ":app:bundleRelease" })
        artifacts.forEach {
            assertTrue(it.outputPath.startsWith("app/build/outputs/"))
            assertTrue(it.whenToUse.isNotBlank())
        }
    }

    @Test
    fun playConsoleInternalTestChecklistSeparatesInternalTestFromPublicLaunch() {
        val checklist = StoreReleaseContract.playConsoleInternalTestChecklist()

        assertTrue(checklist.requiredItems.contains("signed Android App Bundle"))
        assertTrue(checklist.requiredItems.contains("internal tester email list"))
        assertTrue(checklist.requiredItems.contains("privacy policy URL"))
        assertTrue(checklist.requiredItems.contains("Data Safety draft"))
        assertFalse(checklist.readyForPublicLaunch)
    }

    @Test
    fun screenshotPlanCoversStudentTeacherAndVolunteerDemoMedia() {
        val plan = StoreReleaseContract.screenshotPlan()

        assertEquals(setOf("student", "teacher", "volunteer"), plan.groups.map { it.role }.toSet())
        plan.groups.forEach { group ->
            assertTrue(group.requiredScreens.size >= 4)
            assertTrue(group.videoScenario.isNotBlank())
            assertFalse(group.requiredScreens.any { it.contains("API") || it.contains("debug", ignoreCase = true) })
        }
    }

    @Test
    fun externalCredentialGapsAreExplicitBeforeStoreLaunch() {
        val gaps = StoreReleaseContract.externalCredentialGaps()

        assertTrue(gaps.any { it.id == "firebase-auth" && it.requiredForPublicLaunch })
        assertTrue(gaps.any { it.id == "google-services-json" && it.owner == "user-or-school" })
        assertTrue(gaps.any { it.id == "ai-proxy" && it.reason.contains("server") })
        assertTrue(gaps.any { it.id == "release-keystore" && it.requiredForPublicLaunch })
    }

    private fun hasPrivateUseCharacter(text: String): Boolean {
        return text.any { it.code in 0xE000..0xF8FF }
    }
}
