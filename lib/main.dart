import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'discover_page.dart';
import 'friends_page.dart';
import 'requests_page.dart';
import 'shelf_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DiscoverPage(),
      const ShelfPage(),
      const RequestsPage(),
      const FriendsPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spielregal'),
        actions: [
          IconButton(
            tooltip: 'Abmelden',
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Entdecken'),
          NavigationDestination(icon: Icon(Icons.shelves), label: 'Mein Regal'),
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Anfragen'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Freunde'),
        ],
      ),
    );
  }
}
