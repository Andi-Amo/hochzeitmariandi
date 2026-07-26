import 'package:flutter/material.dart';
import '../../models/program_item.dart';
import '../../services/program_repository.dart';

/// Admin overview screen to view and manage all submitted program items
/// (speeches, slideshows, games, etc.) submitted by guests.
class AdminProgramOverviewScreen extends StatefulWidget {
  const AdminProgramOverviewScreen({super.key});

  @override
  State<AdminProgramOverviewScreen> createState() =>
      _AdminProgramOverviewScreenState();
}

class _AdminProgramOverviewScreenState
    extends State<AdminProgramOverviewScreen> {
  final ProgramRepository _repository = ProgramRepository();

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'rede':
        return Icons.record_voice_over;
      case 'diashow':
        return Icons.slideshow;
      default:
        return Icons.celebration;
    }
  }

  Future<void> _confirmDelete(BuildContext context, ProgramItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Programmpunkt löschen?'),
        content: Text(
          'Möchtest du den Beitrag von "${item.guestName}" wirklich löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.deleteItem(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Programmpunkte Overview'),
      ),
      body: StreamBuilder<List<ProgramItem>>(
        stream: _repository.watchAllItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Fehler beim Laden der Programmpunkte: ${snapshot.error}',
              ),
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Noch keine Reden oder Beiträge angemeldet. 🎉',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(_getTypeIcon(item.type)),
                  ),
                  title: Text(
                    '${item.guestName} (${item.type})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(item.description),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Theme.of(context).colorScheme.error,
                    tooltip: 'Löschen',
                    onPressed: () => _confirmDelete(context, item),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}