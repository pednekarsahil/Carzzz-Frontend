plugins {
    id("com.android.application")
    id("kotlin-android")

    // ✅ Add this
    id("com.google.gms.google-services")

    // Flutter plugin (keep last)
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.carrzz"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.carrzz"
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

dependencies {
    // ✅ Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.11.0"))

    // ✅ Firebase Analytics (example)
    implementation("com.google.firebase:firebase-analytics")

    // 👉 You can add more like:
    // implementation("com.google.firebase:firebase-auth")
    // implementation("com.google.firebase:firebase-firestore")
}

flutter {
    source = "../.."
}