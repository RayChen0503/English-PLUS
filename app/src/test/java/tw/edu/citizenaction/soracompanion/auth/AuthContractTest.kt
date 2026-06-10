package tw.edu.citizenaction.soracompanion.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AuthContractTest {
    @Test
    fun normalizesSupportedUserRoles() {
        assertEquals(AuthContract.ROLE_STUDENT, AuthContract.normalizeRole("student"))
        assertEquals(AuthContract.ROLE_TEACHER, AuthContract.normalizeRole("teacher"))
        assertEquals(AuthContract.ROLE_VOLUNTEER, AuthContract.normalizeRole("volunteer"))
        assertEquals(AuthContract.ROLE_VOLUNTEER, AuthContract.normalizeRole("mentor"))
        assertEquals("學生", AuthContract.ROLE_STUDENT)
        assertEquals("老師", AuthContract.ROLE_TEACHER)
        assertEquals("志工", AuthContract.ROLE_VOLUNTEER)
        assertEquals(AuthContract.ROLE_STUDENT, AuthContract.normalizeRole(""))
    }

    @Test
    fun validatesProductionAndLocalAuthEndpoints() {
        assertTrue(AuthContract.isValidEndpoint("https://example.com/auth/login"))
        assertTrue(AuthContract.isValidEndpoint("http://10.0.2.2:5001/auth/login"))
        assertTrue(AuthContract.isValidEndpoint("http://localhost:5001/auth/login"))
        assertFalse(AuthContract.isValidEndpoint("http://example.com/auth/login"))
        assertFalse(AuthContract.isValidEndpoint("not-a-url"))
    }

    @Test
    fun reportsMissingLoginFieldsBeforeNetworkRequest() {
        val problems = AuthContract.validateLoginInput("", "", "")

        assertEquals(listOf("請輸入帳號", "請輸入密碼", "請輸入班級代碼"), problems)
        assertFalse(problems.joinToString().contains("account", ignoreCase = true))
        assertFalse(problems.joinToString().contains("password", ignoreCase = true))
        assertFalse(problems.joinToString().contains("class", ignoreCase = true))
    }

    @Test
    fun buildsStableLoginPayloadForBackendAdapters() {
        val payload = AuthContract.buildLoginPayloadData(
            username = "student@example.com",
            password = "secret",
            classCode = "CLASS-8A",
            provider = AuthContract.PROVIDER_FIREBASE
        )

        assertEquals("student@example.com", payload["username"])
        assertEquals("secret", payload["password"])
        assertEquals("CLASS-8A", payload["classCode"])
        assertEquals("English+", payload["app"])
        assertEquals(AuthContract.PROVIDER_FIREBASE, payload["provider"])
        assertEquals(2, payload["schemaVersion"])
    }

    @Test
    fun remoteClaimsAssignRoleWithoutTrustingUiText() {
        val claims = AuthClaims(
            provider = AuthContract.PROVIDER_GOOGLE,
            subject = "google-user-123",
            displayName = "Teacher Lin",
            classCode = "YILAN-8A",
            roles = setOf("student", "teacher")
        )

        val session = AuthContract.sessionFromClaims(
            claims = claims,
            fallbackDemoRole = AuthContract.ROLE_STUDENT
        )

        assertEquals(AuthContract.ROLE_TEACHER, session.roleLabel)
        assertEquals("teacher-lin", session.userId)
        assertEquals("YILAN-8A", session.classCode)
        assertEquals(AuthContract.PROVIDER_GOOGLE, session.provider)
        assertFalse(session.isDemo)
    }

    @Test
    fun demoSessionRemainsAvailableForClassroomTesting() {
        val session = AuthContract.demoSession(
            displayName = "小安",
            classCode = "YILAN-CHENGZHI-8A",
            roleLabel = AuthContract.ROLE_STUDENT
        )

        assertEquals(AuthContract.PROVIDER_DEMO, session.provider)
        assertEquals(AuthContract.ROLE_STUDENT, session.roleLabel)
        assertEquals("xiao-an", session.userId)
        assertTrue(session.isDemo)
    }

    @Test
    fun authBoundaryStatusStaysUserFacing() {
        val status = AuthContract.authBoundaryStatus(
            provider = AuthContract.PROVIDER_FIREBASE,
            endpoint = "https://school.example.com/auth",
            hasRemoteCredential = true
        )

        assertEquals("ready", status.state)
        assertTrue(status.message.contains("學校帳號"))
        assertFalse(status.message.contains("token", ignoreCase = true))
        assertFalse(status.message.contains("implementation", ignoreCase = true))
        assertFalse(status.message.contains("demo", ignoreCase = true))
        assertFalse(status.message.contains("API"))
    }

    @Test
    fun providerNamesStayUserFacingInsteadOfImplementationFacing() {
        val names = listOf(
            AuthContract.providerDisplayName(AuthContract.PROVIDER_FIREBASE),
            AuthContract.providerDisplayName(AuthContract.PROVIDER_GOOGLE),
            AuthContract.providerDisplayName(AuthContract.PROVIDER_SCHOOL),
            AuthContract.providerDisplayName(AuthContract.PROVIDER_DEMO),
            AuthContract.providerDisplayName("")
        )

        assertEquals(listOf("學校帳號", "Google 帳號", "學校帳號", "班級測試帳號", "學校帳號"), names)
        val joined = names.joinToString(" ")
        assertFalse(joined.contains("Firebase", ignoreCase = true))
        assertFalse(joined.contains("SSO", ignoreCase = true))
        assertFalse(joined.contains("Remote", ignoreCase = true))
    }
}
