import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';

/// Admin dashboard: entry point to guest list management, seating plan,
/// cake/program overview, and photo curation.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin-Bereich'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: () async {
              await AuthService().signOutAdmin();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Gästeliste verwalten'),
              subtitle: const Text('Gäste, Tische, Sitzplätze, RSVP-Status'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/admin/guests'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.mic_none_outlined),
              title: const Text('Programmpunkte & Reden'),
              subtitle: const Text('Angemeldete Reden, Diashows & Beiträge'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/admin/program'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Fotos kuratieren'),
              subtitle: const Text('Fotos ausblenden oder löschen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/admin/photos'),
            ),
          ),
        ],
      ),
    );
  }
}