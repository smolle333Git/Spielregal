import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  final _db = Supabase.instance.client;
  bool _incoming = true;
  Set<String> _rated = {};
  late Future<List<Map<String, dynamic>>> _rows;

  String get _uid => _db.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _rows = _load();
  }

  void _reload() {
    setState(() {
      _rows = _load();
    });
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _db
        .from('requests')
        .select('*, item:shelf_items(title), '
            'requester:profiles!requests_requester_id_fkey(username), '
            'owner:profiles!requests_owner_id_fkey(username)')
        .order('created_at', ascending: false);
    final mine = await _db.from('ratings').select('request_id').eq('rater_id', _uid);
    _rated = {for (final r in mine) r['request_id'] as String};
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _accept(Map<String, dynamic> r) async {
    final reply = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anfrage zusagen'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: reply,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Nachricht (z. B. Treffpunkt und Zeit)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          const Text(
              'Tipp: Triff dich für die Übergabe an einem öffentlichen Ort und gib deine Adresse nicht ungefragt weiter.',
              style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Zusagen')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db
          .from('requests')
          .update({'status': 'accepted', 'reply': reply.text.trim()}).eq('id', r['id']);
      if (r['kind'] == 'lend') {
        await _db
            .from('shelf_items')
            .update({'available': false}).eq('id', r['item_id']);
      }
    } catch (_) {
      _snack('Das hat nicht geklappt.');
    }
    _reload();
  }

  Future<void> _setStatus(Map<String, dynamic> r, String status,
      {bool? available}) async {
    try {
      await _db.from('requests').update({'status': status}).eq('id', r['id']);
      if (available != null && r['kind'] == 'lend') {
        await _db
            .from('shelf_items')
            .update({'available': available}).eq('id', r['item_id']);
      }
    } catch (_) {
      _snack('Das hat nicht geklappt.');
    }
    _reload();
  }

  Future<void> _rate(Map<String, dynamic> r) async {
    int stars = 0;
    final comment = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Hat es gut geklappt?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var n = 1; n <= 5; n++)
                IconButton(
                  tooltip: '$n Sterne',
                  icon: Icon(n <= stars ? Icons.star : Icons.star_border,
                      color: Colors.amber, size: 32),
                  onPressed: () => setD(() => stars = n),
                ),
            ]),
            TextField(
              controller: comment,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Kommentar (optional)', border: OutlineInputBorder()),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Später')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Bewertung senden')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (stars == 0) {
      _snack('Bitte Sterne wählen.');
      return;
    }
    final other = r['owner_id'] == _uid ? r['requester_id'] : r['owner_id'];
    try {
      await _db.from('ratings').insert({
        'request_id': r['id'],
        'rater_id': _uid,
        'rated_id': other,
        'stars': stars,
        'comment': comment.text.trim(),
      });
      _snack('Danke für deine Bewertung.');
    } catch (_) {
      _snack('Die Bewertung konnte nicht gespeichert werden.');
    }
    _reload();
  }

  static const _status = {
    'open': 'Wartet auf Antwort',
    'accepted': 'Zugesagt',
    'declined': 'Abgelehnt',
    'done': 'Abgeschlossen',
  };

  Widget _card(Map<String, dynamic> r) {
    final isOwner = r['owner_id'] == _uid;
    final item = r['item'] as Map<String, dynamic>?;
    final title = item?['title'] ?? 'Spiel nicht mehr sichtbar';
    final who = isOwner
        ? (r['requester']?['username'] ?? '?')
        : (r['owner']?['username'] ?? '?');
    final kind = r['kind'] == 'lend' ? 'Ausleihen' : 'Mitspielen';
    final status = r['status'] as String;
    final message = (r['message'] as String?) ?? '';
    final reply = (r['reply'] as String?) ?? '';
    final rated = _rated.contains(r['id']);

    final actions = <Widget>[];
    if (isOwner && status == 'open') {
      actions.addAll([
        FilledButton(onPressed: () => _accept(r), child: const Text('Zusagen')),
        OutlinedButton(
            onPressed: () => _setStatus(r, 'declined'),
            child: const Text('Ablehnen')),
      ]);
    }
    if (isOwner && status == 'accepted') {
      actions.add(FilledButton(
        onPressed: () => _setStatus(r, 'done', available: true),
        child: Text(r['kind'] == 'lend'
            ? 'Spiel ist zurück, abschließen'
            : 'Gespielt, abschließen'),
      ));
    }
    if (status == 'done' && !rated) {
      actions.add(FilledButton(
          onPressed: () => _rate(r), child: const Text('Bewerten')));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(title as String,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
            Chip(label: Text(_status[status] ?? status)),
          ]),
          Text('$kind · ${isOwner ? 'von' : 'bei'} $who'),
          if (message.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Nachricht: $message'),
          ),
          if (reply.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Antwort: $reply'),
          ),
          if (!isOwner && status == 'accepted')
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                  'Hinweis: Nach dem Spielen oder der Rückgabe schließt der Besitzer die Anfrage ab. Danach könnt ihr euch bewerten.',
                  style: TextStyle(fontSize: 12)),
            ),
          if (status == 'done' && rated)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Du hast bewertet.', style: TextStyle(fontSize: 12)),
            ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(spacing: 8, runSpacing: 8, children: actions),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _rows,
        builder: (context, snap) {
          final children = <Widget>[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Erhalten')),
                ButtonSegment(value: false, label: Text('Gesendet')),
              ],
              selected: {_incoming},
              onSelectionChanged: (s) => setState(() => _incoming = s.first),
            ),
            const SizedBox(height: 12),
          ];
          if (snap.connectionState != ConnectionState.done) {
            children.add(const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator())));
          } else if (snap.hasError) {
            children.add(const Text('Die Anfragen konnten nicht geladen werden.'));
          } else {
            final list = snap.data!
                .where((r) => _incoming ? r['owner_id'] == _uid : r['requester_id'] == _uid)
                .toList();
            if (list.isEmpty) {
              children.add(Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                      child: Text(_incoming
                          ? 'Noch keine Anfragen an dich.'
                          : 'Du hast noch keine Anfrage gesendet.'))));
            } else {
              children.addAll(list.map(_card));
            }
          }
          return ListView(padding: const EdgeInsets.all(16), children: children);
        },
      ),
    );
  }
}
