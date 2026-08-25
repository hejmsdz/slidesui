import com.android.build.api.dsl.LibraryExtension

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
// Some plugins (e.g. bonsoir_android, pinned by dependency_overrides) declare a
// stale compileSdk. Align every plugin module with the app module so that the
// AndroidX dependencies resolve consistently.
// Note: afterEvaluate must be registered before evaluationDependsOn, which
// forces immediate evaluation.
subprojects {
    afterEvaluate {
        extensions.findByType(LibraryExtension::class.java)?.apply {
            if ((compileSdk ?: 0) < 37) {
                compileSdk = 37
            }
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
