-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.mujbites.** { *; }
-dontwarn io.flutter.embedding.**

# Add these new rules for Google Play Core library
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.splitcompat.**

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable