import java.io.File

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "tw.edu.citizenaction.soracompanion"
    compileSdk = 35

    defaultConfig {
        applicationId = "tw.edu.citizenaction.soracompanion"
        minSdk = 26
        targetSdk = 35
        versionCode = 7
        versionName = "0.7.0"
    }

    buildTypes {
        debug {
            versionNameSuffix = "-debug"
        }

        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}

val prototypeUnitTestRoot = providers.systemProperty("java.io.tmpdir").map {
    File(it, "englishplus-unit-test")
}

val syncPrototypeUnitTestClasses by tasks.registering(Sync::class) {
    dependsOn("compileDebugKotlin", "compileDebugUnitTestKotlin", "processDebugUnitTestJavaRes")
    into(prototypeUnitTestRoot)
    from(layout.buildDirectory.dir("tmp/kotlin-classes/debug")) {
        into("main")
    }
    from(layout.buildDirectory.dir("tmp/kotlin-classes/debugUnitTest")) {
        into("test")
    }
    from(layout.buildDirectory.dir("intermediates/java_res/debug/processDebugJavaRes/out")) {
        into("main-res")
    }
    from(layout.buildDirectory.dir("intermediates/java_res/debugUnitTest/processDebugUnitTestJavaRes/out")) {
        into("test-res")
    }
}

val releaseUnitTestRoot = providers.systemProperty("java.io.tmpdir").map {
    File(it, "englishplus-release-unit-test")
}

val syncReleaseUnitTestClasses by tasks.registering(Sync::class) {
    dependsOn("compileReleaseKotlin", "compileReleaseUnitTestKotlin", "processReleaseUnitTestJavaRes")
    into(releaseUnitTestRoot)
    from(layout.buildDirectory.dir("tmp/kotlin-classes/release")) {
        into("main")
    }
    from(layout.buildDirectory.dir("tmp/kotlin-classes/releaseUnitTest")) {
        into("test")
    }
    from(layout.buildDirectory.dir("intermediates/java_res/release/processReleaseJavaRes/out")) {
        into("main-res")
    }
    from(layout.buildDirectory.dir("intermediates/java_res/releaseUnitTest/processReleaseUnitTestJavaRes/out")) {
        into("test-res")
    }
}

tasks.register<Test>("prototypeUnitTest") {
    description = "Runs English+ JVM unit tests with an explicit classpath."
    group = "verification"
    dependsOn(syncPrototypeUnitTestClasses)

    val mainClasses = prototypeUnitTestRoot.map { it.resolve("main") }
    val testClasses = prototypeUnitTestRoot.map { it.resolve("test") }
    testClassesDirs = files(testClasses)
    classpath = files(
        testClasses,
        mainClasses,
        prototypeUnitTestRoot.map { it.resolve("main-res") },
        prototypeUnitTestRoot.map { it.resolve("test-res") },
        configurations.named("debugUnitTestRuntimeClasspath")
    )
    useJUnit()
}

afterEvaluate {
    tasks.withType<Test>().matching { it.name == "testDebugUnitTest" }.configureEach {
        dependsOn(syncPrototypeUnitTestClasses)
        val mainClasses = prototypeUnitTestRoot.map { it.resolve("main") }
        val testClasses = prototypeUnitTestRoot.map { it.resolve("test") }
        testClassesDirs = files(testClasses)
        classpath = files(
            testClasses,
            mainClasses,
            prototypeUnitTestRoot.map { it.resolve("main-res") },
            prototypeUnitTestRoot.map { it.resolve("test-res") },
            configurations.named("debugUnitTestRuntimeClasspath")
        )
        useJUnit()
    }
    tasks.withType<Test>().matching { it.name == "testReleaseUnitTest" }.configureEach {
        dependsOn(syncReleaseUnitTestClasses)
        val mainClasses = releaseUnitTestRoot.map { it.resolve("main") }
        val testClasses = releaseUnitTestRoot.map { it.resolve("test") }
        testClassesDirs = files(testClasses)
        classpath = files(
            testClasses,
            mainClasses,
            releaseUnitTestRoot.map { it.resolve("main-res") },
            releaseUnitTestRoot.map { it.resolve("test-res") },
            configurations.named("releaseUnitTestRuntimeClasspath")
        )
        useJUnit()
    }
}
