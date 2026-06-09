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
}
