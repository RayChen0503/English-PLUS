package tw.edu.citizenaction.soracompanion.model

enum class Role { Student, Mentor }

enum class Screen { Home, CheckIn, Lesson, AiCoach, Breakpoints, Handoff, Map, Roster, Mentor, Report, Profile, Journey, Intervention, HelpRequest, StudentDetail, Contract, Reflection, ActionQueue, Account, StudentManager, AiLab, SyncCenter, QuestionBank, DesignSystem }

enum class Mood(
    val label: String,
    val description: String,
    val color: String,
    val defaultMinutes: Int,
    val confidenceDelta: Int,
    val planName: String
) {
    Good("狀態穩定", "可以做一題完整練習，也能多挑戰一點。", "#0F766E", 8, 3, "小挑戰任務"),
    Okay("普通，先暖身", "先做 5 分鐘短任務，完成一小步就好。", "#246BFD", 5, 1, "低壓短任務"),
    Low("有點卡住", "先做一個復原任務，不急著考自己。", "#B45309", 3, 0, "復原任務")
}

data class StudentProfile(
    val name: String,
    val age: Int,
    val location: String,
    val grade: String,
    val goal: String,
    val constraint: String,
    val mentor: String,
    val learningStyle: String,
    val supportNeed: String
)

data class LearningModule(
    val title: String,
    val subtitle: String,
    val progress: Int,
    val nextStep: String,
    val status: String
)

data class Question(
    val prompt: String,
    val options: List<String>,
    val answer: String,
    val explanation: String,
    val concept: String,
    val type: String = "選擇題",
    val repairHint: String = explanation
)

data class QuestionBankItem(
    val id: String,
    val level: String,
    val unit: String,
    val skill: String,
    val source: String,
    val question: Question,
    val updatedAt: Long = System.currentTimeMillis(),
    val reviewState: String = "draft",
    val importBatchId: String = "seed"
)

data class Breakpoint(
    val title: String,
    val severity: String,
    val evidence: String,
    val aiAction: String,
    val mentorAction: String
)

data class StudentRow(
    val name: String,
    val risk: String,
    val issue: String,
    val status: String
)

data class Metric(
    val label: String,
    val value: String,
    val color: String
)

data class ActionItem(
    val title: String,
    val subtitle: String,
    val action: () -> Unit
)

data class StudyTask(
    val title: String,
    val minutes: Int,
    val difficulty: String,
    val reason: String,
    val status: String
)

data class SupportMessage(
    val sender: String,
    val time: String,
    val content: String,
    val tone: String
)

data class CollaborationNote(
    val actor: String,
    val role: String,
    val target: String,
    val note: String,
    val status: String,
    val createdAt: Long = System.currentTimeMillis()
)

data class WeeklySignal(
    val label: String,
    val value: String,
    val note: String,
    val color: String
)

data class MistakeRecord(
    val concept: String,
    val wrongPattern: String,
    val repairStep: String,
    val status: String
)

data class OfflinePack(
    val title: String,
    val size: String,
    val duration: String,
    val content: String
)

data class MentorCheck(
    val label: String,
    val status: String,
    val note: String,
    val color: String
)

data class HandoffPriority(
    val title: String,
    val owner: String,
    val nextAction: String,
    val urgency: String
)

data class JourneyStep(
    val stage: String,
    val studentFeeling: String,
    val platformResponse: String,
    val handoffRule: String
)

data class InterventionStep(
    val trigger: String,
    val designAction: String,
    val studentCopy: String,
    val evidence: String
)

data class DesignPrinciple(
    val title: String,
    val detail: String,
    val productProof: String
)

data class HelpRequestOption(
    val reason: String,
    val studentText: String,
    val platformAction: String,
    val route: String
)

data class LearningContract(
    val title: String,
    val studentPromise: String,
    val platformPromise: String,
    val mentorPromise: String
)

data class ReflectionPrompt(
    val title: String,
    val studentChoice: String,
    val platformResponse: String,
    val confidenceDelta: Int
)

data class TeacherAction(
    val title: String,
    val owner: String,
    val status: String,
    val due: String,
    val evidence: String,
    val nextStep: String
)

data class SyncRecord(
    val title: String,
    val status: String,
    val detail: String
)

data class OfflineSyncItem(
    val title: String,
    val category: String,
    val detail: String,
    val status: String,
    val updatedAt: Long = System.currentTimeMillis()
)

data class LocalAccount(
    val displayName: String,
    val roleLabel: String,
    val classCode: String,
    val loginState: String
)

data class AiScenario(
    val title: String,
    val input: String,
    val diagnosis: String,
    val feedback: String,
    val handoffSummary: String
)

data class AppState(
    val mood: Mood,
    val minutes: Int,
    val confidence: Int,
    val completedTasks: Int,
    val currentQuestionIndex: Int,
    val actionDoneCount: Int = 0,
    val managedStudentCount: Int = 5,
    val offlinePendingCount: Int = 1,
    val selectedAccountName: String = "小安",
    val mentorReplyCount: Int = 0,
    val learningEventCount: Int = 0,
    val repairedMistakeCount: Int = 0,
    val customTaskCount: Int = 0
)
