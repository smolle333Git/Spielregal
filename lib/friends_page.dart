import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'shelf_page.dart' show genres;

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _db = Supabase.instance.client;
  double _radius = 25;
  String _q = '';
  String? _genre;
  int? _players;
  int? _age;
  int? _mins;
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  bool _noLocation = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await _db
          .from('profile_locations')
          .select('user_id')
          .eq('user_id', _db.auth.currentUser!.id)
          .maybeSingle();
      if (me == null) {
        _noLocation = true;
        _all = [];
      } else {
        _noLocation = false;
        final rows =
            await _db.rpc('nearby_items', params: {'radius_km': _radius});
        _all = List<Map<String, dynamic>>.from(rows as List);
      }
    } catch (_) {
      _error = 'Die Spiele konnten nicht geladen werden.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _snack('Standortzugriff nicht erlaubt. Bitte in den Einstellungen freigeben.');
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
      await _db.rpc('set_my_location',
          params: {'lat': pos.latitude, 'lng': pos.longitude});
      _snack('Standort gespeichert (auf ca. 1 km gerundet).');
      _load();
    } catch (_) {
      _snack('Der Standort konnte nicht bestimmt werden.');
    }
  }

  List<Map<String, dynamic>> get _filtered => _all.where((i) {
        if (_q.isNotEmpty &&
            !(i['title'] as String).toLowerCase().contains(_q.toLowerCase())) {
          return false;
        }
        if (_genre != null && i['genre'] != _genre) return false;
        if (_players != null) {
          final a = i['min_players'] as int?;
          final b = i['max_players'] as int?;
          if (a == null || b == null || _players! < a || _players! > b) return false;
        }
        if (_age != null && ((i['min_age'] as int?) ?? 99) > _age!) return false;
        if (_mins != null && ((i['play_minutes'] as int?) ?? 9999) > _mins!) {
          return false;
        }
        return true;
      }).toList();

  Future<void> _ask(Map<String, dynamic> it) async {
    String kind = 'lend';
    final msg = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(it['title'] as String),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'lend', label: Text('Ausleihen')),
                ButtonSegment(value: 'play', label: Text('Mitspielen')),
              ],
              selected: {kind},
              onSelectionChanged: (s) => setD(() => kind = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msg,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Nachricht', border: OutlineInputBorder()),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Anfrage senden')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _db.from('requests').insert({
        'item_id': it['id'],
        'requester_id': _db.auth.currentUser!.id,
        'owner_id': it['owner_id'],
        'kind': kind,
        'message': msg.text.trim(),
      });
      _snack('Anfrage gesendet');
    } catch (_) {
      _snack('Die Anfrage konnte nicht gesendet werden.');
    }
  }

  Widget _dd<T>(String label, T? v, List<T> opts, String Function(T) f,
          ValueChanged<T?> on) =>
      SizedBox(
        width: 150,
        child: DropdownButtonFormField<T?>(
          value: v,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder(), isDense: true),
          items: [
            const DropdownMenuItem(value: null, child: Text('Egal')),
            ...opts.map((o) => DropdownMenuItem<T?>(value: o, child: Text(f(o)))),
          ],
          onChanged: (x) => setState(() => on(x)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_noLocation)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'Für die Umkreissuche brauchen wir deinen Standort. Andere sehen nur eine grobe Entfernung, nie deine Adresse.'),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _setLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Standort bestimmen'),
                    ),
                  ],
                ),
              ),
            ),
          TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
                labelText: 'Spiel suchen',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _dd<String>('Genre', _genre, genres, (g) => g, (x) => _genre = x),
            _dd<int>('Spieler', _players, [1, 2, 3, 4, 5, 6, 7, 8], (n) => '$n',
                (x) => _players = x),
            _dd<int>('Alter bis', _age, [6, 8, 10, 12], (n) => '$n J.',
                (x) => _age = x),
            _dd<int>('Dauer bis', _mins, [30, 60, 90], (n) => '$n Min.',
                (x) => _mins = x),
          ]),
          const SizedBox(height: 8),
          Text('Umkreis: ${_radius.round()} km'),
          Slider(
            value: _radius,
            min: 1,
            max: 50,
            divisions: 49,
            onChanged: (v) => setState(() => _radius = v),
            onChangeEnd: (_) => _load(),
          ),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Text(_error!)
          else if (!_noLocation && items.isEmpty)
            const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child: Text(
                        'Keine Spiele gefunden. Vergrößere den Umkreis oder lockere die Filter.')))
          else
            for (final it in items)
              Card(
                child: ListTile(
                  title: Text(it['title'] as String),
                  subtitle: Text(
                      'ab ${it['min_age'] ?? '?'} J. · ${it['min_players']}–${it['max_players']} Spieler · ${it['play_minutes'] ?? '?'} Min.\n${it['owner_name']}${it['owner_rating'] != null ? ' (★ ${it['owner_rating']}, ${it['owner_ratings']})' : ''} · ca. ${it['distance_km']} km · ${(it['available'] as bool) ? 'Verfügbar' : 'Verliehen'}'),
                  isThreeLine: true,
                  trailing: FilledButton(
                    onPressed: () => _ask(it),
                    child: Text((it['available'] as bool) ? 'Anfragen' : 'Vormerken'),
                  ),
                ),
              ),
          if (!_noLocation)
            TextButton.icon(
              onPressed: _setLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Standort aktualisieren'),
            ),
        ],
      ),
    );
  }
}
