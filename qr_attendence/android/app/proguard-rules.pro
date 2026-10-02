# Flutter Generated Plugin Registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Keep Native JNI Methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve annotations and line numbers for crash reporting
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# Suppress harmless warnings for optional/deferred components
-dontwarn com.google.android.play.core.**
-dontwarn javax.annotation.**
-dontwarn com.google.android.gms.**
