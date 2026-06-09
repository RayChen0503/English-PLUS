package tw.edu.citizenaction.soracompanion.qa

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReportExportContractTest {
    @Test
    fun separatesStudentClassAndPilotReports() {
        val reports = ReportExportContract.availableReports()

        assertEquals(
            listOf(ReportKind.Student, ReportKind.Class, ReportKind.Pilot),
            reports.map { it.kind }
        )
        assertEquals(3, reports.map { it.fileStem }.distinct().size)
        assertTrue(reports.first { it.kind == ReportKind.Student }.audience.contains("學生"))
        assertTrue(reports.first { it.kind == ReportKind.Class }.audience.contains("老師"))
        assertTrue(reports.first { it.kind == ReportKind.Pilot }.audience.contains("課程"))
    }

    @Test
    fun renderedReportsArePolishedAndDoNotExposeInternalPrototypeLabels() {
        val context = ReportContext(
            studentName = "小安",
            classCode = "YILAN-CHENGZHI-8A",
            moodLabel = "穩定",
            missionProgress = "3/4",
            supportSummary = "學生已主動求助，老師已回覆下一步。",
            handoffSummary = "志工已陪學生看懂關鍵句。",
            syncSummary = "最新資料已保存。",
            generatedAtLabel = "2026-06-09"
        )

        ReportExportContract.availableReports().forEach { spec ->
            val text = ReportExportContract.renderText(spec.kind, context)

            assertTrue(text.startsWith("English+"))
            assertTrue(text.contains(context.studentName))
            assertFalse(text.contains("prototype", ignoreCase = true))
            assertFalse(text.contains("debug", ignoreCase = true))
            assertFalse(text.contains("本機備援模式"))
            assertFalse(text.contains("正式版可改"))
        }
    }

    @Test
    fun exportPackageDefinesPdfAndWordReadyBoundaries() {
        val context = ReportContext(
            studentName = "小安",
            classCode = "YILAN-CHENGZHI-8A",
            moodLabel = "穩定",
            missionProgress = "3/4",
            supportSummary = "學生已主動求助，老師已回覆下一步。",
            handoffSummary = "志工已陪學生看懂關鍵句。",
            syncSummary = "最新資料已保存。",
            generatedAtLabel = "2026-06-09"
        )

        val pack = ReportExportContract.exportPackage(ReportKind.Class, context)

        assertEquals(ReportKind.Class, pack.kind)
        assertTrue(pack.files.any { it.fileName.endsWith(".txt") && it.mimeType == "text/plain; charset=utf-8" })
        assertTrue(pack.files.any { it.fileName.endsWith(".html") && it.mimeType == "text/html; charset=utf-8" })
        assertTrue(pack.renderTargets.contains(RenderTarget.Pdf))
        assertTrue(pack.renderTargets.contains(RenderTarget.Word))
        assertTrue(pack.teacherDashboardSections.containsAll(listOf("learning", "support", "handoff", "nextActions")))
    }
}
