# ── Flutter Core ─────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.view.** { *; }
-dontwarn io.flutter.**

# ── Flutter Plugin Communication ─────────────────────────────────────────────
-keep class * extends io.flutter.plugin.common.MessageCodec { *; }
-keep class * extends io.flutter.plugin.common.MethodChannel { *; }
-keep class * extends io.flutter.plugin.common.EventChannel { *; }
-keep class * extends io.flutter.plugin.common.BasicMessageChannel { *; }
-keep class * implements io.flutter.plugin.common.PluginRegistry { *; }

# ── FlutterFire Pigeon-generated Android classes ──────────────────────────────
# These are the actual Java classes (GeneratedAndroidFirebase*.java) that R8
# strips in release builds, causing "channel-error: Unable to establish
# connection" errors. Package: io.flutter.plugins.firebase.*
-keep class io.flutter.plugins.firebase.** { *; }
-keepclassmembers class io.flutter.plugins.firebase.** { *; }
-keep interface io.flutter.plugins.firebase.** { *; }

# Explicitly keep the Pigeon-generated host APIs (critical for channel binding)
-keep class io.flutter.plugins.firebase.core.GeneratedAndroidFirebaseCore { *; }
-keep class io.flutter.plugins.firebase.core.GeneratedAndroidFirebaseCore$* { *; }
-keep class io.flutter.plugins.firebase.core.FlutterFirebaseCorePlugin { *; }
-keep class io.flutter.plugins.firebase.core.FlutterFirebaseCoreRegistrar { *; }
-keep class io.flutter.plugins.firebase.core.FlutterFirebasePlugin { *; }
-keep class io.flutter.plugins.firebase.core.FlutterFirebasePluginRegistry { *; }

# Pigeon dev.flutter.pigeon namespace (Dart-side channel names)
-keep class dev.flutter.pigeon.** { *; }
-keep class * implements dev.flutter.pigeon.** { *; }
-keepclassmembers class dev.flutter.pigeon.** { *; }
-keep interface dev.flutter.pigeon.** { *; }
-keep class dev.flutter.plugins.** { *; }
-dontwarn dev.flutter.**

# ── Firebase & Google Play Services ──────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepclassmembers class com.google.firebase.** { *; }
-dontwarn com.google.**

# Firebase App Check - Play Integrity
-keep class com.google.android.play.core.integrity.** { *; }
-dontwarn com.google.android.play.core.integrity.**

# ── Kotlin & Reflection ───────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings { <fields>; }

# ── Reflection Attributes ─────────────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile,LineNumberTable
