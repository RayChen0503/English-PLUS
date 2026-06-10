package tw.edu.citizenaction.soracompanion.qa

data class ProductReadinessSnapshot(
    val automatedChecksPassed: Boolean,
    val debugApkBuilt: Boolean,
    val githubCleanAfterPush: Boolean,
    val manualSmokeTestPassed: Boolean,
    val physicalDeviceTested: Boolean,
    val teacherBriefReady: Boolean,
    val classroomConsentReady: Boolean,
    val demoEvidenceAccepted: Boolean,
    val signedRelease: Boolean,
    val privacyPolicyUrlReady: Boolean,
    val backendDeployed: Boolean,
    val productionBackendGatePassed: Boolean,
    val questionBankLicenseReady: Boolean,
    val playDataSafetyReviewed: Boolean
)

data class ProductReadinessReport(
    val readyForClassroomDemo: Boolean,
    val readyForInternalPilot: Boolean,
    val readyForPublicLaunch: Boolean,
    val blockersForClassroomDemo: List<String>,
    val blockersForInternalPilot: List<String>,
    val blockersForPublicLaunch: List<String>,
    val statusLabel: String,
    val honestSummary: String,
    val nextAction: String
)

data class ReadinessChecklistItem(
    val id: String,
    val sourceContract: String,
    val acceptanceEvidence: String,
    val requiredFor: String
)

object ProductReadinessContract {
    const val PRODUCT_READINESS_SCHEMA_VERSION = 1

    fun defaultLocalPrototypeSnapshot(): ProductReadinessSnapshot {
        return ProductReadinessSnapshot(
            automatedChecksPassed = true,
            debugApkBuilt = true,
            githubCleanAfterPush = true,
            manualSmokeTestPassed = false,
            physicalDeviceTested = false,
            teacherBriefReady = true,
            classroomConsentReady = false,
            demoEvidenceAccepted = false,
            signedRelease = false,
            privacyPolicyUrlReady = false,
            backendDeployed = false,
            productionBackendGatePassed = false,
            questionBankLicenseReady = false,
            playDataSafetyReviewed = false
        )
    }

    fun evaluate(snapshot: ProductReadinessSnapshot): ProductReadinessReport {
        val classroomBlockers = buildList {
            if (!snapshot.automatedChecksPassed) add("automated checks")
            if (!snapshot.debugApkBuilt) add("debug APK")
            if (!snapshot.githubCleanAfterPush) add("GitHub clean status")
        }
        val internalBlockers = buildList {
            addAll(classroomBlockers)
            if (!snapshot.manualSmokeTestPassed) add("manual smoke test")
            if (!snapshot.physicalDeviceTested) add("test device")
            if (!snapshot.teacherBriefReady) add("teacher brief")
            if (!snapshot.classroomConsentReady) add("classroom consent")
            if (!snapshot.demoEvidenceAccepted) add("showcase evidence")
        }
        val publicBlockers = buildList {
            addAll(internalBlockers)
            if (!snapshot.signedRelease) add("signed release")
            if (!snapshot.privacyPolicyUrlReady) add("privacy policy URL")
            if (!snapshot.backendDeployed) add("backend deployment")
            if (!snapshot.productionBackendGatePassed) add("production backend gate")
            if (!snapshot.questionBankLicenseReady) add("question bank license")
            if (!snapshot.playDataSafetyReviewed) add("Play Data Safety review")
        }.distinct()

        val readyForClassroomDemo = classroomBlockers.isEmpty()
        val readyForInternalPilot = internalBlockers.isEmpty()
        val readyForPublicLaunch = publicBlockers.isEmpty()

        val statusLabel = when {
            readyForPublicLaunch -> "可準備公開上架"
            readyForInternalPilot -> "可進入封閉內測"
            readyForClassroomDemo -> "可進行課堂展示"
            else -> "仍需修正後再展示"
        }
        val nextAction = when {
            readyForPublicLaunch -> "建立封閉測試名單，準備簽署版本與 Play Console 發布流程。"
            readyForInternalPilot -> "下一步先完成正式後端、隱私政策網址、簽章與題庫授權。"
            readyForClassroomDemo -> "下一步先補齊實機測試、同意資料與完整展示證據。"
            else -> "先修正建置、測試或 GitHub 狀態，再讓他人觀看。"
        }
        val honestSummary = when {
            readyForPublicLaunch -> "English+ 已通過目前定義的公開上架前條件；仍需依平台審查處理上架流程。"
            readyForInternalPilot -> "English+ 已可做封閉內測，但公開上架仍需要後端、簽章、隱私政策與正式題庫授權。"
            readyForClassroomDemo -> "English+ 目前適合課堂展示與產品走查；仍不是公開上架或正式跨裝置服務。"
            else -> "English+ 目前不應展示給外部使用者，需先完成基本驗證。"
        }

        return ProductReadinessReport(
            readyForClassroomDemo = readyForClassroomDemo,
            readyForInternalPilot = readyForInternalPilot,
            readyForPublicLaunch = readyForPublicLaunch,
            blockersForClassroomDemo = classroomBlockers,
            blockersForInternalPilot = internalBlockers,
            blockersForPublicLaunch = publicBlockers,
            statusLabel = statusLabel,
            honestSummary = honestSummary,
            nextAction = nextAction
        )
    }

    fun readinessChecklist(): List<ReadinessChecklistItem> {
        return listOf(
            ReadinessChecklistItem(
                id = "qa-verification",
                sourceContract = "ValidationContract",
                acceptanceEvidence = "Fresh Gradle tests, runnable APK build, lint, and clean GitHub status.",
                requiredFor = "classroom-demo"
            ),
            ReadinessChecklistItem(
                id = "showcase-evidence",
                sourceContract = "StoreReleaseContract",
                acceptanceEvidence = "Student, teacher, and volunteer screenshots and videos match the non-duplicate evidence package.",
                requiredFor = "internal-pilot"
            ),
            ReadinessChecklistItem(
                id = "privacy-consent",
                sourceContract = "PrivacyGovernanceContract",
                acceptanceEvidence = "Consent packet, data lifecycle runbook, and data safety draft are reviewed by the course team.",
                requiredFor = "internal-pilot"
            ),
            ReadinessChecklistItem(
                id = "backend-gate",
                sourceContract = "ProductionDeploymentContract",
                acceptanceEvidence = "HTTPS endpoints, role claims, server-held AI key, and backend handoff gate are verified.",
                requiredFor = "public-launch"
            ),
            ReadinessChecklistItem(
                id = "store-release",
                sourceContract = "StoreReleaseContract",
                acceptanceEvidence = "Signed release, privacy policy URL, Play Data Safety review, and tester list are ready.",
                requiredFor = "public-launch"
            ),
            ReadinessChecklistItem(
                id = "question-bank-license",
                sourceContract = "ProductionDeploymentContract",
                acceptanceEvidence = "Formal question source, license, import owner, and review process are confirmed.",
                requiredFor = "public-launch"
            )
        )
    }
}
