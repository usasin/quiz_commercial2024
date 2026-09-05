# ProGuard rules for Firebase and other libraries

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# AppCompat
-keep class android.support.v7.** { *; }
-dontwarn android.support.v7.**

# Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Butter Knife library
-keep class butterknife.** { *; }
-dontwarn butterknife.**

# OKHTTP3
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okio.**
