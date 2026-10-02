# ==============================================================================
# R8 / ProGuard Code Optimization & Obfuscation
# ==============================================================================

# Enable multi-pass optimization
-optimizationpasses 5

# Allow R8 to modify access modifiers for aggressive inlining and class merging
-allowaccessmodification

# Repackage all obfuscated classes into the root package to eliminate duplicate package name strings
-repackageclasses ''

# Rename source file attributes to a generic name for stack traces
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# Preserve runtime annotations required for reflection in Firebase, Flutter, and AndroidX
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# ==============================================================================
# Flutter Framework
# ==============================================================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Keep native JNI methods (required for Flutter engine and C/C++ plugins)
-keepclasseswithmembernames class * {
    native <methods>;
}

# ==============================================================================
# Firebase & Google Play Services
# ==============================================================================
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
-dontwarn com.google.android.play.core.**
-dontwarn javax.annotation.**

# Firebase Auth & Firestore models
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable CREATORs for IPC and lifecycle stability across devices
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep Serializable for intent extras
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ==============================================================================
# CameraX & ML Kit
# ==============================================================================
-dontwarn androidx.camera.**
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.odml.**

# ==============================================================================
# Kotlin Coroutines & Standard Library
# ==============================================================================
-dontwarn kotlin.**
-dontwarn kotlinx.**
