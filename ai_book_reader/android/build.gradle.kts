allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

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

subprojects {
    val fixNamespace: (Project) -> Unit = { proj ->
        if (proj.plugins.hasPlugin("com.android.library")) {
            val androidExtension = proj.extensions.findByName("android") as? com.android.build.gradle.LibraryExtension
            if (androidExtension != null && androidExtension.namespace == null) {
                val manifestFile = proj.file("src/main/AndroidManifest.xml")
                var pkgName: String? = null
                if (manifestFile.exists()) {
                    val match = Regex("""package\s*=\s*"([^"]+)"""").find(manifestFile.readText())
                    if (match != null) {
                        pkgName = match.groupValues[1]
                    }
                }
                androidExtension.namespace = pkgName ?: "com.example.${proj.name.replace("-", "_")}"
            }
        }
    }
    if (state.executed) {
        fixNamespace(this)
    } else {
        afterEvaluate { fixNamespace(this) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
