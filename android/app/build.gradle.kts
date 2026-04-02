plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.br.voxfinance"
    compileSdk = flutter.compileSdkVersion

    // 👇 ALTERE AQUI
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.br.voxfinance"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Nome do APK gerado (release = voxfinance.apk)
// Observação: algumas versões do Android Gradle Plugin não expõem `outputFileName`.
// Então renomeamos via uma task de cópia ao final do assembleRelease.
tasks.register("copyReleaseApkAsVoxFinance") {
    doLast {
        val rootBuildDir = rootProject.layout.buildDirectory.get().asFile
        val releaseApk = rootBuildDir.resolve("app/outputs/apk/release/app-release.apk")

        if (!releaseApk.exists()) {
            throw GradleException("APK release não encontrado em: ${releaseApk.absolutePath}")
        }

        // 1) Deixa também no caminho que o Flutter geralmente procura
        val flutterApkDir = rootBuildDir.resolve("app/outputs/flutter-apk")
        flutterApkDir.mkdirs()
        releaseApk.copyTo(flutterApkDir.resolve("app-release.apk"), overwrite = true)

        // 2) Nome final solicitado
        releaseApk.copyTo(flutterApkDir.resolve("voxfinance.apk"), overwrite = true)
    }
}

// O Flutter pode registrar tasks em outra fase; evitamos falhar caso ainda não exista.
tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy("copyReleaseApkAsVoxFinance")
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // ML Kit Text Recognition - módulos adicionais (evita erro do R8 "Missing class ...Options")
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
}
