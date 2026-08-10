import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties()

if (releaseSigningPropertiesFile.isFile) {
    releaseSigningPropertiesFile.inputStream().use(releaseSigningProperties::load)
}

val releaseStoreFilePath = releaseSigningProperties.getProperty("storeFile")?.trim().orEmpty()
val releaseStorePassword = releaseSigningProperties.getProperty("storePassword")?.trim().orEmpty()
val releaseKeyAlias = releaseSigningProperties.getProperty("keyAlias")?.trim().orEmpty()
val releaseKeyPassword = releaseSigningProperties.getProperty("keyPassword")?.trim().orEmpty()
val releaseStoreFile =
    if (releaseStoreFilePath.isEmpty()) null else rootProject.file(releaseStoreFilePath)

val releaseSigningError =
    when {
        !releaseSigningPropertiesFile.isFile ->
            "Release signing is not configured. Create android/key.properties."
        listOf(
            releaseStoreFilePath,
            releaseStorePassword,
            releaseKeyAlias,
            releaseKeyPassword,
        ).any(String::isEmpty) ->
            "Release signing is incomplete. Configure storeFile, storePassword, " +
                "keyAlias, and keyPassword in android/key.properties."
        releaseStoreFile?.isFile != true ->
            "Release signing keystore file does not exist."
        else -> null
    }

android {
    namespace = "com.ovexiq.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ovexiq.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningError == null) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

gradle.taskGraph.whenReady {
    val releaseTaskRequested = allTasks.any { task ->
        task.path.startsWith(":app:") && task.name.contains("Release", ignoreCase = true)
    }

    if (releaseTaskRequested && releaseSigningError != null) {
        throw GradleException(releaseSigningError)
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
