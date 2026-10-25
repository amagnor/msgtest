import 'package:msgtest/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  // Stellt sicher, dass die Flutter-Bindings vor der Initialisierung bereit sind
  WidgetsFlutterBinding.ensureInitialized();

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
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.greenAccent,
        ), //   deepPurple),
        scaffoldBackgroundColor: Color(0xFF0D1B2A),
      ),
      home: const MyHomePage(),
    );
  }
}
