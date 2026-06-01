package tw.edu.citizenaction.soracompanion.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PrototypeRepositoryTest {
    @Test
    fun questionBankItemsHaveValidQuestionPayloads() {
        val items = PrototypeRepository.questionBankItems

        assertTrue("question bank should contain enough inner-pilot items", items.size >= 1000)
        assertEquals("question bank ids should be unique", items.size, items.map { it.id }.distinct().size)

        items.forEach { item ->
            assertFalse("question prompt should not be blank for ${item.id}", item.question.prompt.isBlank())
            assertTrue("answer must be one of the options for ${item.id}", item.question.answer in item.question.options)
            assertFalse("concept should not be blank for ${item.id}", item.question.concept.isBlank())
            assertFalse("repair hint should not be blank for ${item.id}", item.question.repairHint.isBlank())
        }
    }

    @Test
    fun largeQuestionBankProvidesSelectableDifficultyAndTypeCoverage() {
        val items = PrototypeRepository.questionBankItems
        val cleanTypes = items.map { it.questionType }.toSet()
        val bands = items.map { it.difficultyBand }.toSet()

        assertTrue("third round should expose an approximately 1000-item practice bank", items.size in 1000..1100)
        assertTrue("should include foundation questions", bands.contains("foundation"))
        assertTrue("should include CAP-standard questions", bands.contains("cap-standard"))
        assertTrue("should include challenge questions", bands.contains("challenge"))
        assertTrue("should include choice questions", cleanTypes.contains("choice"))
        assertTrue("should include fill blank questions", cleanTypes.contains("fill-blank"))
        assertTrue("should include cloze questions", cleanTypes.contains("cloze"))
        assertTrue("should include reading questions", cleanTypes.contains("reading"))
        assertTrue("should include translation or reordering questions", cleanTypes.contains("translation-reorder"))
        assertTrue("challenge score should support harder selectable items", items.any { it.challengeScore >= 5 })
    }

    @Test
    fun questionBankCoversCapStyleQuestionTypesAndDifficultyRange() {
        val items = PrototypeRepository.questionBankItems
        val types = items.map { it.question.type }.toSet()
        val levels = items.map { it.level }.toSet()

        assertTrue("should keep simple choice questions as the lower bound", types.contains("選擇題"))
        assertTrue("should include fill-in questions", types.contains("填空題"))
        assertTrue("should include cloze passage questions", types.contains("克漏字"))
        assertTrue("should include reading comprehension questions", types.contains("閱讀理解"))
        assertTrue("should include translation or sentence reordering questions", types.contains("翻譯/句子重組"))
        assertTrue("should keep A1 entry-level items", levels.contains("A1"))
        assertTrue("should include A2 bridge items", levels.contains("A2"))
        assertTrue("should include B1 CAP challenge items", levels.contains("B1"))
        assertTrue(
            "CAP-style originals should be marked in the source",
            items.any { it.source.contains("CAP-style original") }
        )
    }

    @Test
    fun questionBankHasEnoughItemsPerQuestionTypeForPractice() {
        val counts = PrototypeRepository.questionBankItems.groupingBy { it.question.type }.eachCount()

        assertTrue("choice questions should have enough warm-up items", counts.getValue("選擇題") >= 20)
        assertTrue("fill-in questions should have enough grammar practice", counts.getValue("填空題") >= 25)
        assertTrue("cloze questions should have enough passage practice", counts.getValue("克漏字") >= 25)
        assertTrue("reading comprehension should have enough article/message practice", counts.getValue("閱讀理解") >= 25)
        assertTrue("translation/reordering should have enough sentence practice", counts.getValue("翻譯/句子重組") >= 20)
    }

    @Test
    fun adaptiveRecommendationsRepairAfterWrongAnswer() {
        val current = PrototypeRepository.questionBankItems.first { it.questionType == "reading" && it.difficultyBand == "challenge" }
        val recommendations = PrototypeRepository.adaptivePracticeRecommendations(
            current = current,
            wasCorrect = false,
            confidence = 38,
            moodLabel = "Low",
            wrongAttempts = 2
        )

        assertEquals("wrong-answer repair should return three next steps", 3, recommendations.size)
        assertTrue("repair path should avoid repeating the same item", recommendations.none { it.id == current.id })
        assertTrue(
            "repair path should prefer lower-pressure items",
            recommendations.all { it.difficultyBand == "foundation" || "repair" in it.recommendationTags || it.emotionalFit == "low" }
        )
        assertTrue("repair path should not jump to the hardest challenge", recommendations.all { it.challengeScore <= 4 })
    }

    @Test
    fun adaptiveRecommendationsUpgradeAfterCorrectHighConfidenceAnswer() {
        val current = PrototypeRepository.questionBankItems.first { it.questionType == "choice" && it.difficultyBand == "cap-standard" }
        val recommendations = PrototypeRepository.adaptivePracticeRecommendations(
            current = current,
            wasCorrect = true,
            confidence = 78,
            moodLabel = "Good",
            wrongAttempts = 0
        )

        assertEquals("correct-answer upgrade should return three next steps", 3, recommendations.size)
        assertTrue("upgrade path should avoid repeating the same item", recommendations.none { it.id == current.id })
        assertTrue(
            "upgrade path should prefer CAP-standard or challenge questions",
            recommendations.all { it.difficultyBand in setOf("cap-standard", "challenge") }
        )
        assertTrue("upgrade path should include at least one harder challenge", recommendations.any { it.challengeScore >= current.challengeScore })
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
