# ARCore & Sceneform Protection
-keep class com.google.ar.sceneform.** { *; }
-keep class com.google.ar.core.** { *; }
-dontwarn com.google.ar.sceneform.**
-dontwarn com.google.devtools.build.android.desugar.runtime.**

# General Flutter & R8 rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.systemchannels.** { *; }

# Google Play Store (Deferred Components) Protection
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.common.**
-keep class com.google.android.play.core.** { *; }
