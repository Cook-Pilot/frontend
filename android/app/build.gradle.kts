plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

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
    }

    signingConfigs {
        // 팀 공용 debug 키. PC마다 자동 생성되는 ~/.android/debug.keystore 대신 이걸로 서명해서
        // 누가 빌드하든 SHA-1·카카오 키 해시가 같게 한다 — 구글 Android 클라이언트와 카카오
        // 키 해시를 개발자(PC)마다 등록할 필요가 없어진다. 비밀번호가 공개된 debug 키라 비밀이 아니다.
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
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
