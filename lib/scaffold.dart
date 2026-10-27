// mein erste Projekt, jetzt mit GitHub Repository-Anbindung.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final PageController _controller = PageController(initialPage: 0);
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _notificationChannel;

  @override
  void initState() {
    super.initState();
    _updateFcmToken();

    // Lauscht auf automatische Token-Änderungen von Firebase während die App läuft
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _updateFcmTokenWithToken(newToken);
    });

    _setupRealtimeNotifications();
    _setupFcmListeners();
  }

  void _setupRealtimeNotifications() {
    _notificationChannel = _supabase
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final title = newRecord['title'] ?? 'Ziel erreicht!';
            final message = newRecord['message'] ?? '';

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(message),
                          ],
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF1B263B),
                  duration: const Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        )
        .subscribe();
  }

  void _setupFcmListeners() {
    // 1. Vordergrund-Nachrichten (App ist aktiv und geöffnet)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (mounted) {
        final title = message.notification?.title ?? 'Ziel erreicht!';
        final body = message.notification?.body ?? '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: $body'),
            backgroundColor: const Color(0xFF1B263B),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    // 2. App war im Hintergrund und wurde durch Tippen auf Push-Benachrichtigung geöffnet
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        'App aus dem Hintergrund durch Push-Benachrichtigung geöffnet',
      );
      _handleNotificationPayload(message);
    });

    // 3. App war vollständig beendet und wird durch Tippen auf Push-Benachrichtigung gestartet
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        debugPrint(
          'App aus beendetem Zustand durch Push-Benachrichtigung gestartet',
        );
        _handleNotificationPayload(message);
      }
    });
  }

  void _handleNotificationPayload(RemoteMessage message) {
    if (!mounted) return;
    final title =
        message.notification?.title ??
        message.data['title'] ??
        'Push-Benachrichtigung';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Geöffnet: $title - $body'),
        backgroundColor: const Color(0xFF2A9D8F),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updateFcmToken() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
        // FCM Topic abonnieren für Push Notifications
        await FirebaseMessaging.instance.subscribeToTopic('all_users');
      } catch (e) {
        debugPrint('Konnte FCM Token beim Start nicht abrufen: $e');
      }

      fcmToken ??= 'simulator_fcm_token_${user.id}';

      await _supabase.from('user_profiles').upsert({
        'id': user.id,
        'email': user.email,
        'fcm_token': fcmToken,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Fehler beim Aktualisieren des FCM Tokens in MyHomePage: $e');
    }
  }

  Future<void> _updateFcmTokenWithToken(String newToken) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('user_profiles').upsert({
        'id': user.id,
        'email': user.email,
        'fcm_token': newToken,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Fehler beim Aktualisieren des neuen FCM Tokens: $e');
    }
  }

  @override
  void dispose() {
    if (_notificationChannel != null) {
      _supabase.removeChannel(_notificationChannel!);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Abmelden',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
      body: PageView(
        controller: _controller,
        children: const [
          DetailPage(headline: 'Heute', daysInPast: 0),
          DetailPage(headline: 'Gestern', daysInPast: 1),
          DetailPage(headline: 'Vorgestern', daysInPast: 2),
        ],
      ),
    );
  }
}

