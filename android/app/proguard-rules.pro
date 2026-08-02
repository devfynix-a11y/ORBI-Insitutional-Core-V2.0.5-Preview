# Flutter and Firebase baseline ProGuard rules.
# Keep the Flutter engine JNI entrypoints and Firebase reflection-based APIs.

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugin.platform.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.crashlytics.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.analytics.** { *; }
-keep class androidx.annotation.Keep { *; }

# Keep Play Core classes used by Flutter's Play Store split/deferred component support.
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep entrypoint used by Flutter plugin registration.
-keep class com.orbi.mobile.** { *; }

# Keep model classes referenced by reflection or serialization.
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep classes annotated with @Keep.
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Keep runtime annotation information.
-keepattributes *Annotation*

# Keep synthetic methods used by Lambdas and Kotlin metadata.
-keepclassmembers class kotlin.Metadata { *; }
-keepclassmembers class kotlin.jvm.internal.Lambda { *; }
-keepclassmembers class kotlin.jvm.internal.FunctionReference { *; }

# Workaround for Firebase Crashlytics and serialization.
-keep class com.google.firebase.crashlytics.** { *; }
-keep class com.google.firebase.ktx.** { *; }
-keep class com.google.firebase.messaging.ktx.** { *; }
