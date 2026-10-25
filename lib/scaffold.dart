// mein erste Projekt, jetzt mit GitHub Repository-Anbindung.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final PageController _controller = PageController(initialPage: 0);

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
  Future<void> _updateValue(String column, int currentValue) async {
    final newValue = currentValue + 1;

    try {
      // Upsert nutzt das 'date' als Key: Zeile updaten oder neu anlegen
      await _supabase.from('fitness_data').upsert({
        'date': _dateString,
        column: newValue,
      });
    } catch (e) {
      debugPrint('Fehler beim Speichern von $column: $e');
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
                vMaxVal: 5000.0,
                vCounter: _schritte,
                onTap: () => _updateValue('schritte', _schritte),
              ),

              // 2. Trinken (Spalte: trinken)
              TrackingElement(
                vColor: const Color(0xFFBA1818),
                vIconData: Icons.local_drink,
                vUnit: 'ml',
                vMaxVal: 3,
                vCounter: _trinken,
                onTap: () => _updateValue('trinken', _trinken),
              ),

              // 3. Kalorien (Spalte: kalorien)
              TrackingElement(
                vColor: const Color(0xFF66BA18),
                vIconData: Icons.fastfood,
                vUnit: 'kcal',
                vMaxVal: 1800.0,
                vCounter: _kalorien,
                onTap: () => _updateValue('kalorien', _kalorien),
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
