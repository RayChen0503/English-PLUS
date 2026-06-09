package tw.edu.citizenaction.soracompanion.ai

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AiSecurityContractTest {
    @Test
    fun productionModeRequiresHttpsProxy() {
        val secureProxy = AiSecurityContract.evaluate(
            proxyEndpoint = "https://school.example.edu/english-plus/ai",
            localApiKey = "",
            productionMode = true
        )
        val localKeyOnly = AiSecurityContract.evaluate(
            proxyEndpoint = "",
            localApiKey = "sk-test",
            productionMode = true
        )

        assertEquals(AiRoute.Proxy, secureProxy.route)
        assertTrue(secureProxy.canCallRemoteAi)
        assertEquals(AiRoute.LocalSimulation, localKeyOnly.route)
        assertFalse(localKeyOnly.canCallRemoteAi)
        assertTrue(localKeyOnly.warning.contains("proxy"))
    }

    @Test
    fun developmentModeStillPrefersProxyBeforeLocalKeyFallback() {
        val decision = AiSecurityContract.evaluate(
            proxyEndpoint = "https://school.example.edu/english-plus/ai",
            localApiKey = "sk-dev",
            productionMode = false
        )

        assertEquals(AiRoute.Proxy, decision.route)
        assertTrue(decision.canCallRemoteAi)
        assertFalse(decision.usesMobileSecret)
    }

    @Test
    fun localKeyFallbackIsMarkedAsMobileSecretRisk() {
        val decision = AiSecurityContract.evaluate(
            proxyEndpoint = "",
            localApiKey = "sk-dev",
            productionMode = false
        )

        assertEquals(AiRoute.DirectOpenAiDevelopment, decision.route)
        assertTrue(decision.canCallRemoteAi)
        assertTrue(decision.usesMobileSecret)
        assertTrue(decision.warning.contains("development"))
    }

    @Test
    fun proxyPayloadNeverContainsSecrets() {
        val payload = AiSecurityContract.proxyPayloadMetadata("CLASS-8A", "ray-chen")

        assertEquals(2, payload["aiSecuritySchemaVersion"])
        assertEquals("CLASS-8A", payload["classId"])
        assertEquals("ray-chen", payload["requesterId"])
        assertEquals("server-held OpenAI key", payload["secretLocation"])
        assertFalse(payload.keys.any { it.contains("key", ignoreCase = true) && it != "secretLocation" })
    }
}
