import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:msgtest/device_helper.dart';

/// Holt den aktuellen FCM-Token, sammelt die Geräteinformationen und speichert beides in Supabase (user_profiles).
Future<void> saveFcmTokenAndDeviceInfo() async {
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      // FCM Topic für Push Notifications abonnieren
      await FirebaseMessaging.instance.subscribeToTopic('all_users');
    } catch (e) {
      debugPrint('Konnte FCM Token nicht abrufen: $e');
    }

    // Fallback für Simulator / Emulator, falls kein FCM-Token generiert werden konnte
    fcmToken ??= 'simulator_fcm_token_${user.id}';
    final deviceInfo = await getDeviceInfo();

    await supabase.from('user_profiles').upsert({
      'id': user.id,
      'email': user.email,
      'fcm_token': fcmToken,
      'device_type': deviceInfo['device_type'],
      'os_version': deviceInfo['os_version'],
      'device_name': deviceInfo['device_name'],
      'updated_at': DateTime.now().toIso8601String(),
    });

    debugPrint(
      'FCM Token und Geräteinformationen erfolgreich in Supabase gespeichert.',
    );
  } catch (e) {
    debugPrint(
      'Fehler beim Speichern des FCM Tokens und der Geräteinfos in Supabase: $e',
    );
  }
}

/// Aktualisiert den Token bei Token-Refresh in Supabase (inkl. Geräteinfo).
Future<void> updateFcmTokenWithToken(String newToken) async {
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final deviceInfo = await getDeviceInfo();

    await supabase.from('user_profiles').upsert({
      'id': user.id,
      'email': user.email,
      'fcm_token': newToken,
      'device_type': deviceInfo['device_type'],
      'os_version': deviceInfo['os_version'],
      'device_name': deviceInfo['device_name'],
      'updated_at': DateTime.now().toIso8601String(),
    });

    debugPrint(
      'Neuer FCM Token (Refresh) erfolgreich in Supabase aktualisiert.',
    );
  } catch (e) {
    debugPrint('Fehler beim Aktualisieren des neuen FCM Tokens: $e');
  }
}
