allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Fix build directory location (optional but fine)
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    layout.buildDirectory.set(newSubprojectBuildDir)
}

// ✅ Ensure proper evaluation order
subprojects {
    evaluationDependsOn(":app")
}

// ✅ Force Java 17 everywhere (IMPORTANT FIX)
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
}

// ✅ Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}