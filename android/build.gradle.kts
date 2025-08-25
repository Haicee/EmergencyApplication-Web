buildscript {
    extra.apply {
        set("kotlin_version", "1.9.0")
        set("java_version", JavaVersion.VERSION_17)
        set("compileSdkVersion", 35)
        set("targetSdkVersion", 35)
        set("minSdkVersion", 21)
    }
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.application") || project.plugins.hasPlugin("com.android.library")) {
            project.extensions.findByName("android")?.let { androidExt ->
                (androidExt as com.android.build.gradle.BaseExtension).apply {
                    compileSdkVersion(35)
                    defaultConfig {
                        minSdk = 21
                        targetSdk = 35
                    }
                    compileOptions {
                        sourceCompatibility = JavaVersion.VERSION_17
                        targetCompatibility = JavaVersion.VERSION_17
                    }
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
