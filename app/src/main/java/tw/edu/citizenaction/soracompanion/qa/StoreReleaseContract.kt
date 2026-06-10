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

data class DemoEvidenceItem(
    val role: String,
    val screenId: String,
    val mediaType: String,
    val label: String,
    val acceptanceNote: String
)

data class DemoEvidencePackage(
    val items: List<DemoEvidenceItem>,
    val folderRule: String,
    val minimumVideoSeconds: Int
)

data class DemoMediaCapture(
    val role: String,
    val screenId: String,
    val mediaType: String,
    val durationSeconds: Int,
    val hasUserAction: Boolean,
    val isDuplicate: Boolean,
    val exposesInternalCopy: Boolean
)

data class DemoEvidenceGate(
    val readyForShowcase: Boolean,
    val blockers: List<String>
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

    fun demoEvidencePackage(): DemoEvidencePackage {
        val items = listOf(
            DemoEvidenceItem("student", "student_01_role_login", "screenshot", "學生端入口與登入", "看得到學生路徑，沒有老師或志工工作台混入。"),
            DemoEvidenceItem("student", "student_02_check_in", "screenshot", "四題心情檢測", "心情、時間、挑戰意願與題型偏好都能完成。"),
            DemoEvidenceItem("student", "student_03_daily_mission", "screenshot", "今日任務與做題進度", "進度只計算今日任務答對題，不包含心情檢測。"),
            DemoEvidenceItem("student", "student_04_practice_feedback", "screenshot", "答題回饋", "答對與答錯都有明確狀態與下一步。"),
            DemoEvidenceItem("student", "student_05_mission_complete", "screenshot", "今日任務完成", "完成後有明確鼓勵，並提供自由練習。"),
            DemoEvidenceItem("student", "student_06_free_practice", "screenshot", "自由練習中心", "學生可選難度、題型與挑戰，不被強迫回心情檢測。"),
            DemoEvidenceItem("student", "student_07_support_thread", "screenshot", "學生支援串", "學生能看見求助、回覆與下一步。"),
            DemoEvidenceItem("student", "student_08_learning_map", "screenshot", "學習地圖", "顯示學習節點與進度，不混入老師資料。"),
            DemoEvidenceItem("student", "student_09_checkin_video", "video", "學生心情檢測到完成任務影片", "完整錄到檢測、任務、做題、完成鼓勵。"),
            DemoEvidenceItem("student", "student_10_free_practice_video", "video", "學生自由練習影片", "完整錄到直接進練習中心、選題、作答與回饋。"),
            DemoEvidenceItem("teacher", "teacher_01_home", "screenshot", "老師今日工作台", "先看到最需要接住的學生與班級狀態。"),
            DemoEvidenceItem("teacher", "teacher_02_roster", "screenshot", "學生名單", "學生清單、風險與進度可掃描。"),
            DemoEvidenceItem("teacher", "teacher_03_student_detail", "screenshot", "學生詳情", "看得到學習紀錄、求助與下一步。"),
            DemoEvidenceItem("teacher", "teacher_04_reply", "screenshot", "老師回覆", "能給學生自訂回覆，不只是固定文案。"),
            DemoEvidenceItem("teacher", "teacher_05_question_bank", "screenshot", "題庫管理", "題型、難度、來源與審題狀態清楚。"),
            DemoEvidenceItem("teacher", "teacher_06_report", "screenshot", "班級報告", "報告能說明班級進度與支援狀態。"),
            DemoEvidenceItem("teacher", "teacher_07_priority_video", "video", "老師接住學生影片", "錄到老師找出優先學生、看證據、回覆與返回工作台。"),
            DemoEvidenceItem("volunteer", "volunteer_01_home", "screenshot", "志工接力首頁", "志工只看到陪練與接力，不看到老師行政。"),
            DemoEvidenceItem("volunteer", "volunteer_02_queue", "screenshot", "接力佇列", "等待陪練學生與狀態清楚。"),
            DemoEvidenceItem("volunteer", "volunteer_03_student_context", "screenshot", "學生接力脈絡", "志工看得到需要陪伴的原因與下一步。"),
            DemoEvidenceItem("volunteer", "volunteer_04_script", "screenshot", "陪練腳本", "腳本協助志工陪練，而不是替老師做行政。"),
            DemoEvidenceItem("volunteer", "volunteer_05_sync", "screenshot", "接力同步狀態", "同步或待補傳狀態可理解。"),
            DemoEvidenceItem("volunteer", "volunteer_06_handoff_video", "video", "志工接力影片", "錄到接單、查看腳本、留下接力紀錄與返回佇列。")
        )
        return DemoEvidencePackage(
            items = items,
            folderRule = "Use separate folders: student, teacher, volunteer. File names must match role_sequence_screen, such as student_03_daily_mission.png.",
            minimumVideoSeconds = 45
        )
    }

    fun demoEvidenceGate(captures: List<DemoMediaCapture>): DemoEvidenceGate {
        val packageSpec = demoEvidencePackage()
        val requiredIds = packageSpec.items.map { it.screenId }.toSet()
        val capturedIds = captures.map { it.screenId }.toSet()
        val capturedRoles = captures.map { it.role }.toSet()
        val blockers = buildList {
            if (!capturedRoles.containsAll(setOf("student", "teacher", "volunteer")) || !capturedIds.containsAll(requiredIds)) {
                add("missing role coverage")
            }
            if (captures.any { it.isDuplicate } || captures.size != capturedIds.size) {
                add("duplicate captures")
            }
            if (captures.any { it.mediaType == "video" && it.durationSeconds < packageSpec.minimumVideoSeconds }) {
                add("videos too short")
            }
            if (captures.any { !it.hasUserAction }) {
                add("missing user actions")
            }
            if (captures.any { it.exposesInternalCopy }) {
                add("internal copy exposed")
            }
        }
        return DemoEvidenceGate(
            readyForShowcase = blockers.isEmpty(),
            blockers = blockers
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
