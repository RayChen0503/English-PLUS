package tw.edu.citizenaction.soracompanion.qa

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PilotMaterialsContractTest {
    @Test
    fun teacherBriefContainsCorePilotMessage() {
        val brief = PilotMaterialsContract.teacherBrief()

        assertEquals(12, PilotMaterialsContract.MATERIALS_SCHEMA_VERSION)
        assertTrue(brief.title.contains("English+"))
        assertTrue(brief.title.contains("老師"))
        assertTrue(brief.talkingPoints.any { it.contains("情緒") && it.contains("英文") })
        assertTrue(brief.talkingPoints.any { it.contains("老師") && it.contains("志工") })
        assertTrue(brief.talkingPoints.any { it.contains("資料") && it.contains("排名").not() })
        assertFalse(brief.talkingPoints.any { hasPrivateUseCharacter(it) || it.contains('\uFFFD') })
    }

    @Test
    fun consentNoticeExplainsDataUseAndOptOut() {
        val notice = PilotMaterialsContract.consentNotice()

        assertTrue(notice.sections.containsKey("資料會怎麼使用"))
        assertTrue(notice.sections.containsKey("學生可以選擇什麼"))
        assertTrue(notice.sections.containsKey("退出與刪除"))
        assertFalse(notice.allowPublicRanking)
        assertTrue(notice.sections.getValue("資料會怎麼使用").contains("學生"))
    }

    @Test
    fun feedbackFormAsksStudentTeacherAndVolunteerUsefulnessQuestions() {
        val form = PilotMaterialsContract.feedbackForm()
        val audienceSet = form.questions.map { it.audience }.toSet()

        assertTrue(audienceSet.contains("student"))
        assertTrue(audienceSet.contains("teacher"))
        assertTrue(audienceSet.contains("volunteer"))
        assertTrue(form.questions.any { it.question.contains("下一步") || it.question.contains("有幫助") })
        assertFalse(form.questions.any { hasPrivateUseCharacter(it.question) || it.question.contains('\uFFFD') })
    }

    @Test
    fun observationSheetTracksFlowEvidenceWithoutGrades() {
        val sheet = PilotMaterialsContract.observationSheet()

        assertTrue(sheet.fields.contains("student returned after support"))
        assertTrue(sheet.fields.contains("teacher next action identified"))
        assertTrue(sheet.fields.contains("handoff summary understandable"))
        assertFalse(sheet.fields.contains("student rank"))
    }

    private fun hasPrivateUseCharacter(text: String): Boolean {
        return text.any { it.code in 0xE000..0xF8FF }
    }
}
