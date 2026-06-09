package tw.edu.citizenaction.soracompanion.model

data class TeacherHomeSummary(
    val priorityStudent: String,
    val highRiskCount: Int,
    val helpPending: Int,
    val pendingSyncCount: Int,
    val nextAction: String,
    val primaryScreens: List<Screen>
)

data class TeacherStudentDetail(
    val studentName: String,
    val missionProgress: String,
    val helpRequestCount: Int,
    val recentAnswers: List<String>,
    val primaryAction: String
)

object TeacherWorkspaceContract {
    fun homeSummary(
        roster: List<StudentRow>,
        notes: List<CollaborationNote>,
        pendingSyncCount: Int
    ): TeacherHomeSummary {
        val highRiskRows = roster.filter { it.risk.contains("高") }
        val pendingHelp = CollaborationFlowContract.unansweredRequests(notes)
        val priority = pendingHelp.firstOrNull()?.target
            ?: highRiskRows.firstOrNull()?.name
            ?: roster.firstOrNull()?.name
            ?: "尚無學生"
        val nextAction = when {
            pendingHelp.isNotEmpty() -> "先回覆 $priority 的求助，再安排下一步。"
            highRiskRows.isNotEmpty() -> "先查看 $priority 的學習細節與風險原因。"
            pendingSyncCount > 0 -> "先同步班級資料，確認最新紀錄。"
            else -> "查看週報與題庫，安排下一次任務。"
        }
        return TeacherHomeSummary(
            priorityStudent = priority,
            highRiskCount = highRiskRows.size,
            helpPending = pendingHelp.size,
            pendingSyncCount = pendingSyncCount,
            nextAction = nextAction,
            primaryScreens = listOf(Screen.StudentDetail, Screen.ActionQueue, Screen.Report, Screen.QuestionBank)
        )
    }

    fun studentDetail(
        row: StudentRow,
        notes: List<CollaborationNote>,
        recentAnswerTitles: List<String>,
        missionProgress: String
    ): TeacherStudentDetail {
        val helpCount = CollaborationFlowContract.unansweredRequests(notes, row.name).size
        return TeacherStudentDetail(
            studentName = row.name,
            missionProgress = missionProgress,
            helpRequestCount = helpCount,
            recentAnswers = recentAnswerTitles.take(4),
            primaryAction = if (helpCount > 0) "write_teacher_reply" else "assign_next_task"
        )
    }

    fun resourcesFor(role: Role): Set<Screen> {
        return if (UserFlowContract.isTeacherRole(role)) {
            setOf(Screen.Report, Screen.QuestionBank, Screen.StudentManager, Screen.StudentDetail, Screen.ActionQueue)
        } else {
            emptySet()
        }
    }
}
