# Globale Attribute für Serialisierung und Typen erhalten
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Supabase & PostgREST Core-Bibliotheken schützen
-keep class com.supabase.** { *; }
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }
-keep class kotlinx.serialization.** { *; }

# Shared Preferences & Datastore absichern
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class androidx.datastore.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**
-dontwarn androidx.datastore.**

# Kotlin Coroutines erhalten
-keep class kotlinx.coroutines.** { *; }
-keep class kotlin.coroutines.** { *; }

# Essentielle Kotlin-Laufzeitklassen vor R8-Stripping schützen
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
