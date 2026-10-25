import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:msgtest/scaffold.dart';
import 'package:msgtest/login_screen.dart';

Future<void> main() async {
  // Stellt sicher, dass die Flutter-Bindings vor der Initialisierung bereit sind
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
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
