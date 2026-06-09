package tw.edu.citizenaction.soracompanion.ui

enum class DesignAudience {
    Student,
    Teacher
}

data class ComponentRules(
    val primaryButtonMinHeightDp: Int,
    val secondaryButtonMinHeightDp: Int,
    val cardPaddingDp: Int,
    val cardRadiusDp: Int,
    val statusPillTextSp: Int
)

data class ScreenWidthPolicy(
    val requiredCheckWidthsDp: List<Int>,
    val minimumSupportedWidthDp: Int
) {
    fun supportsWidth(widthDp: Int): Boolean = widthDp >= minimumSupportedWidthDp
}

data class ScreenDensityPolicy(
    val audience: DesignAudience,
    val maxCardsPerScreen: Int,
    val primaryActionRule: String,
    val copyRule: String
)

data class NavigationPolicy(
    val maxBottomBarsPerScreen: Int,
    val maxDestinations: Int
) {
    fun isValidBottomBarCount(count: Int): Boolean = count == maxBottomBarsPerScreen

    fun isValidDestinationCount(count: Int): Boolean = count in 1..maxDestinations
}

data class ActionHierarchyPolicy(
    val maxPrimaryActionsPerScreen: Int,
    val maxSecondaryActionsPerScreen: Int
) {
    fun isValid(primaryActions: Int, secondaryActions: Int): Boolean {
        return primaryActions in 0..maxPrimaryActionsPerScreen &&
            secondaryActions in 0..maxSecondaryActionsPerScreen
    }
}

data class CardLayoutPolicy(
    val internalPaddingDp: Int,
    val verticalGapDp: Int,
    val radiusDp: Int,
    val maxBodyLineChars: Int
)

data class CopyFitPolicy(
    val maxNavLabelChars: Int,
    val maxStatusPillChars: Int,
    val maxButtonChars: Int
) {
    fun fitsNavLabel(label: String): Boolean = label.length <= maxNavLabelChars
}

enum class UiState {
    Success,
    Loading,
    Empty,
    Error
}

data class StateVisualPolicy(
    val tokens: Map<UiState, String>,
    val messages: Map<UiState, String>
) {
    fun messageFor(state: UiState): String = messages.getValue(state)
}

object DesignSystemContract {
    const val DESIGN_SYSTEM_VERSION = 12

    fun colorTokens(): Map<String, String> {
        return linkedMapOf(
            "Ink" to UiKit.ColorToken.Ink,
            "Muted" to UiKit.ColorToken.Muted,
            "Surface" to UiKit.ColorToken.Surface,
            "Card" to UiKit.ColorToken.Card,
            "Primary" to UiKit.ColorToken.Primary,
            "PrimarySoft" to UiKit.ColorToken.PrimarySoft,
            "Accent" to UiKit.ColorToken.Accent,
            "AccentSoft" to UiKit.ColorToken.AccentSoft,
            "Success" to UiKit.ColorToken.Success,
            "SuccessSoft" to UiKit.ColorToken.SuccessSoft,
            "Warning" to UiKit.ColorToken.Warning,
            "WarningSoft" to UiKit.ColorToken.WarningSoft,
            "Danger" to UiKit.ColorToken.Danger,
            "VioletSoft" to UiKit.ColorToken.VioletSoft,
            "Border" to UiKit.ColorToken.Border
        )
    }

    fun componentRules(): ComponentRules {
        return ComponentRules(
            primaryButtonMinHeightDp = 52,
            secondaryButtonMinHeightDp = 48,
            cardPaddingDp = 20,
            cardRadiusDp = 8,
            statusPillTextSp = 12
        )
    }

    fun screenWidthPolicy(): ScreenWidthPolicy {
        return ScreenWidthPolicy(
            requiredCheckWidthsDp = listOf(360, 412),
            minimumSupportedWidthDp = 360
        )
    }

    fun screenDensityPolicy(audience: DesignAudience): ScreenDensityPolicy {
        return when (audience) {
            DesignAudience.Student -> ScreenDensityPolicy(
                audience = audience,
                maxCardsPerScreen = 5,
                primaryActionRule = "one primary action",
                copyRule = "short, low-pressure, task-first"
            )
            DesignAudience.Teacher -> ScreenDensityPolicy(
                audience = audience,
                maxCardsPerScreen = 8,
                primaryActionRule = "evidence, owner, next action",
                copyRule = "scan-friendly evidence and follow-up status"
            )
        }
    }

    fun navigationPolicy(): NavigationPolicy {
        return NavigationPolicy(
            maxBottomBarsPerScreen = 1,
            maxDestinations = 5
        )
    }

    fun actionHierarchyPolicy(): ActionHierarchyPolicy {
        return ActionHierarchyPolicy(
            maxPrimaryActionsPerScreen = 1,
            maxSecondaryActionsPerScreen = 3
        )
    }

    fun cardLayoutPolicy(): CardLayoutPolicy {
        val rules = componentRules()
        return CardLayoutPolicy(
            internalPaddingDp = rules.cardPaddingDp,
            verticalGapDp = 12,
            radiusDp = rules.cardRadiusDp,
            maxBodyLineChars = 64
        )
    }

    fun copyFitPolicy(): CopyFitPolicy {
        return CopyFitPolicy(
            maxNavLabelChars = 4,
            maxStatusPillChars = 8,
            maxButtonChars = 16
        )
    }

    fun stateVisualPolicy(): StateVisualPolicy {
        return StateVisualPolicy(
            tokens = linkedMapOf(
                UiState.Success to UiKit.ColorToken.SuccessSoft,
                UiState.Loading to UiKit.ColorToken.PrimarySoft,
                UiState.Empty to UiKit.ColorToken.VioletSoft,
                UiState.Error to UiKit.ColorToken.WarningSoft
            ),
            messages = linkedMapOf(
                UiState.Success to "已完成，下一步可以繼續。",
                UiState.Loading to "正在整理資料，請稍候。",
                UiState.Empty to "還沒有資料，先完成一個小步驟。",
                UiState.Error to "暫時無法完成，請稍後再試。"
            )
        )
    }

    fun isEightPointSpacing(valueDp: Int): Boolean {
        return valueDp > 0 && (valueDp % 8 == 0 || valueDp % 4 == 0)
    }
}
