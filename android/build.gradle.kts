// android/build.gradle.kts  (루트)

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// --- (당신이 쓰던 build 디렉토리 이동 로직: 유지) ---
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// --- Firebase Google Services 플러그인: 루트에는 "버전 선언 + apply false"만 ---
plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}