class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.headline,
    required this.daysInPast,
  });

  final String headline;
  final int daysInPast;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late final String _dateString;
  late final Stream<List<Map<String, dynamic>>> _dataStream;

  // Maximalwerte als Konstanten definieren, damit UI und Logik immer übereinstimmen
  static const double maxSchritte = 12.0;
  static const double maxTrinken = 3.0;
  static const double maxKalorien = 8.0;

  // Zustandsspeicher für die drei Werte dieser Seite
  int _schritte = 0;
  int _trinken = 0;
  int _kalorien = 0;

  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    // Berechnet das exakte Datum im Format "YYYY-MM-DD" für die Datenbank
    final targetDate = DateTime.now().subtract(
      Duration(days: widget.daysInPast),
    );
    _dateString =
        "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

    // REALTIME-STREAM: Lauscht aktiv auf Änderungen für das spezifische Datum
    _dataStream = _supabase
        .from('fitness_data')
        .stream(primaryKey: ['date'])
        .eq('date', _dateString);
  }

  // Universelle Funktion zum Hochzählen einer bestimmten Spalte
  Future<void> _updateValue(
    String column,
    int currentValue,
    double maxVal,
    String unit,
  ) async {
    final newValue = currentValue + 1;

    try {
      // Upsert nutzt das 'date' als Key: Zeile updaten oder neu anlegen
      await _supabase.from('fitness_data').upsert({
        'date': _dateString,
        column: newValue,
      });

      // Prüfen, ob vMaxVal genau bei diesem Klick erreicht wurde
      if (currentValue < maxVal && newValue >= maxVal) {
        await _sendNotificationToOthers(column, newValue, maxVal, unit);
      }
    } catch (e) {
      debugPrint('Fehler beim Speichern von $column: $e');
    }
  }

  Future<void> _sendNotificationToOthers(
    String category,
    int value,
    double maxVal,
    String unit,
  ) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final email = user.email ?? 'Ein Benutzer';
      final categoryName = category[0].toUpperCase() + category.substring(1);
      final title = '🎉 Ziel erreicht!';
      final message =
          '$email hat das Ziel für $categoryName (${maxVal.toInt()} $unit) erreicht!';

      // 1. In Supabase 'notifications' Tabelle eintragen (für In-App Realtime UI)
      await _supabase.from('notifications').insert({
        'sender_id': user.id,
        'sender_email': email,
        'title': title,
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Supabase Edge Function aufrufen (sendet FCM Push-Benachrichtigung an alle Geräte)
      try {
        await _supabase.functions.invoke(
          'clever-processor',
          body: {'topic': 'all_users', 'title': title, 'body': message},
        );
      } catch (e) {
        debugPrint('Fehler beim Aufruf der Edge Function clever-processor: $e');
      }
    } catch (e) {
      debugPrint('Fehler beim Senden der Benachrichtigung: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ein StreamBuilder sorgt dafür, dass das UI bei jeder DB-Änderung neu zeichnet
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dataStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Wenn Daten vorhanden sind, aktualisieren wir unsere lokalen Variablen
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final data = snapshot.data!.first;
          _schritte = data['schritte'] ?? 0;
          _trinken = data['trinken'] ?? 0;
          _kalorien = data['kalorien'] ?? 0;
        } else {
          // Falls für den Tag noch kein Eintrag existiert, setzen wir alles auf 0
          _schritte = 0;
          _trinken = 0;
          _kalorien = 0;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(0.0, 60, 0.0, 32.0),
          child: Column(
            children: [
              Text(
                widget.headline,
                style: const TextStyle(
                  fontSize: 48,
                  color: Color(0x80ffffff),
                  fontWeight: FontWeight.bold,
                ),
              ),

              // 1. Schritte (Spalte: schritte)
              TrackingElement(
                vColor: const Color(0xFF072B61),
                vIconData: Icons.directions_run,
                vUnit: 'm',
                vMaxVal: maxSchritte,
                vCounter: _schritte,
                onTap: () =>
                    _updateValue('schritte', _schritte, maxSchritte, 'm'),
              ),

              // 2. Trinken (Spalte: trinken)
              TrackingElement(
                vColor: const Color(0xFFBA1818),
                vIconData: Icons.local_drink,
                vUnit: 'ml',
                vMaxVal: maxTrinken,
                vCounter: _trinken,
                onTap: () =>
                    _updateValue('trinken', _trinken, maxTrinken, 'ml'),
              ),

              // 3. Kalorien (Spalte: kalorien)
              TrackingElement(
                vColor: const Color(0xFF66BA18),
                vIconData: Icons.fastfood,
                vUnit: 'kcal',
                vMaxVal: maxKalorien,
                vCounter: _kalorien,
                onTap: () =>
                    _updateValue('kalorien', _kalorien, maxKalorien, 'kcal'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TrackingElement extends StatelessWidget {
  const TrackingElement({
    super.key,
    required this.vColor,
    required this.vIconData,
    required this.vUnit,
    required this.vMaxVal,
    required this.vCounter,
    required this.onTap,
  });

  final Color vColor;
  final IconData vIconData;
  final String vUnit;
  final double vMaxVal;
  final int vCounter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0D1B2A),
      child: InkWell(
        onTap: onTap,
        splashColor: vColor.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32.0, 16.0, 32.0, 8.0),
                child: Row(
                  children: [
                    Icon(vIconData, color: Colors.blue, size: 50),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '${vCounter.toString()} / ${vMaxVal.toInt().toString()} $vUnit',
                        style: const TextStyle(
                          color: Color(0xff8eacea),
                          fontSize: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: LinearProgressIndicator(
                  value: (vCounter / vMaxVal).clamp(0.0, 1.0),
                  color: vColor,
                  backgroundColor: Colors.grey,
                  minHeight: 15.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
