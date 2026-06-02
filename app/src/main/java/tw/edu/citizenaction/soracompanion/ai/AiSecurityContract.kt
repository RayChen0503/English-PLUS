package tw.edu.citizenaction.soracompanion.ai

enum class AiRoute {
    Proxy,
    DirectOpenRouterDevelopment,
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
        productionMode: Boolean,
        openRouterApiKey: String = ""
    ): AiSecurityDecision {
        val proxy = proxyEndpoint.trim()
        val key = localApiKey.trim()
        val openRouterKey = openRouterApiKey.trim()
        return when {
            proxy.startsWith("https://") -> AiSecurityDecision(
                route = AiRoute.Proxy,
                canCallRemoteAi = true,
                usesMobileSecret = false,
                warning = "Production-safe: Android calls a backend proxy and does not hold the AI provider key."
            )
            proxy.startsWith("http://") -> AiSecurityDecision(
                route = AiRoute.LocalSimulation,
                canCallRemoteAi = false,
                usesMobileSecret = false,
                warning = "AI proxy must use HTTPS before remote AI can run."
            )
            OpenRouterClient.isLikelyOpenRouterKey(openRouterKey) && !productionMode -> AiSecurityDecision(
                route = AiRoute.DirectOpenRouterDevelopment,
                canCallRemoteAi = true,
                usesMobileSecret = true,
                warning = "Direct OpenRouter key is development-only. Production should use a backend proxy."
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
                warning = "Remote AI is disabled until a secure HTTPS proxy or development OpenRouter key is configured."
            )
        }
    }

    fun proxyPayloadMetadata(classId: String, requesterId: String): Map<String, Any> {
        return mapOf(
            "aiSecuritySchemaVersion" to AI_SECURITY_SCHEMA_VERSION,
            "classId" to classId,
            "requesterId" to requesterId,
            "secretLocation" to "server-held AI provider key",
            "clientSecretPolicy" to "Android must not send or store production AI keys",
            "transport" to "https-only"
        )
    }
}