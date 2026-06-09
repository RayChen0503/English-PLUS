package tw.edu.citizenaction.soracompanion.qa

enum class ReportKind {
    Student,
    Class,
    Pilot
}

enum class RenderTarget {
    Pdf,
    Word,
    TeacherDashboard
}

data class ReportSpec(
    val kind: ReportKind,
    val title: String,
    val audience: String,
    val fileStem: String
)

data class ReportContext(
    val studentName: String,
    val classCode: String,
    val moodLabel: String,
    val missionProgress: String,
    val supportSummary: String,
    val handoffSummary: String,
    val syncSummary: String,
    val generatedAtLabel: String
)

data class ReportFileBoundary(
    val fileName: String,
    val mimeType: String,
    val content: String
)

data class ReportExportPackage(
    val kind: ReportKind,
    val files: List<ReportFileBoundary>,
    val renderTargets: List<RenderTarget>,
    val teacherDashboardSections: List<String>
)

object ReportExportContract {
    const val REPORT_EXPORT_SCHEMA_VERSION = 11

    fun availableReports(): List<ReportSpec> {
        return listOf(
            ReportSpec(
                kind = ReportKind.Student,
                title = "English+ 學生學習回饋",
                audience = "學生與家長",
                fileStem = "english_plus_student_report"
            ),
            ReportSpec(
                kind = ReportKind.Class,
                title = "English+ 班級支持週報",
                audience = "老師與教學團隊",
                fileStem = "english_plus_class_report"
            ),
            ReportSpec(
                kind = ReportKind.Pilot,
                title = "English+ 課程內測報告",
                audience = "課程團隊與評審",
                fileStem = "english_plus_pilot_report"
            )
        )
    }

    fun renderText(kind: ReportKind, context: ReportContext): String {
        val spec = availableReports().first { it.kind == kind }
        return when (kind) {
            ReportKind.Student -> studentReport(spec, context)
            ReportKind.Class -> classReport(spec, context)
            ReportKind.Pilot -> pilotReport(spec, context)
        }
    }

    fun exportPackage(kind: ReportKind, context: ReportContext): ReportExportPackage {
        val spec = availableReports().first { it.kind == kind }
        val text = renderText(kind, context)
        return ReportExportPackage(
            kind = kind,
            files = listOf(
                ReportFileBoundary(
                    fileName = "${spec.fileStem}.txt",
                    mimeType = "text/plain; charset=utf-8",
                    content = text
                ),
                ReportFileBoundary(
                    fileName = "${spec.fileStem}.html",
                    mimeType = "text/html; charset=utf-8",
                    content = renderHtml(spec.title, context, text)
                )
            ),
            renderTargets = listOf(RenderTarget.Pdf, RenderTarget.Word, RenderTarget.TeacherDashboard),
            teacherDashboardSections = listOf("learning", "support", "handoff", "nextActions")
        )
    }

    fun renderHtml(title: String, context: ReportContext, bodyText: String): String {
        val escaped = bodyText.escapeHtml()
        return """
            <!doctype html>
            <html lang="zh-Hant">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>$title</title>
              <style>
                body { font-family: sans-serif; margin: 32px; color: #17324D; line-height: 1.7; }
                header { border-bottom: 3px solid #1C6E74; margin-bottom: 24px; padding-bottom: 16px; }
                h1 { margin: 0 0 8px; font-size: 28px; }
                .meta { color: #5F7287; font-size: 14px; }
                pre { white-space: pre-wrap; background: #F4F7F5; border: 1px solid #D7E3DF; border-radius: 8px; padding: 20px; }
                .note { margin-top: 18px; color: #5F7287; font-size: 13px; }
              </style>
            </head>
            <body>
              <header>
                <h1>$title</h1>
                <div class="meta">學生：${context.studentName.escapeHtml()}｜班級：${context.classCode.escapeHtml()}｜產生時間：${context.generatedAtLabel.escapeHtml()}</div>
              </header>
              <pre>$escaped</pre>
              <div class="note">此檔案已保留列印、PDF、Word 與老師後台報表需要的段落邊界。</div>
            </body>
            </html>
        """.trimIndent()
    }

    private fun studentReport(spec: ReportSpec, context: ReportContext): String {
        return """
            ${spec.title}
            對象：${spec.audience}
            產生時間：${context.generatedAtLabel}

            一、今天的學習狀態
            ${context.studentName} 目前心情是「${context.moodLabel}」，今日任務進度為 ${context.missionProgress}。

            二、可以肯定的進步
            ${context.supportSummary}

            三、下一個小步驟
            先完成一個短練習，再依照提示修復卡住的題型。重點不是和別人比較，而是把下一題做得更清楚。
        """.trimIndent()
    }

    private fun classReport(spec: ReportSpec, context: ReportContext): String {
        return """
            ${spec.title}
            對象：${spec.audience}
            班級：${context.classCode}
            產生時間：${context.generatedAtLabel}

            一、學習證據
            學生：${context.studentName}
            心情狀態：${context.moodLabel}
            今日任務進度：${context.missionProgress}

            二、支持與接力
            ${context.supportSummary}
            ${context.handoffSummary}

            三、資料保存
            ${context.syncSummary}

            四、老師下一步
            先回覆尚未處理的求助，再安排同一概念的小量練習；避免公開排名或加重壓力。
        """.trimIndent()
    }

    private fun pilotReport(spec: ReportSpec, context: ReportContext): String {
        return """
            ${spec.title}
            對象：${spec.audience}
            產生時間：${context.generatedAtLabel}

            一、產品定位
            English+ 以低壓短任務、錯題修復、老師與志工接力，協助偏鄉學生在英文卡關時繼續前進。

            二、內測觀察重點
            學生是否能看懂今日任務、是否願意求助、老師是否能快速判斷下一步、志工是否能依接力摘要陪學生完成一題。

            三、目前資料摘要
            學生：${context.studentName}
            班級：${context.classCode}
            任務進度：${context.missionProgress}
            支持摘要：${context.supportSummary}
            接力摘要：${context.handoffSummary}
            保存狀態：${context.syncSummary}
        """.trimIndent()
    }

    private fun String.escapeHtml(): String {
        return replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
    }
}
