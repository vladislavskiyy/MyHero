// Top‐level build file where you can add configuration options common to all sub-projects/modules.
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Android Gradle Plugin
        classpath("com.android.tools.build:gradle:8.1.0")
        // Google Services plugin для Firebase
        classpath("com.google.gms:google-services:4.3.15")
    }
}

plugins {
    // Не применять эти плагины здесь, они будут подклю­чаться в модулях
    id("com.android.application") apply false
    id("com.android.library")    apply false
    kotlin("android")            apply false

    // Регистрация плагина Google Services (но пока без apply)
    id("com.google.gms.google-services") version "4.3.15" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Переопределяем директорию сборки на уровень выше (../../build)
val newBuildDir: Directory = rootProject
    .layout
    .buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // Каждому сабпроекту своя папка в ../../build/<module>
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Для корректного порядка сборки
subprojects {
    project.evaluationDependsOn(":app")
}

// Применяем Google Services плагин к модулю app
project(":app") {
    plugins.apply("com.google.gms.google-services")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
