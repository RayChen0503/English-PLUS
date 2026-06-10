package tw.edu.citizenaction.soracompanion.model

data class CopyAuditResult(
    val checkedCount: Int,
    val offendingTerms: List<String>
) {
    val isClean: Boolean = offendingTerms.isEmpty()
}

object UserVisibleCopyContract {
    private val internalTerms = listOf(
        "API",
        "Key",
        "Proxy",
        "SQLite",
        "JSON",
        "POST",
        "HTTP",
        "debug",
        "本機",
        "備援",
        "端點",
        "正式登入",
        "正式端",
        "雲端後端",
        "同步佇列",
        "內測",
        "展示模式"
    )

    private val mojibakeFragments = listOf(
        "�",
        "嚗",
        "蝧",
        "撌",
        "憿",
        "隞",
        "雿",
        "銝",
        "摰",
        "敺",
        "蝺",
        "蜓",
        "頝",
        "",
        "",
        "",
        ""
    )

    fun audit(texts: List<String>): CopyAuditResult {
        val normalizedTexts = texts.filter { it.isNotBlank() }
        val terms = (internalTerms + mojibakeFragments)
            .filter { term ->
                normalizedTexts.any { text -> text.contains(term, ignoreCase = true) }
            }
            .distinct()
        return CopyAuditResult(
            checkedCount = normalizedTexts.size,
            offendingTerms = terms
        )
    }
}
