# Flutter Engine & Plugin Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Attributes & Annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-dontwarn javax.annotation.**

# Firebase & Google Play Services
-dontwarn com.google.android.gms.**
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Play Core & Deferred Components (used conditionally by Flutter engine)
-dontwarn com.google.android.play.core.**

# Keep Native JNI Methods
-keepclasseswithmembernames class * {
    native <methods>;
}
