# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }

# WebRTC
-keep class org.webrtc.** { *; }

# Avoid stripping generic models
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# Fix for Play Core deferred components
-dontwarn com.google.android.play.core.**
