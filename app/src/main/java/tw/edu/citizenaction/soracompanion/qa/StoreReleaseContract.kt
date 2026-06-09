package tw.edu.citizenaction.soracompanion.qa

data class PlayStoreListing(
    val appName: String,
    val shortDescription: String,
    val fullDescription: String,
    val contactEmail: String
)

data class PrivacyDeclaration(
    val dataTypes: List<String>,
    val aiKeyLocation: String,
    val allowsProductionKeyOnDevice: Boolean,
    val studentDataPolicy: String
)

data class StoreReadinessGate(
    val readyForStore: Boolean,
    val blockers: List<String>
)

data class ClassroomPilotGate(
    val readyForPilot: Boolean,
    val blockers: List<String>
)

enum class BuildArtifactKind {
    DebugApk,
    ReleaseApk,
    ReleaseAab
}

data class BuildArtifactInstruction(
    val kind: BuildArtifactKind,
    val gradleTask: String,
    val outputPath: String,
    val whenToUse: String
)

data class PlayConsoleInternalTestChecklist(
    val requiredItems: List<String>,
    val readyForPublicLaunch: Boolean
)

data class ScreenshotGroup(
    val role: String,
    val requiredScreens: List<String>,
    val videoScenario: String
)

data class ScreenshotPlan(
    val groups: List<ScreenshotGroup>,
    val namingRule: String
)

data class ExternalCredentialGap(
    val id: String,
    val label: String,
    val owner: String,
    val reason: String,
    val requiredForPublicLaunch: Boolean
)

object StoreReleaseContract {
    const val STORE_RELEASE_SCHEMA_VERSION = 10

    fun playStoreListing(): PlayStoreListing {
        return PlayStoreListing(
            appName = "English+",
            shortDescription = "偏鄉學生英語練習、每日任務與情緒支持平台",
            fullDescription = """
                English+ 是為偏鄉學生設計的英語練習與支持平台。學生先用簡短檢測整理今天的情緒、
                可用時間與想練習的題型，再進入適合自己的每日任務與自由練習。答錯時，系統會提供
                清楚詳解與低壓力提示；需要真人陪伴時，老師與志工可以接續看見求助脈絡並回覆。

                這個版本適合課堂內測、專題展示與小規模試用，重點是讓英文卡關不只停在分數，而是
                變成下一個可完成的小步驟。
            """.trimIndent(),
            contactEmail = "english-plus@example.edu"
        )
    }

    fun privacyDeclaration(): PrivacyDeclaration {
        return PrivacyDeclaration(
            dataTypes = listOf(
                "student learning records",
                "class collaboration notes",
                "AI support context",
                "local account role and class code",
                "offline sync status"
            ),
            aiKeyLocation = "server-side proxy",
            allowsProductionKeyOnDevice = false,
            studentDataPolicy = "Collect only learning context needed for support, reports, sync, and teacher/volunteer handoff."
        )
    }

    fun storeReadinessGate(
        signedRelease: Boolean,
        privacyPolicyUrlReady: Boolean,
        backendDeployed: Boolean,
        classroomConsentReady: Boolean
    ): StoreReadinessGate {
        val blockers = buildList {
            if (!signedRelease) add("signed release")
            if (!privacyPolicyUrlReady) add("privacy policy URL")
            if (!backendDeployed) add("backend deployment")
            if (!classroomConsentReady) add("classroom consent")
        }
        return StoreReadinessGate(blockers.isEmpty(), blockers)
    }

    fun classroomPilotGate(
        debugApkBuilt: Boolean,
        teacherBriefReady: Boolean,
        testDeviceReady: Boolean
    ): ClassroomPilotGate {
        val blockers = buildList {
            if (!debugApkBuilt) add("debug APK")
            if (!teacherBriefReady) add("teacher brief")
            if (!testDeviceReady) add("test device")
        }
        return ClassroomPilotGate(blockers.isEmpty(), blockers)
    }

