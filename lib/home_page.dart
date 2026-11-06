import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _db = Supabase.instance.client;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _hits = [];
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
    final rows = await _db.from('friendships').select(
        '*, requester:profiles!friendships_user_id_fkey(username), '
        'friend:profiles!friendships_friend_id_fkey(username)');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _find(String q) async {
    final text = q.trim().replaceAll(RegExp(r'[%_]'), '');
    if (text.length < 2) {
      setState(() => _hits = []);
      return;
    }
    try {
      final rows = await _db
          .from('profiles')
          .select('id, username')
          .ilike('username', '%$text%')
          .neq('id', _uid)
          .limit(10);
      if (mounted) setState(() => _hits = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      _snack('Die Suche hat nicht geklappt.');
    }
  }

  Future<void> _invite(Map<String, dynamic> p) async {
    try {
      await _db
          .from('friendships')
          .insert({'user_id': _uid, 'friend_id': p['id']});
      _snack('Freundschaftsanfrage gesendet.');
      setState(() {
        _hits = [];
        _search.clear();
      });
      _reload();
    } catch (_) {
      _snack('Die Anfrage existiert schon oder hat nicht geklappt.');
    }
  }

  Future<void> _accept(Map<String, dynamic> f) async {
    try {
      await _db
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('user_id', f['user_id'])
          .eq('friend_id', _uid);
    } catch (_) {
      _snack('Das hat nicht geklappt.');
    }
    _reload();
  }

  Future<void> _remove(Map<String, dynamic> f) async {
    try {
      await _db
          .from('friendships')
          .delete()
          .eq('user_id', f['user_id'])
          .eq('friend_id', f['friend_id']);
    } catch (_) {
      _snack('Das hat nicht geklappt.');
    }
    _reload();
  }

  String _name(Map<String, dynamic> f) => f['user_id'] == _uid
      ? (f['friend']?['username'] ?? '?') as String
      : (f['requester']?['username'] ?? '?') as String;

  Widget _section(String title, List<Widget> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ...items,
        ],
      );

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _search,
            onChanged: _find,
            decoration: const InputDecoration(
              labelText: 'Nutzer per Spitzname suchen',
              prefixIcon: Icon(Icons.person_search),
              border: OutlineInputBorder(),
            ),
          ),
          for (final p in _hits)
            Card(
              child: ListTile(
                title: Text(p['username'] as String),
                trailing: FilledButton(
                    onPressed: () => _invite(p), child: const Text('Hinzufügen')),
              ),
            ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _rows,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()));
              }
              if (snap.hasError) {
                return const Text('Die Freunde konnten nicht geladen werden.');
              }
              final all = snap.data!;
              final friends = all.where((f) => f['status'] == 'accepted').toList();
              final incoming = all
                  .where((f) => f['status'] == 'pending' && f['friend_id'] == _uid)
                  .toList();
              final outgoing = all
                  .where((f) => f['status'] == 'pending' && f['user_id'] == _uid)
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (incoming.isNotEmpty)
                    _section('Anfragen an dich', [
                      for (final f in incoming)
                        Card(
                          child: ListTile(
                            title: Text(_name(f)),
                            trailing: Wrap(spacing: 8, children: [
                              FilledButton(
                                  onPressed: () => _accept(f),
                                  child: const Text('Annehmen')),
                              OutlinedButton(
                                  onPressed: () => _remove(f),
                                  child: const Text('Ablehnen')),
                            ]),
                          ),
                        ),
                    ]),
                  _section('Meine Freunde (${friends.length})', [
                    if (friends.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                              'Noch keine Freunde. Suche oben nach dem Spitznamen.')),
                    for (final f in friends)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(_name(f)),
                          trailing: IconButton(
                            tooltip: 'Freundschaft beenden',
                            icon: const Icon(Icons.person_remove),
                            onPressed: () => _remove(f),
                          ),
                        ),
                      ),
                  ]),
                  if (outgoing.isNotEmpty)
                    _section('Gesendet, wartet auf Antwort', [
                      for (final f in outgoing)
                        Card(
                          child: ListTile(
                            title: Text(_name(f)),
                            trailing: TextButton(
                                onPressed: () => _remove(f),
                                child: const Text('Zurückziehen')),
                          ),
                        ),
                    ]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
