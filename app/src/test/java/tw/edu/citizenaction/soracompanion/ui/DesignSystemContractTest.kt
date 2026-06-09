package tw.edu.citizenaction.soracompanion.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DesignSystemContractTest {
    @Test
    fun colorTokensMatchEnglishPlusBrandPalette() {
        val tokens = DesignSystemContract.colorTokens()

        assertEquals("#17324D", tokens["Ink"])
        assertEquals("#1C6E74", tokens["Primary"])
        assertEquals("#F08A3C", tokens["Accent"])
        assertEquals("#D7E3DF", tokens["Border"])
        assertTrue(tokens.values.all { it.matches(Regex("#[0-9A-Fa-f]{6}")) })
    }

    @Test
    fun componentSizesRespectTouchAndSpacingRules() {
        val rules = DesignSystemContract.componentRules()

        assertEquals(52, rules.primaryButtonMinHeightDp)
        assertEquals(48, rules.secondaryButtonMinHeightDp)
        assertEquals(20, rules.cardPaddingDp)
        assertEquals(8, rules.cardRadiusDp)
        assertTrue(DesignSystemContract.isEightPointSpacing(24))
        assertFalse(DesignSystemContract.isEightPointSpacing(22))
    }

    @Test
    fun screenWidthPolicyCoversSmallAndroidPhones() {
        val policy = DesignSystemContract.screenWidthPolicy()

        assertEquals(listOf(360, 412), policy.requiredCheckWidthsDp)
        assertTrue(policy.supportsWidth(360))
        assertTrue(policy.supportsWidth(412))
        assertFalse(policy.supportsWidth(320))
    }

    @Test
    fun densityPolicySeparatesStudentAndTeacherScreens() {
        val student = DesignSystemContract.screenDensityPolicy(DesignAudience.Student)
        val teacher = DesignSystemContract.screenDensityPolicy(DesignAudience.Teacher)

        assertEquals("one primary action", student.primaryActionRule)
        assertEquals("evidence, owner, next action", teacher.primaryActionRule)
        assertTrue(student.maxCardsPerScreen < teacher.maxCardsPerScreen)
    }

    @Test
    fun navigationPolicyPreventsDuplicateBottomBarsAndOvercrowdedTabs() {
        val policy = DesignSystemContract.navigationPolicy()

        assertEquals(1, policy.maxBottomBarsPerScreen)
        assertEquals(5, policy.maxDestinations)
        assertTrue(policy.isValidBottomBarCount(1))
        assertFalse(policy.isValidBottomBarCount(2))
        assertTrue(policy.isValidDestinationCount(5))
        assertFalse(policy.isValidDestinationCount(6))
    }

    @Test
    fun actionHierarchyAllowsOnlyOnePrimaryActionPerFocusedScreen() {
        val hierarchy = DesignSystemContract.actionHierarchyPolicy()

        assertEquals(1, hierarchy.maxPrimaryActionsPerScreen)
        assertTrue(hierarchy.isValid(primaryActions = 1, secondaryActions = 2))
        assertFalse(hierarchy.isValid(primaryActions = 2, secondaryActions = 1))
        assertFalse(hierarchy.isValid(primaryActions = 1, secondaryActions = 5))
    }

    @Test
    fun cardAndCopyPoliciesProtectSmallScreensFromOverflow() {
        val card = DesignSystemContract.cardLayoutPolicy()
        val copy = DesignSystemContract.copyFitPolicy()

        assertTrue(DesignSystemContract.isEightPointSpacing(card.verticalGapDp))
        assertTrue(DesignSystemContract.isEightPointSpacing(card.internalPaddingDp))
        assertEquals(8, card.radiusDp)
        assertTrue(copy.maxNavLabelChars <= 4)
        assertTrue(copy.fitsNavLabel("今日"))
        assertFalse(copy.fitsNavLabel("完整學習報告"))
    }

    @Test
    fun stateVisualPolicyDefinesConsistentSuccessLoadingEmptyAndErrorStates() {
        val policy = DesignSystemContract.stateVisualPolicy()

        assertEquals(setOf(UiState.Success, UiState.Loading, UiState.Empty, UiState.Error), policy.tokens.keys)
        assertEquals(4, policy.tokens.values.toSet().size)
        assertTrue(policy.messageFor(UiState.Success).contains("完成"))
        assertTrue(policy.messageFor(UiState.Empty).contains("還沒有"))
        assertTrue(policy.messageFor(UiState.Error).contains("再試"))
    }
}
