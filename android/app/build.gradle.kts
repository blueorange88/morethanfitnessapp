import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("dev.flutter.flutter-gradle-plugin")
}

val uploadKeyPropertiesFile = rootProject.file("key.properties")
val uploadKeyProperties = Properties().apply {
    if (uploadKeyPropertiesFile.exists()) {
        uploadKeyPropertiesFile.inputStream().use(::load)
    }
}
val requiredUploadKeyProperties =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val hasUploadSigningProperties = requiredUploadKeyProperties.all {
    !uploadKeyProperties.getProperty(it).isNullOrBlank()
}
val useLegacyLocalProdSigning =
    providers.gradleProperty("mtfLegacyLocalProdSigning").orNull.toBoolean()
val isBundleBuild = gradle.startParameter.taskNames.any {
    it.contains("bundle", ignoreCase = true)
}

if (useLegacyLocalProdSigning && isBundleBuild) {
    throw GradleException(
        "Legacy local PROD signing is APK-only. Play AAB must use the upload key.",
    )
}

android {
    namespace = "com.example.mtf_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildFeatures {
        compose = true
    }

    defaultConfig {
        applicationId = "com.example.mtf_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("upload") {
            if (hasUploadSigningProperties) {
                storeFile = file(uploadKeyProperties.getProperty("storeFile"))
                storePassword = uploadKeyProperties.getProperty("storePassword")
                keyAlias = uploadKeyProperties.getProperty("keyAlias")
                keyPassword = uploadKeyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (useLegacyLocalProdSigning) "debug" else "upload",
            )
            proguardFiles("proguard-rules.pro")
        }
    }

    flavorDimensions += "environment"
    productFlavors {
        create("prod") {
            dimension = "environment"
        }
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
    }
}

val devGoogleServicesFile = file("src/dev/google-services.json")
tasks.configureEach {
    if (name.startsWith("validateSigning") && name.endsWith("Release")) {
        doFirst {
            if (!useLegacyLocalProdSigning) {
                check(hasUploadSigningProperties) {
                    "Play release signing requires ignored android/key.properties " +
                        "with storeFile, storePassword, keyAlias, and keyPassword."
                }
            }
        }
    }
    if (name.startsWith("processDev") && name.endsWith("GoogleServices")) {
        doFirst {
            check(devGoogleServicesFile.exists()) {
                "Dev Firebase configuration is missing: " +
                    "android/app/src/dev/google-services.json"
            }
        }
    }
}

dependencies {
    implementation(project(":home_widget"))

    implementation("androidx.glance:glance:1.1.1")
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.glance:glance-material3:1.1.1")

    implementation("com.google.mlkit:text-recognition-korean:16.0.1")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

configurations.all {
    resolutionStrategy {
        force("androidx.glance:glance:1.1.1")
        force("androidx.glance:glance-appwidget:1.1.1")
        force("androidx.glance:glance-material3:1.1.1")
    }
}
