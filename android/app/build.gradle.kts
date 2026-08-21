// Kotlin DSL 에서는 `java` 가 Gradle 의 java 확장으로 잡혀 java.util 을 직접 쓸 수 없다 — import 로 푼다.
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// android/local.properties 의 값. 비밀(네이버 Client Secret)을 저장소 밖에 두기 위한 통로다.
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
fun localProperty(name: String): String? = localProperties.getProperty(name)?.takeIf { it.isNotBlank() }

android {
    namespace = "com.cookpilot.cookpilot"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications가 요구하는 core library desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.cookpilot.cookpilot"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 카카오 로그인 리다이렉트 스킴(kakao<네이티브앱키>://address)에 쓰인다.
        // AndroidManifest 는 빌드 타임에 확정되므로 --dart-define 으로는 바꿀 수 없다.
        // Dart 쪽 기본값(lib/core/api/kakao_config.dart)과 같은 값을 유지해야 한다.
        manifestPlaceholders["KAKAO_NATIVE_APP_KEY"] =
            (project.findProperty("kakaoNativeAppKey") as String?)
                ?: "49c1ac97b674198d1b8f7d47f38897f8"

        // 네이버 로그인. 플러그인이 Client ID/Secret 을 매니페스트 meta-data 에서 읽는다.
        // Secret 은 저장소에 두지 않고 android/local.properties(gitignored) 에서 가져온다:
        //   naver.clientId=...
        //   naver.clientSecret=...
        // 비어 있으면 메타데이터도 비어 SDK 초기화가 실패하지만, Dart 쪽(NAVER_CLIENT_ID
        // dart-define)이 비어 있으면 버튼을 그리지 않으므로 앱은 정상 동작한다.
        manifestPlaceholders["NAVER_CLIENT_ID"] =
            localProperty("naver.clientId") ?: (project.findProperty("naverClientId") as String?) ?: ""
        manifestPlaceholders["NAVER_CLIENT_SECRET"] =
            localProperty("naver.clientSecret") ?: (project.findProperty("naverClientSecret") as String?) ?: ""
        manifestPlaceholders["NAVER_CLIENT_NAME"] = "쿡로그"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
