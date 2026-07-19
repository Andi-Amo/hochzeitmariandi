import 'package:flutter/material.dart';

import '../../models/guest.dart';
import '../../services/guest_repository.dart';

/// Admin screen to view/edit the guest list: table/seat assignment,
/// the "usual cake suspect" flag, and RSVP status. Guests can be added one
/// by one, or bulk-imported by pasting CSV text (see [_showCsvImportDialog]).
class AdminGuestListScreen extends StatefulWidget {
  const AdminGuestListScreen({super.key});

  @override
  State<AdminGuestListScreen> createState() => _AdminGuestListScreenState();
}

class _AdminGuestListScreenState extends State<AdminGuestListScreen> {
  final GuestRepository _repository = GuestRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gästeliste'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'CSV importieren',
            onPressed: () => _showCsvImportDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, null),
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<List<Guest>>(
        stream: _repository.watchAllGuests(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final guests = snapshot.data!
            ..sort((a, b) => a.fullName.compareTo(b.fullName));
          if (guests.isEmpty) {
            return const Center(child: Text('Noch keine Gäste angelegt.'));
          }
          return ListView.builder(
            itemCount: guests.length,
            itemBuilder: (context, index) {
              final g = guests[index];
              return ListTile(
                leading: g.isUsualCakeSuspect
                    ? const Icon(Icons.cake, color: Colors.brown)
                    : const Icon(Icons.person_outline),
                title: Text(g.fullName),
                subtitle: Text(
                  'Tisch: ${g.tableId ?? '-'} · Platz: ${g.seat ?? '-'} · RSVP: ${g.rsvpStatus}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditDialog(context, g),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, Guest? existing) async {
    final firstNameController = TextEditingController(text: existing?.firstName ?? '');
    final lastNameController = TextEditingController(text: existing?.lastName ?? '');
    final tableController = TextEditingController(text: existing?.tableId ?? '');
    final seatController = TextEditingController(text: existing?.seat ?? '');
    bool isCakeSuspect = existing?.isUsualCakeSuspect ?? false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Gast hinzufügen' : 'Gast bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: 'Vorname'),
                ),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'Nachname'),
                ),
                TextField(
                  controller: tableController,
                  decoration: const InputDecoration(labelText: 'Tisch'),
                ),
                TextField(
                  controller: seatController,
                  decoration: const InputDecoration(labelText: 'Sitzplatz'),
                ),
                CheckboxListTile(
                  title: const Text('Üblicher Kuchen-Verdächtiger'),
                  value: isCakeSuspect,
                  onChanged: (v) => setDialogState(() => isCakeSuspect = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await _repository.deleteGuest(existing.id);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Löschen'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                final guest = Guest(
                  id: existing?.id ?? '',
                  firstName: firstNameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                  tableId: tableController.text.trim().isEmpty ? null : tableController.text.trim(),
                  seat: seatController.text.trim().isEmpty ? null : seatController.text.trim(),
                  isUsualCakeSuspect: isCakeSuspect,
                  rsvpStatus: existing?.rsvpStatus ?? 'pending',
                  plusOnes: existing?.plusOnes ?? 0,
                  dietaryNotes: existing?.dietaryNotes,
                );
                if (existing == null) {
                  await _repository.addGuest(guest);
                } else {
                  await _repository.updateGuest(guest);
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  /// Bulk-imports guests from pasted CSV text. Expected columns (header
  /// row required, order doesn't matter):
  ///   firstName,lastName,tableId,seat,isUsualCakeSuspect
  /// `isUsualCakeSuspect` accepts true/false/1/0/ja/nein (case-insensitive).
  Future<void> _showCsvImportDialog(BuildContext context) async {
    final csvController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Gästeliste per CSV importieren'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Spaltenkopf: firstName,lastName,tableId,seat,isUsualCakeSuspect\n'
                  'Beispiel:\n'
                  'firstName,lastName,tableId,seat,isUsualCakeSuspect\n'
                  'Anna,Muster,1,A1,true',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: csvController,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: 'CSV-Inhalt hier einfügen...',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final guests = _parseCsv(csvController.text);
                  for (final guest in guests) {
                    await _repository.addGuest(guest);
                  }
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${guests.length} Gäste importiert.')),
                    );
                  }
                } catch (e) {
                  setDialogState(() => error = 'Fehler beim Import: $e');
                }
              },
              child: const Text('Importieren'),
            ),
          ],
        ),
      ),
    );
  }

  List<Guest> _parseCsv(String csvText) {
    final lines = csvText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return [];

    final header = lines.first.split(',').map((h) => h.trim()).toList();
    final guests = <Guest>[];

    for (final line in lines.skip(1)) {
      final values = line.split(',').map((v) => v.trim()).toList();
      final row = <String, String>{};
      for (var i = 0; i < header.length && i < values.length; i++) {
        row[header[i]] = values[i];
      }

      final firstName = row['firstName'] ?? '';
      final lastName = row['lastName'] ?? '';
      if (firstName.isEmpty && lastName.isEmpty) continue;

      final cakeFlagRaw = (row['isUsualCakeSuspect'] ?? '').toLowerCase();
      final isCakeSuspect = ['true', '1', 'ja', 'yes'].contains(cakeFlagRaw);

      guests.add(
        Guest(
          id: '',
          firstName: firstName,
          lastName: lastName,
          tableId: (row['tableId'] ?? '').isEmpty ? null : row['tableId'],
          seat: (row['seat'] ?? '').isEmpty ? null : row['seat'],
          isUsualCakeSuspect: isCakeSuspect,
        ),
      );
    }
    return guests;
  }
}
