import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:msgtest/scaffold.dart';
import 'package:msgtest/login_screen.dart';

/// Top-Level Handler für Firebase Push-Benachrichtigungen im Hintergrund / wenn App geschlossen ist
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Stellt sicher, dass Firebase initialisiert ist, bevor auf Nachrichten zugegriffen wird
  await Firebase.initializeApp();
  debugPrint(
    'FCM Hintergrund-Nachricht empfangen [ID: ${message.messageId}]: ${message.notification?.title}',
  );
}

Future<void> main() async {
  // Stellt sicher, dass die Flutter-Bindings vor der Initialisierung bereit sind
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Hintergrund-Handler VOR Firebase-Initialisierung / runApp registrieren
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // 2. Benachrichtigungs-Berechtigungen anfordern (Android 13+ & iOS)
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM Berechtigungsstatus: ${settings.authorizationStatus}');

    // Vorzeigeeinstellungen für den Vordergrund (iOS)
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e) {
    debugPrint('FCM Berechtigung konnte nicht angefordert werden: $e');
  }

  // Supabase mit Ihren Anmeldedaten initialisieren
  await Supabase.initialize(
    url: 'https://cfvobcohkupgbzpdwfpq.supabase.co',
    publishableKey: 'sb_publishable_NI6E8G6sk7tKmm-Hjk6_FA_wu2QIvOt',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness & MsgTest',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.greenAccent),
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
      ),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            return const MyHomePage();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
