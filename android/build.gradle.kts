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

// flutter_pcm_sound 0.x가 compileSdk 33으로 고정돼 있어 androidx 의존성(34+ 요구)과 충돌한다.
// 플러그인이 업데이트되면 제거할 것.
subprojects {
    if (name == "flutter_pcm_sound") {
        afterEvaluate {
            extensions.findByType(com.android.build.api.dsl.CommonExtension::class.java)
                ?.compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
