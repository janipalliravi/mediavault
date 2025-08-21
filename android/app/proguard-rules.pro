# Keep Flutter and plugin classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# AndroidX common keeps
-keep class androidx.lifecycle.** { *; }
-keep class androidx.annotation.** { *; }

# Firebase/Google Play services (if used)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Play Core for deferred components (R8 only)
#-keep class com.google.android.play.core.** { *; }

# sqflite/sqlite helpers
-keep class org.sqlite.** { *; }
-keep class android.database.** { *; }

# Plugin registrant
-keep class **PluginRegistrant** { *; }

# App package (models, if reflection used later)
-keep class com.example.mediavault.** { *; }

# Preserve source info for better crash logs
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable
