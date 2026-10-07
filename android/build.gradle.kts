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

    // tesseract_ocr 0.5.0 ships a Kotlin template class with the same name as the
    // Java plugin. When compiled, it registers the channel but does not implement
    // extractText, which causes MissingPluginException at runtime.
    if (project.name == "tesseract_ocr") {
        val kotlinStub = project.projectDir.resolve(
            "src/main/kotlin/io/paratoner/tesseract_ocr/TesseractOcrPlugin.kt",
        )
        if (kotlinStub.exists()) {
            kotlinStub.delete()
        }

        val patchedPlugin = rootProject.file("tesseract_patches/TesseractOcrPlugin.java")
        val pluginJava = project.projectDir.resolve(
            "src/main/java/io/paratoner/tesseract_ocr/TesseractOcrPlugin.java",
        )
        if (patchedPlugin.exists()) {
            patchedPlugin.copyTo(pluginJava, overwrite = true)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
