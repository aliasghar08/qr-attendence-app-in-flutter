allprojects {
    repositories {
        google()
        mavenCentral()
    }
    configurations.all {
        resolutionStrategy {
            force("com.google.mlkit:barcode-scanning:17.3.0")
            force("com.google.android.gms:play-services-mlkit-barcode-scanning:18.3.1")
            force("androidx.camera:camera-core:1.4.1")
            force("androidx.camera:camera-camera2:1.4.1")
            force("androidx.camera:camera-lifecycle:1.4.1")
            force("androidx.camera:camera-view:1.4.1")
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
