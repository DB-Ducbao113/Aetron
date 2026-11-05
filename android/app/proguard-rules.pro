# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Isar & SQLite
-keep class io.isar.** { *; }
-dontwarn io.isar.**

# Desugaring & Kotlin Coroutines
-dontwarn java.time.**
-dontwarn org.codehaus.mojo.animal_sniffer.**

# Flutter Deferred Components & Play Core
-dontwarn com.google.android.play.core.**
