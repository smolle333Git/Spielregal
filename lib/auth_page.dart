import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'scan_page.dart';
import 'shelf_page.dart' show genres;

class AddGamePage extends StatefulWidget {
  const AddGamePage({super.key});

  @override
  State<AddGamePage> createState() => _AddGamePageState();
}

class _AddGamePageState extends State<AddGamePage> {
  final _db = Supabase.instance.client;
  final _search = TextEditingController();
  final _title = TextEditingController();
  final _age = TextEditingController(text: '8');
  final _minP = TextEditingController(text: '2');
  final _maxP = TextEditingController(text: '4');
  final _mins = TextEditingController(text: '45');
  String _genre = genres.first;
  String? _ean;
  int? _bgg;
  String? _image;
  bool _fromCatalog = false;
  List<Map<String, dynamic>> _hits = [];

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _fill(Map<String, dynamic> c) {
    setState(() {
      _title.text = c['title'] as String;
      _age.text = '${c['min_age'] ?? ''}';
      _minP.text = '${c['min_players'] ?? ''}';
      _maxP.text = '${c['max_players'] ?? ''}';
      _mins.text = '${c['play_minutes'] ?? ''}';
      _genre = genres.contains(c['genre']) ? c['genre'] as String : genres.first;
      _ean = c['ean'] as String? ?? _ean;
      _bgg = c['bgg_id'] as int?;
      _image = c['image_url'] as String?;
      _fromCatalog = true;
      _hits = [];
    });
  }

  Future<void> _doSearch(String q) async {
    final text = q.trim().replaceAll(RegExp(r'[%_]'), '');
    if (text.length < 2) {
      setState(() => _hits = []);
      return;
    }
    try {
      final rows =
          await _db.from('catalog').select().ilike('title', '%$text%').limit(8);
      if (mounted) setState(() => _hits = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      _snack('Die Suche hat nicht geklappt.');
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const ScanPage()));
    if (code == null) return;
    try {
      final c = await _db.from('catalog').select().eq('ean', code).maybeSingle();
      if (c != null) {
        _fill(c);
        _snack('Spiel erkannt: ${c['title']}');
      } else {
        setState(() {
          _ean = code;
          _fromCatalog = false;
        });
        _snack('Code noch unbekannt. Trage die Daten ein, dann kennt ihn die App künftig.');
      }
    } catch (_) {
      _snack('Der Code konnte nicht geprüft werden.');
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _snack('Bitte einen Titel eingeben.');
      return;
    }
    final a = int.tryParse(_minP.text) ?? 1;
    final b = int.tryParse(_maxP.text) ?? a;
    final data = {
      'title': title,
      'ean': _ean,
      'bgg_id': _bgg,
      'image_url': _image,
      'min_age': int.tryParse(_age.text),
      'min_players': a,
      'max_players': b < a ? a : b,
      'play_minutes': int.tryParse(_mins.text),
      'genre': _genre,
    };
    try {
      await _db
          .from('shelf_items')
          .insert({...data, 'owner_id': _db.auth.currentUser!.id});
      // Unbekannten Barcode für alle ergänzen (Fehler sind unkritisch).
      if (!_fromCatalog) {
        try {
          await _db
              .from('catalog')
              .insert({...data, 'created_by': _db.auth.currentUser!.id});
        } catch (_) {}
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      _snack('Speichern hat nicht geklappt.');
    }
  }

  Widget _num(TextEditingController c, String label) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder(), isDense: true),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spiel hinzufügen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Barcode scannen')),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            onChanged: _doSearch,
            decoration: const InputDecoration(
              labelText: 'In der Spieledatenbank suchen',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          if (_search.text.trim().length >= 2 && _hits.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                  'Nichts gefunden. Trage das Spiel unten von Hand ein, dann ist es für alle in der Datenbank.'),
            ),
          for (final h in _hits)
            Card(
              child: ListTile(
                title: Text(h['title'] as String),
                subtitle: Text(
                    'ab ${h['min_age'] ?? '?'} J. · ${h['min_players']}–${h['max_players']} Spieler · ${h['play_minutes'] ?? '?'} Min.'),
                onTap: () => _fill(h),
              ),
            ),
          const Divider(height: 32),
          if (_image != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: Image.network(_image!,
                    height: 140,
                    errorBuilder: (_, __, ___) => const Icon(Icons.casino, size: 64)),
              ),
            ),
          TextField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Titel', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(children: [
            _num(_age, 'Alter ab'),
            const SizedBox(width: 8),
            _num(_mins, 'Minuten'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _num(_minP, 'Spieler von'),
            const SizedBox(width: 8),
            _num(_maxP, 'Spieler bis'),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _genre,
            decoration: const InputDecoration(
                labelText: 'Genre', border: OutlineInputBorder()),
            items: genres
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => _genre = v ?? _genre),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Zum Regal hinzufügen')),
          ),
        ],
      ),
    );
  }
}
