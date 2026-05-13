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
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android")
            try {
                // 1. Force Namespace Fix
                val namespaceMethod = android.javaClass.getMethod("getNamespace")
                val namespace = namespaceMethod.invoke(android)
                if (namespace == null) {
                    val setNamespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespaceMethod.invoke(android, "com.tharushi.upeksha.${project.name}")
                }

                // 2. Manifest Package Attribute Fix (Modern AGP)
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    var content = manifestFile.readText()
                    if (content.contains("package=")) {
                        println("Fixing Manifest for: ${project.name}")
                        content = content.replace(Regex("package=\"[^\"]*\""), "")
                        manifestFile.writeText(content)
                    }
                }
            } catch (e: Exception) {
                // Ignore errors during reflection
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
