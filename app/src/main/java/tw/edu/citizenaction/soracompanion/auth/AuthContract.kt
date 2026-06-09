package tw.edu.citizenaction.soracompanion.auth

import org.json.JSONObject

data class AuthClaims(
    val provider: String,
    val subject: String,
    val displayName: String,
    val classCode: String,
    val roles: Set<String>
)

data class AuthIdentitySession(
    val provider: String,
    val userId: String,
    val displayName: String,
    val classCode: String,
    val roleLabel: String,
    val isDemo: Boolean
)

data class AuthBoundaryStatus(
    val state: String,
    val message: String
)

object AuthContract {
    const val ROLE_STUDENT = "學生"
    const val ROLE_TEACHER = "老師"
    const val ROLE_VOLUNTEER = "志工"

    const val PROVIDER_DEMO = "demo"
    const val PROVIDER_FIREBASE = "firebase"
    const val PROVIDER_GOOGLE = "google"
    const val PROVIDER_SCHOOL = "school"

    fun normalizeRole(rawRole: String): String {
        val normalized = rawRole.trim().lowercase()
        return when {
            normalized.contains("teacher") || normalized.contains("老師") -> ROLE_TEACHER
            normalized.contains("volunteer") || normalized.contains("mentor") || normalized.contains("志工") -> ROLE_VOLUNTEER
            normalized.contains("student") || normalized.contains("學生") -> ROLE_STUDENT
            else -> ROLE_STUDENT
        }
    }

    fun isStudentRole(roleLabel: String): Boolean = normalizeRole(roleLabel) == ROLE_STUDENT

    fun isStaffRole(roleLabel: String): Boolean = !isStudentRole(roleLabel)

    fun sessionFromClaims(
        claims: AuthClaims,
        fallbackDemoRole: String
    ): AuthIdentitySession {
        val role = roleFromClaims(claims.roles, fallbackDemoRole)
        return AuthIdentitySession(
            provider = claims.provider.trim().lowercase().ifBlank { PROVIDER_SCHOOL },
            userId = normalizeUserId(claims.displayName.ifBlank { claims.subject }),
            displayName = claims.displayName.trim().ifBlank { claims.subject.trim() },
            classCode = claims.classCode.trim().uppercase().ifBlank { "CLASS-LOCAL" },
            roleLabel = role,
            isDemo = false
        )
    }

    fun demoSession(
        displayName: String,
        classCode: String,
        roleLabel: String
    ): AuthIdentitySession {
        return AuthIdentitySession(
            provider = PROVIDER_DEMO,
            userId = normalizeUserId(displayName),
            displayName = displayName.trim().ifBlank { "班級使用者" },
            classCode = classCode.trim().uppercase().ifBlank { "CLASS-LOCAL" },
            roleLabel = normalizeRole(roleLabel),
            isDemo = true
        )
    }

    fun authBoundaryStatus(
        provider: String,
        endpoint: String,
        hasRemoteCredential: Boolean
    ): AuthBoundaryStatus {
        val normalizedProvider = provider.trim().lowercase()
        return when {
            normalizedProvider == PROVIDER_DEMO -> AuthBoundaryStatus(
                state = "classroom",
                message = "可使用班級測試帳號完成今天的課堂流程。"
            )
            hasRemoteCredential && isValidEndpoint(endpoint) -> AuthBoundaryStatus(
                state = "ready",
                message = "學校帳號已可使用，角色會依帳號權限判斷。"
            )
            else -> AuthBoundaryStatus(
                state = "setup-required",
                message = "目前可先使用班級帳號；跨裝置使用需要學校登入服務。"
            )
        }
    }

    fun isValidEndpoint(endpoint: String): Boolean {
        val url = endpoint.trim()
        return url.startsWith("https://") ||
            url.startsWith("http://localhost") ||
            url.startsWith("http://127.0.0.1") ||
            url.startsWith("http://10.0.2.2")
    }

    fun validateLoginInput(username: String, password: String, classCode: String): List<String> {
        val problems = mutableListOf<String>()
        if (username.trim().isBlank()) problems.add("account is required")
        if (password.isBlank()) problems.add("password is required")
        if (classCode.trim().isBlank()) problems.add("class code is required")
        return problems
    }

    fun buildLoginPayload(
        username: String,
        password: String,
        classCode: String,
        provider: String = PROVIDER_SCHOOL
    ): JSONObject {
        val data = buildLoginPayloadData(username, password, classCode, provider)
        return JSONObject()
            .put("schemaVersion", data.getValue("schemaVersion"))
            .put("app", data.getValue("app"))
            .put("username", data.getValue("username"))
            .put("password", data.getValue("password"))
            .put("classCode", data.getValue("classCode"))
            .put("provider", data.getValue("provider"))
    }

    fun buildLoginPayloadData(
        username: String,
        password: String,
        classCode: String,
        provider: String = PROVIDER_SCHOOL
    ): Map<String, Any> {
        return mapOf(
            "schemaVersion" to 2,
            "app" to "English+",
            "username" to username.trim(),
            "password" to password,
            "classCode" to classCode.trim(),
            "provider" to provider
        )
    }

    fun providerDisplayName(provider: String): String {
        return when (provider.trim().lowercase()) {
            PROVIDER_FIREBASE -> "Firebase Auth"
            PROVIDER_GOOGLE -> "Google Sign-In"
            PROVIDER_SCHOOL -> "School SSO"
            PROVIDER_DEMO -> "班級測試帳號"
            else -> provider.ifBlank { "Remote Auth" }
        }
    }

    private fun roleFromClaims(roles: Set<String>, fallbackRole: String): String {
        val normalized = roles.map { it.trim().lowercase() }.toSet()
        return when {
            normalized.any { it.contains("teacher") || it.contains("老師") } -> ROLE_TEACHER
            normalized.any { it.contains("volunteer") || it.contains("mentor") || it.contains("志工") } -> ROLE_VOLUNTEER
            normalized.any { it.contains("student") || it.contains("學生") } -> ROLE_STUDENT
            else -> normalizeRole(fallbackRole)
        }
    }

    private fun normalizeUserId(value: String): String {
        val trimmed = value.trim()
        if (trimmed == "小安") return "xiao-an"
        return trimmed
            .lowercase()
            .replace(Regex("[^a-z0-9]+"), "-")
            .trim('-')
            .ifBlank { "class-user" }
    }
}
