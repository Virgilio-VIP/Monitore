# Proguard rules for Maria Maia
# Configurações de obfuscação para release

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class com.google.android.material.** { *; }
-keep class androidx.** { *; }

# Keep all classes in the app package
-keep class br.com.monitore.app.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom application classes
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
