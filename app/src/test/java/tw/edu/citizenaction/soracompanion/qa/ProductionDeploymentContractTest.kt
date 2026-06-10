package tw.edu.citizenaction.soracompanion.qa

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ProductionDeploymentContractTest {
    @Test
    fun deploymentDecisionMatrixNamesEveryExternalDecisionBeforePublicLaunch() {
        val decisions = ProductionDeploymentContract.deploymentDecisionMatrix()
        val ids = decisions.map { it.id }.toSet()

        assertTrue(ids.contains("auth-provider"))
        assertTrue(ids.contains("cloud-database"))
        assertTrue(ids.contains("ai-proxy"))
        assertTrue(ids.contains("security-rules"))
        assertTrue(ids.contains("question-bank-source"))
        assertTrue(ids.contains("release-signing"))

        decisions.forEach { decision ->
            assertTrue(decision.owner in setOf("user", "school", "team", "user-or-school"))
            assertTrue(decision.userDecision.isNotBlank())
            assertTrue(decision.implementationHandoff.isNotBlank())
            assertFalse(decision.userDecision.contains("TODO", ignoreCase = true))
            assertFalse(decision.userDecision.contains("API"))
        }
    }

    @Test
    fun backendHandoffGateBlocksProductionUntilHttpsAuthCloudAiProxyAndFirebaseConfigAreReady() {
        val blocked = ProductionDeploymentContract.backendHandoffGate(
            authEndpoint = "https://school.example.edu/auth/login",
            cloudEndpoint = "http://example.edu/sync",
            aiProxyEndpoint = "",
            hasGoogleServicesJson = false,
            hasRoleClaims = true,
            hasPrivacyPolicyUrl = true,
            hasServerHeldAiKey = false,
            mobileStoresProductionKey = false
        )

        assertFalse(blocked.readyForProductionBackend)
        assertTrue(blocked.blockers.contains("cloud endpoint must use HTTPS"))
        assertTrue(blocked.blockers.contains("AI proxy endpoint"))
        assertTrue(blocked.blockers.contains("google-services.json"))
        assertTrue(blocked.blockers.contains("server-held AI key"))
        assertTrue(blocked.nextAction.contains("先補齊"))

        val ready = ProductionDeploymentContract.backendHandoffGate(
            authEndpoint = "https://school.example.edu/auth/login",
            cloudEndpoint = "https://school.example.edu/sync",
            aiProxyEndpoint = "https://school.example.edu/ai/proxy",
            hasGoogleServicesJson = true,
            hasRoleClaims = true,
            hasPrivacyPolicyUrl = true,
            hasServerHeldAiKey = true,
            mobileStoresProductionKey = false
        )

        assertTrue(ready.readyForProductionBackend)
        assertEquals(emptyList<String>(), ready.blockers)
        assertTrue(ready.nextAction.contains("可以進入"))
    }

    @Test
    fun backendHandoffNeverAllowsProductionAiKeyOnMobile() {
        val gate = ProductionDeploymentContract.backendHandoffGate(
            authEndpoint = "https://school.example.edu/auth/login",
            cloudEndpoint = "https://school.example.edu/sync",
            aiProxyEndpoint = "https://school.example.edu/ai/proxy",
            hasGoogleServicesJson = true,
            hasRoleClaims = true,
            hasPrivacyPolicyUrl = true,
            hasServerHeldAiKey = true,
            mobileStoresProductionKey = true
        )

        assertFalse(gate.readyForProductionBackend)
        assertTrue(gate.blockers.contains("production AI key must not be stored on mobile"))
        assertTrue(gate.nextAction.contains("移到後端"))
    }

    @Test
    fun securityRulesOutlineCoversStudentTeacherVolunteerAndQuestionBankPermissions() {
        val rules = ProductionDeploymentContract.securityRulesOutline()

        assertTrue(rules.any { it.role == "學生" && it.allowedWrites.contains("own learning events") })
        assertTrue(rules.any { it.role == "學生" && !it.allowedReads.contains("other students") })
        assertTrue(rules.any { it.role == "老師" && it.allowedWrites.contains("teacher replies") })
        assertTrue(rules.any { it.role == "老師" && it.allowedWrites.contains("question bank") })
        assertTrue(rules.any { it.role == "志工" && it.allowedWrites.contains("handoff notes") })
        assertTrue(rules.any { it.role == "志工" && !it.allowedWrites.contains("question bank") })
        rules.forEach {
            assertTrue(it.serverCheck.isNotBlank())
            assertFalse(it.serverCheck.contains("trust UI", ignoreCase = true))
        }
    }

    @Test
    fun backendEndpointManifestCoversAuthSyncAiQuestionBankAndHealthCheck() {
        val manifest = ProductionDeploymentContract.backendEndpointManifest()
        val actions = manifest.map { it.action }.toSet()

        assertTrue(actions.contains("login"))
        assertTrue(actions.contains("pushSync"))
        assertTrue(actions.contains("fetchSync"))
        assertTrue(actions.contains("aiSupport"))
        assertTrue(actions.contains("questionBankImport"))
        assertTrue(actions.contains("healthCheck"))

        manifest.forEach { endpoint ->
            assertTrue(endpoint.method in setOf("GET", "POST"))
            assertTrue(endpoint.path.startsWith("/"))
            assertTrue(endpoint.responseFields.isNotEmpty())
            assertFalse(endpoint.path.contains("localhost", ignoreCase = true))
            assertFalse(endpoint.description.contains("TODO", ignoreCase = true))
            if (endpoint.authRequired) {
                assertTrue(endpoint.requiredHeaders.contains("Authorization"))
                assertTrue(endpoint.allowedRoles.isNotEmpty())
            }
        }
    }

    @Test
    fun backendPayloadExamplesUseCurrentSchemasAndNeverContainSecrets() {
        val examples = ProductionDeploymentContract.backendPayloadExamples()
        val byAction = examples.associateBy { it.action }

        assertEquals(ProductionDeploymentContract.PRODUCTION_DEPLOYMENT_SCHEMA_VERSION, byAction.getValue("deployment").schemaVersion)
        assertTrue(byAction.getValue("login").jsonBody.contains("classCode"))
        assertTrue(byAction.getValue("pushSync").jsonBody.contains("schemaVersion"))
        assertTrue(byAction.getValue("aiSupport").jsonBody.contains("taskType"))
        assertTrue(byAction.getValue("questionBankImport").jsonBody.contains("questionBankSchemaVersion"))

        examples.forEach { example ->
            assertFalse(example.jsonBody.contains("sk-"))
            assertFalse(example.jsonBody.contains("secret", ignoreCase = true))
            assertFalse(example.jsonBody.contains("password"))
            assertTrue(example.validationNote.isNotBlank())
        }
    }

    @Test
    fun deploymentRunbookOrdersLocalVerificationBeforeCredentialedBackendLaunch() {
        val steps = ProductionDeploymentContract.deploymentRunbook()

        assertEquals(1, steps.first().order)
        assertTrue(steps.first().title.contains("本機"))
        assertTrue(steps.any { it.title.contains("HTTPS") })
        assertTrue(steps.any { it.title.contains("角色") })
        assertTrue(steps.any { it.title.contains("AI") })
        assertTrue(steps.any { it.title.contains("內測") })
        assertTrue(steps.zipWithNext().all { (a, b) -> a.order < b.order })
        steps.forEach {
            assertTrue(it.acceptanceCheck.isNotBlank())
            assertFalse(it.acceptanceCheck.contains("TODO", ignoreCase = true))
        }
    }
}
