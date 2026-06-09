package tw.edu.citizenaction.soracompanion.qa

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PilotMaterialsRendererTest {
    @Test
    fun rendersTeacherBriefAsMarkdown() {
        val markdown = PilotMaterialsRenderer.renderTeacherBrief(PilotMaterialsContract.teacherBrief())

        assertTrue(markdown.startsWith("# "))
        assertTrue(markdown.contains("English+"))
        assertTrue(markdown.contains("## Talking Points"))
        assertTrue(markdown.contains("- "))
        assertTrue(markdown.contains("## Demo Reminder"))
        assertTrue(markdown.contains("內建提示"))
    }

    @Test
    fun rendersConsentNoticeWithAllSectionsAndNoPublicRanking() {
        val markdown = PilotMaterialsRenderer.renderConsentNotice(PilotMaterialsContract.consentNotice())

        assertTrue(markdown.startsWith("# "))
        assertTrue(markdown.contains("English+"))
        assertTrue(markdown.contains("## "))
        assertTrue(markdown.contains("no public ranking"))
        assertFalse(markdown.contains("public ranking: allowed"))
    }

    @Test
    fun rendersFeedbackFormWithAudienceLabels() {
        val markdown = PilotMaterialsRenderer.renderFeedbackForm(PilotMaterialsContract.feedbackForm())

        assertTrue(markdown.startsWith("# "))
        assertTrue(markdown.contains("English+"))
        assertTrue(markdown.contains("[student]"))
        assertTrue(markdown.contains("[teacher]"))
        assertTrue(markdown.contains("[volunteer]"))
        assertTrue(markdown.contains("Response type"))
    }

    @Test
    fun rendersCompletePilotMaterialPack() {
        val pack = PilotMaterialsRenderer.renderMaterialPack()

        assertTrue(pack.contains("## 1. Teacher Brief"))
        assertTrue(pack.contains("## 2. Consent Notice"))
        assertTrue(pack.contains("## 3. Feedback Form"))
        assertTrue(pack.contains("## 4. Observation Sheet"))
        assertTrue(pack.contains("student returned after support"))
    }
}
