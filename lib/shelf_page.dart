import 'package:flutter/material.dart';

const List<String> genres = [
  'Familie',
  'Strategie',
  'Party',
  'Kartenspiel',
  'Kooperativ',
  'Kinderspiel',
  'Wirtschaft',
  'Fantasy',
];

class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key});

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  final List<Map<String, dynamic>> games = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: games.isEmpty
          ? const Center(
              child: Text(
                'Noch keine Spiele im Regal',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.casino),
                    title: Text(game['title'] ?? 'Unbekanntes Spiel'),
                    subtitle: Text(
                      '${game['min_players'] ?? '?'} - '
                      '${game['max_players'] ?? '?'} Spieler',
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}