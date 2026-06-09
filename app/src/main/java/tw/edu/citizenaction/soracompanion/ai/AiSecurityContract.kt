package tw.edu.citizenaction.soracompanion.ai

enum class AiRoute {
    Proxy,
    DirectOpenAiDevelopment,
    LocalSimulation
}

data class AiSecurityDecision(
    val route: AiRoute,
    val canCallRemoteAi: Boolean,
    val usesMobileSecret: Boolean,
    val warning: String
)

object AiSecurityContract {
    const val AI_SECURITY_SCHEMA_VERSION = 2

    fun evaluate(
        proxyEndpoint: String,
        localApiKey: String,
        productionMode: Boolean
    ): AiSecurityDecision {
        val proxy = proxyEndpoint.trim()
        val key = localApiKey.trim()
        return when {
            proxy.startsWith("https://") -> AiSecurityDecision(
                route = AiRoute.Proxy,
                canCallRemoteAi = true,
                usesMobileSecret = false,
                warning = "Production-safe: Android calls a backend proxy and does not hold the OpenAI key."
            )
            proxy.startsWith("http://") -> AiSecurityDecision(
                route = AiRoute.LocalSimulation,
                canCallRemoteAi = false,
                usesMobileSecret = false,
                warning = "AI proxy must use HTTPS before remote AI can run."
            )
            key.startsWith("sk-") && !productionMode -> AiSecurityDecision(
                route = AiRoute.DirectOpenAiDevelopment,
                canCallRemoteAi = true,
                usesMobileSecret = true,
                warning = "Direct OpenAI key is development-only. Production must use the proxy."
            )
            else -> AiSecurityDecision(
                route = AiRoute.LocalSimulation,
                canCallRemoteAi = false,
                usesMobileSecret = false,
                warning = "Remote AI is disabled until a secure HTTPS proxy is configured."
            )
        }
    }

    fun proxyPayloadMetadata(classId: String, requesterId: String): Map<String, Any> {
        return mapOf(
            "aiSecuritySchemaVersion" to AI_SECURITY_SCHEMA_VERSION,
            "classId" to classId,
            "requesterId" to requesterId,
            "secretLocation" to "server-held OpenAI key",
            "clientSecretPolicy" to "Android must not send or store production OpenAI keys",
            "transport" to "https-only"
        )
    }
}
