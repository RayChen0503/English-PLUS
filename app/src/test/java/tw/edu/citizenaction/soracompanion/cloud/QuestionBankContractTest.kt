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

    @Test
    fun practiceBlueprintRequiresDifficultyAndTypeCoverage() {
        val items = listOf(
            item("a1-choice", "A1", "選擇題", "Choose one."),
            item("a2-blank", "A2", "填空題", "Fill one."),
            item("b1-cloze", "B1", "克漏字", "Read one."),
            item("b1-read", "B1", "閱讀理解", "Read two."),
            item("b2-translate", "B2", "翻譯/句子重組", "Translate one.")
        )

        val blueprint = QuestionBankContract.practiceBlueprint(
            items = items,
            preferredTypes = setOf("選擇題", "填空題"),
            challengeWanted = true
        )

        assertEquals(5, blueprint.totalQuestions)
        assertEquals(listOf("A1", "A2", "B1", "B2"), blueprint.availableLevels)
        assertEquals(listOf("選擇題", "填空題", "克漏字", "閱讀理解", "翻譯/句子重組"), blueprint.availableTypes)
        assertEquals("挑戰模式會優先加入 B1/B2 題，但仍保留 A1/A2 當暖身。", blueprint.recommendation)
    }

    @Test
    fun sessionCandidatesAvoidRecentlySeenPrompts() {
        val items = listOf(
            item("q1", "A1", "選擇題", "same prompt"),
            item("q2", "A1", "選擇題", "same prompt"),
            item("q3", "A2", "填空題", "new prompt"),
            item("q4", "B1", "閱讀理解", "hard prompt")
        )

        val candidates = QuestionBankContract.sessionCandidates(
            items = items,
            preferredTypes = setOf("選擇題", "填空題", "閱讀理解"),
            recentlySeenPrompts = setOf("same prompt"),
            challengeWanted = false
        )

        assertEquals(listOf("new prompt", "hard prompt"), candidates.map { it.question.prompt })
    }

    @Test
    fun sessionCandidatesRecoverWhenRecentPromptsWouldEmptyTheSession() {
        val items = listOf(
            item("q1", "A1", "choice", "seen choice"),
            item("q2", "A2", "blank", "seen blank")
        )

        val candidates = QuestionBankContract.sessionCandidates(
            items = items,
            preferredTypes = setOf("choice", "blank"),
            recentlySeenPrompts = setOf("seen choice", "seen blank"),
            challengeWanted = false
        )

        assertEquals(listOf("seen choice", "seen blank"), candidates.map { it.question.prompt })
    }

    private fun item(id: String, level: String, type: String, prompt: String): QuestionBankItem {
        return QuestionBankItem(
            id = id,
            level = level,
            unit = "unit",
            skill = type,
            source = "unit-test",
            question = Question(
                prompt = prompt,
                options = listOf("A", "B"),
                answer = "A",
                explanation = "A is correct.",
                concept = type,
                type = type
            ),
            reviewState = "approved"
        )
    }
}
