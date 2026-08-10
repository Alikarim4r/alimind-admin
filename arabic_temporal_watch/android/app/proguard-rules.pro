# ProGuard / R8 rules for arabic_temporal_watch.
#
# minifyEnabled is currently false for the release build, so these rules are
# inert — they are kept so that enabling shrinking later does not silently
# break the Flutter engine or the plugins this app depends on.

# ── Flutter engine ────────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Plugins used by this app ──────────────────────────────────────────────────
# just_audio / ExoPlayer
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
# geolocator / permission_handler rely on reflection over Play Services
-dontwarn com.google.android.gms.**

# ── Keep annotations and native-callable members ─────────────────────────────
-keepattributes *Annotation*
-keepclasseswithmembernames class * {
    native <methods>;
}
