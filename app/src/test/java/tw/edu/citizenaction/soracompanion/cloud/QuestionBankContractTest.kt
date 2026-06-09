package tw.edu.citizenaction.soracompanion.cloud

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import tw.edu.citizenaction.soracompanion.auth.AuthContract
import tw.edu.citizenaction.soracompanion.model.Question
import tw.edu.citizenaction.soracompanion.model.QuestionBankItem

class QuestionBankContractTest {
    private val sampleItem = QuestionBankItem(
        id = " B1 U1 001 ",
        level = "a1",
        unit = "be verbs",
        skill = "grammar",
        source = "teacher import",
        question = Question(
            prompt = "He ___ a student.",
            options = listOf("am", "is", "are"),
            answer = "is",
            explanation = "He uses is.",
            concept = "be verb"
        )
    )

    @Test
    fun importIdIsStableAndClassScoped() {
        val scope = CloudDataContract.buildScope(" class 8a ", "Teacher Lin", AuthContract.ROLE_TEACHER)

        val importId = QuestionBankContract.importId(scope, sampleItem)

        assertEquals("CLASS-8A:b1-u1-001", importId)
    }

    @Test
    fun reviewStateMovesFromDraftToApprovedWhenTeacherPublishes() {
        val teacher = CloudDataContract.buildScope("CLASS-8A", "Teacher Lin", AuthContract.ROLE_TEACHER)
        val student = CloudDataContract.buildScope("CLASS-8A", "Ray Chen", AuthContract.ROLE_STUDENT)

        assertEquals(QuestionReviewState.Draft, QuestionBankContract.initialReviewState(sampleItem))
        assertEquals(QuestionReviewState.Approved, QuestionBankContract.publishState(teacher, sampleItem))
        assertEquals(QuestionReviewState.Draft, QuestionBankContract.publishState(student, sampleItem))
        assertTrue(QuestionBankContract.canPublishQuestionBank(teacher))
        assertFalse(QuestionBankContract.canPublishQuestionBank(student))
    }

    @Test
    fun questionBankMetadataDeclaresImportAndReviewRules() {
        val scope = CloudDataContract.buildScope("CLASS-8A", "Teacher Lin", AuthContract.ROLE_TEACHER)
        val metadata = QuestionBankContract.buildQuestionBankMetadata(scope, listOf(sampleItem))

        assertEquals(5, metadata["questionBankSchemaVersion"])
        assertEquals("classes/CLASS-8A/questionBank", metadata["collectionPath"])
        assertEquals("teacher-lin", metadata["publisherId"])
        assertEquals(AuthContract.ROLE_TEACHER, metadata["publisherRole"])
        assertEquals("teacher-only publish; student read-only", metadata["permissionRule"])
        assertEquals("importId keeps latest updatedAt", metadata["conflictRule"])
        assertEquals(mapOf("a1" to 1), metadata["levelCounts"])
        assertEquals(mapOf("grammar" to 1), metadata["skillCounts"])
    }
}
