package tw.edu.citizenaction.soracompanion.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import tw.edu.citizenaction.soracompanion.model.UserFlowContract

class PrototypeRepositoryTest {
    @Test
    fun questionBankItemsHaveValidQuestionPayloads() {
        val items = PrototypeRepository.questionBankItems

        assertTrue("question bank should contain enough full prototype items", items.size >= 1000)
        assertEquals("question bank ids should be unique", items.size, items.map { it.id }.distinct().size)

        items.forEach { item ->
            assertFalse("question prompt should not be blank for ${item.id}", item.question.prompt.isBlank())
            assertTrue("answer must be one of the options for ${item.id}", item.question.answer in item.question.options)
            assertFalse("concept should not be blank for ${item.id}", item.question.concept.isBlank())
            assertFalse("repair hint should not be blank for ${item.id}", item.question.repairHint.isBlank())
        }
    }

    @Test
    fun questionBankCoversCapStyleQuestionTypesAndDifficultyRange() {
        val items = PrototypeRepository.questionBankItems
        val types = items.map { it.question.type }.toSet()
        val levels = items.map { it.level }.toSet()

        assertTrue("should keep simple choice questions as the lower bound", types.contains(UserFlowContract.TYPE_CHOICE))
        assertTrue("should include fill-in questions", types.contains(UserFlowContract.TYPE_FILL_BLANK))
        assertTrue("should include cloze passage questions", types.contains(UserFlowContract.TYPE_CLOZE))
        assertTrue("should include reading comprehension questions", types.contains(UserFlowContract.TYPE_READING))
        assertTrue("should include translation or sentence reordering questions", types.contains(UserFlowContract.TYPE_TRANSLATION))
        assertTrue("should keep A1 entry-level items", levels.contains("A1"))
        assertTrue("should include A2 bridge items", levels.contains("A2"))
        assertTrue("should include B1 CAP challenge items", levels.contains("B1"))
        assertTrue("should include B2 stretch items", levels.contains("B2"))
        assertTrue(
            "CAP-style originals should be marked in the source",
            items.any { it.source.contains("CAP-style original") }
        )
    }

    @Test
    fun questionBankHasEnoughItemsPerQuestionTypeForPractice() {
        val counts = PrototypeRepository.questionBankItems.groupingBy { it.question.type }.eachCount()

        assertTrue("choice questions should have enough warm-up items", counts.getValue(UserFlowContract.TYPE_CHOICE) >= 180)
        assertTrue("fill-in questions should have enough grammar practice", counts.getValue(UserFlowContract.TYPE_FILL_BLANK) >= 180)
        assertTrue("cloze questions should have enough passage practice", counts.getValue(UserFlowContract.TYPE_CLOZE) >= 180)
        assertTrue("reading comprehension should have enough article/message practice", counts.getValue(UserFlowContract.TYPE_READING) >= 180)
        assertTrue("translation/reordering should have enough sentence practice", counts.getValue(UserFlowContract.TYPE_TRANSLATION) >= 180)
    }

    @Test
    fun productPrototypeKeepsBothStudentAndMentorTracks() {
        assertTrue("student task track should have several short tasks", PrototypeRepository.studyTasks.size >= 4)
        assertTrue("mentor roster should contain multiple students", PrototypeRepository.roster.size >= 5)
        assertTrue("handoff priorities should exist for human relay", PrototypeRepository.handoffPriorities.isNotEmpty())
        assertTrue("collaboration messages should exist", PrototypeRepository.supportMessages.isNotEmpty())
    }

    @Test
    fun designPrinciplesCoverTheCoreProposal() {
        val principles = PrototypeRepository.designPrinciples

        assertTrue("design principles should cover at least four product rules", principles.size >= 4)
        principles.forEach { principle ->
            assertFalse("principle title should not be blank", principle.title.isBlank())
            assertFalse("principle detail should not be blank", principle.detail.isBlank())
            assertFalse("principle product proof should not be blank", principle.productProof.isBlank())
        }
    }
}