    fun buildArtifactInstructions(): List<BuildArtifactInstruction> {
        return listOf(
            BuildArtifactInstruction(
                kind = BuildArtifactKind.DebugApk,
                gradleTask = ":app:assembleDebug",
                outputPath = "app/build/outputs/apk/debug/app-debug.apk",
                whenToUse = "Use for classroom demos, emulator runs, and internal screenshots before signing."
            ),
            BuildArtifactInstruction(
                kind = BuildArtifactKind.ReleaseApk,
                gradleTask = ":app:assembleRelease",
                outputPath = "app/build/outputs/apk/release/app-release-unsigned.apk",
                whenToUse = "Use only to verify release build configuration; not enough for Play Store upload."
            ),
            BuildArtifactInstruction(
                kind = BuildArtifactKind.ReleaseAab,
                gradleTask = ":app:bundleRelease",
                outputPath = "app/build/outputs/bundle/release/app-release.aab",
                whenToUse = "Use for Play Console internal testing after signing and release credentials are ready."
            )
        )
    }

    fun playConsoleInternalTestChecklist(): PlayConsoleInternalTestChecklist {
        return PlayConsoleInternalTestChecklist(
            requiredItems = listOf(
                "signed Android App Bundle",
                "internal tester email list",
                "privacy policy URL",
                "Data Safety draft",
                "app description",
                "student/teacher/volunteer screenshots",
                "release notes",
                "contact email"
            ),
            readyForPublicLaunch = false
        )
    }

    fun screenshotPlan(): ScreenshotPlan {
        return ScreenshotPlan(
            groups = listOf(
                ScreenshotGroup(
                    role = "student",
                    requiredScreens = listOf(
                        "role choice and student login",
                        "check-in",
                        "daily mission",
                        "practice answer feedback",
                        "support thread",
                        "learning map"
                    ),
                    videoScenario = "Student completes check-in, finishes the assigned mission, asks for support, and returns to optional practice."
                ),
                ScreenshotGroup(
                    role = "teacher",
                    requiredScreens = listOf(
                        "teacher home",
                        "student roster",
                        "student detail",
                        "reply composer",
                        "question bank",
                        "class report"
                    ),
                    videoScenario = "Teacher identifies the priority student, reviews evidence, replies, and opens the class report."
                ),
                ScreenshotGroup(
                    role = "volunteer",
                    requiredScreens = listOf(
                        "volunteer home",
                        "handoff queue",
                        "student handoff detail",
                        "mentor script",
                        "sync status"
                    ),
                    videoScenario = "Volunteer reviews one request, follows the script, leaves an internal handoff note, and returns to queue."
                )
            ),
            namingRule = "Use role_screen_sequence, for example student_03_daily_mission.png and teacher_02_roster.mp4."
        )
    }

    fun externalCredentialGaps(): List<ExternalCredentialGap> {
        return listOf(
            ExternalCredentialGap(
                id = "firebase-auth",
                label = "Firebase Auth or school account integration",
                owner = "user-or-school",
                reason = "Real login needs a Firebase project or school identity provider, OAuth settings, and role claims.",
                requiredForPublicLaunch = true
            ),
            ExternalCredentialGap(
                id = "google-services-json",
                label = "google-services.json",
                owner = "user-or-school",
                reason = "Android Firebase clients require the project-specific configuration file.",
                requiredForPublicLaunch = true
            ),
            ExternalCredentialGap(
                id = "ai-proxy",
                label = "Secure AI backend proxy",
                owner = "user-or-school",
                reason = "Production AI calls need a server-held key and HTTPS endpoint, not a mobile-held secret.",
                requiredForPublicLaunch = true
            ),
            ExternalCredentialGap(
                id = "release-keystore",
                label = "Release signing keystore",
                owner = "user",
                reason = "Play Console upload requires a signed Android App Bundle.",
                requiredForPublicLaunch = true
            ),
            ExternalCredentialGap(
                id = "privacy-policy-url",
                label = "Public privacy policy URL",
                owner = "user-or-school",
                reason = "Play Console Data Safety and public launch require a reachable privacy policy page.",
                requiredForPublicLaunch = true
            ),
            ExternalCredentialGap(
                id = "final-question-bank-license",
                label = "Formal question bank license and content source",
                owner = "user-or-school",
                reason = "Public use needs verified content rights and a content-management owner.",
                requiredForPublicLaunch = true
            )
        )
    }
}
