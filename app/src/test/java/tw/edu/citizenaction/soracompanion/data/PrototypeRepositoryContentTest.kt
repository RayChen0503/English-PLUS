package tw.edu.citizenaction.soracompanion.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import tw.edu.citizenaction.soracompanion.model.UserFlowContract
import tw.edu.citizenaction.soracompanion.model.UserVisibleCopyContract

class PrototypeRepositoryContentTest {
    @Test
    fun questionBankHasEnoughCleanVariedPracticeItems() {
        val questions = PrototypeRepository.questions
        val bankItems = PrototypeRepository.questionBankItems

        assertTrue("question bank should be large enough for non-repetitive practice", questions.size >= 1000)
        assertEquals(questions.size, questions.distinctBy { it.prompt }.size)
        assertEquals(UserFlowContract.questionTypes.toSet(), questions.map { it.type }.toSet())
        assertTrue(bankItems.map { it.level }.toSet().containsAll(listOf("A1", "A2", "B1", "B2")))
        assertTrue(bankItems.all { it.unit.isNotBlank() && it.skill.isNotBlank() && it.source.isNotBlank() })
    }

    @Test
    fun coreSeedContentDoesNotExposeMojibakeOrImplementationCopy() {
        val visibleTexts = buildList {
            add(PrototypeRepository.student.name)
            add(PrototypeRepository.student.location)
            add(PrototypeRepository.student.goal)
            addAll(PrototypeRepository.modules.flatMap { listOf(it.title, it.subtitle, it.nextStep, it.status) })
            addAll(PrototypeRepository.questions.take(80).flatMap {
                listOf(it.prompt, it.answer, it.explanation, it.concept, it.type, it.repairHint)
            })
            addAll(PrototypeRepository.helpRequestOptions.flatMap {
                listOf(it.reason, it.studentText, it.platformAction, it.route)
            })
        }

        val audit = UserVisibleCopyContract.audit(visibleTexts)

        assertTrue(audit.offendingTerms.joinToString(), audit.isClean)
        assertFalse(visibleTexts.any { it.contains("�") || it.contains("嚗") || it.contains("蝧") || it.contains("撌") })
    }
}
