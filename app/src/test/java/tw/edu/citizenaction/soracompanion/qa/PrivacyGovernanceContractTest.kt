package tw.edu.citizenaction.soracompanion.qa

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PrivacyGovernanceContractTest {
    @Test
    fun emotionalSupportDataIsSensitiveAndNeverPublic() {
        val catalog = PrivacyGovernanceContract.dataCatalog()
        val emotional = catalog.first { it.type == StudentDataType.EmotionalSupport }

        assertTrue(emotional.sensitive)
        assertFalse(emotional.visibleToOtherStudents)
        assertTrue(emotional.allowedViewers.contains("授課老師"))
        assertTrue(emotional.allowedViewers.contains("指定志工"))
        assertTrue(emotional.purpose.contains("支持"))
    }

    @Test
    fun publicRankingLanguageIsBlocked() {
        val guardrail = PrivacyGovernanceContract.publicComparisonGuardrail()

        assertFalse(guardrail.allowPublicRanking)
        assertFalse(guardrail.isPublicCopyAllowed("本週排行榜第一名"))
        assertFalse(guardrail.isPublicCopyAllowed("全班排名第 3"))
        assertTrue(guardrail.isPublicCopyAllowed("本週完成一個小步驟"))
    }

    @Test
    fun dataRightsPolicyCoversExportDeletionAndOptOut() {
        val policy = PrivacyGovernanceContract.dataRightsPolicy()

        assertTrue(policy.studentFacingCopy.contains("匯出"))
        assertTrue(policy.studentFacingCopy.contains("刪除"))
        assertTrue(policy.studentFacingCopy.contains("停止使用"))
        assertEquals(listOf("request_export", "request_delete", "request_opt_out"), policy.supportedActions)
    }

    @Test
    fun apiKeyCommitGuardDetectsSecretLikeValues() {
        val guard = PrivacyGovernanceContract.apiKeyCommitGuard()

        assertTrue(guard.isForbiddenSecret("sk-" + "live-1234567890abcdef"))
        assertTrue(guard.isForbiddenSecret("OPENROUTER" + "_API" + "_KEY=" + "sk-or-" + "v1-example"))
        assertFalse(guard.isForbiddenSecret("OpenRouter key should be stored on the server proxy."))
        assertFalse(guard.productionKeyAllowedOnDevice)
    }

    @Test
    fun firebaseSecurityRuleRequirementsAreDocumented() {
        val requirements = PrivacyGovernanceContract.firebaseSecurityRequirements()

        assertTrue(requirements.any { it.contains("role claims") })
        assertTrue(requirements.any { it.contains("classId") })
        assertTrue(requirements.any { it.contains("deny other students") })
        assertTrue(requirements.any { it.contains("audit") })
    }

    @Test
    fun internalTestConsentPacketCoversStudentGuardianTeacherVolunteerAndSchool() {
        val packet = PrivacyGovernanceContract.internalTestConsentPacket()
        val audiences = packet.sections.map { it.audience }.toSet()

        assertEquals(setOf("學生", "家長/監護人", "老師", "志工", "學校/課程團隊"), audiences)
        assertTrue(packet.summary.contains("內測"))
        assertTrue(packet.summary.contains("可退出"))
        packet.sections.forEach { section ->
            assertTrue(section.mustTellUser.isNotBlank())
            assertTrue(section.requiredConsentItems.isNotEmpty())
            assertFalse(section.mustTellUser.contains("debug", ignoreCase = true))
            assertFalse(section.mustTellUser.contains("prototype", ignoreCase = true))
        }
    }

    @Test
    fun dataLifecycleRunbookCoversExportDeleteOptOutAndIncidentResponse() {
        val runbook = PrivacyGovernanceContract.dataLifecycleRunbook()
        val actionIds = runbook.map { it.actionId }.toSet()

        assertTrue(actionIds.contains("export-student-data"))
        assertTrue(actionIds.contains("delete-test-records"))
        assertTrue(actionIds.contains("opt-out"))
        assertTrue(actionIds.contains("incident-review"))
        runbook.forEach { action ->
            assertTrue(action.owner in setOf("老師", "課程團隊", "學校管理者"))
            assertTrue(action.studentFacingResult.isNotBlank())
            assertTrue(action.deadlineDays in 1..30)
            assertFalse(action.staffProcedure.contains("TODO", ignoreCase = true))
        }
    }

    @Test
    fun playDataSafetyDraftMapsSensitiveDataToPurposeSharingAndDeletion() {
        val draft = PrivacyGovernanceContract.playDataSafetyDraft()

        assertTrue(draft.entries.any { it.dataType == StudentDataType.LearningRecord && it.purpose.contains("學習") })
        assertTrue(draft.entries.any { it.dataType == StudentDataType.EmotionalSupport && it.sensitive })
        assertTrue(draft.entries.any { it.dataType == StudentDataType.AiSupportContext && it.sharedWith.contains("安全後端") })
        assertTrue(draft.deletionPath.contains("刪除"))
        assertTrue(draft.contactRoute.contains("老師"))
        draft.entries.forEach {
            assertFalse(it.sharedWith.contains("其他學生"))
            assertTrue(it.retentionSummary.isNotBlank())
        }
    }
}
