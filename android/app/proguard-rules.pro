# Reglas de ProGuard para evitar que R8 elimine código necesario en producción
# Esto soluciona: java.lang.NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> []

# Mantener clases de WorkManager y Room intactas
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.startup.** { *; }
-keep class androidx.sqlite.** { *; }

# Mantener modelos de Firebase si aplica
-keep class com.google.firebase.** { *; }

# Mantener secure storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
