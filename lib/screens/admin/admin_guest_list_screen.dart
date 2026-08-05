import 'package:flutter/material.dart';

import '../../models/guest.dart';
import '../../widgets/home_back_button.dart';
import '../../services/guest_repository.dart';

/// Admin screen to view/edit the guest list: table/seat assignment,
/// household/group grouping, the "usual cake suspect" flag, and RSVP status.
class AdminGuestListScreen extends StatefulWidget {
  const AdminGuestListScreen({super.key});

  @override
  State<AdminGuestListScreen> createState() => _AdminGuestListScreenState();
}

class _AdminGuestListScreenState extends State<AdminGuestListScreen> {
  final GuestRepository _repository = GuestRepository();

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          leading: const HomeBackButton(),
          title: const Text('Gästeliste'),
          actions: [
            IconButton(
              icon: const Icon(Icons.storage),
              tooltip: 'groupId zu alten Einträgen hinzufügen',
              onPressed: () => _runGroupIdMigration(context),
            ),
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
                    'Gruppe: ${g.groupId ?? '-'} · Tisch: ${g.tableId ?? '-'} · Platz: ${g.seat ?? '-'} · RSVP: ${g.rsvpStatus} · '
                    '${g.isChild ? 'Kind${g.childAge != null ? ' (${g.childAge} J.)' : ''}' : 'Erwachsener'}',
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
      ),
    );
  }

  /// One-time Migration helper to add missing `groupId` fields to Firestore docs.
  Future<void> _runGroupIdMigration(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datenbank aktualisieren'),
        content: const Text(
          'Möchtest du allen vorhandenen Gästen in Firestore das Feld "groupId" hinzufügen (falls noch nicht vorhanden)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Aktualisieren'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await _repository.backfillGroupIdToAllGuests();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Alle Einträge in Firestore wurden aktualisiert!'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Aktualisieren: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditDialog(BuildContext context, Guest? existing) async {
    final firstNameController = TextEditingController(
      text: existing?.firstName ?? '',
    );
    final lastNameController = TextEditingController(
      text: existing?.lastName ?? '',
    );
    final groupIdController = TextEditingController(
      text: existing?.groupId ?? '',
    );
    final tableController = TextEditingController(
      text: existing?.tableId ?? '',
    );
    final seatController = TextEditingController(text: existing?.seat ?? '');
    final childAgeController = TextEditingController(
      text: existing?.childAge != null ? '${existing!.childAge}' : '',
    );
    bool isCakeSuspect = existing?.isUsualCakeSuspect ?? false;
    bool isChild = existing?.isChild ?? false;

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
                  controller: groupIdController,
                  decoration: const InputDecoration(
                    labelText: 'Gruppe / Familien-ID',
                    hintText: 'z.B. familie-muster oder schmidts',
                  ),
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
                  onChanged: (v) =>
                      setDialogState(() => isCakeSuspect = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Kind (statt Erwachsener)'),
                  value: isChild,
                  onChanged: (v) => setDialogState(() => isChild = v ?? false),
                ),
                if (isChild)
                  TextField(
                    controller: childAgeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Alter des Kindes',
                    ),
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
                final groupVal = groupIdController.text.trim();
                final guest = Guest(
                  id: existing?.id ?? '',
                  firstName: firstNameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                  groupId: groupVal.isEmpty ? null : groupVal,
                  tableId: tableController.text.trim().isEmpty
                      ? null
                      : tableController.text.trim(),
                  seat: seatController.text.trim().isEmpty
                      ? null
                      : seatController.text.trim(),
                  isUsualCakeSuspect: isCakeSuspect,
                  isChild: isChild,
                  childAge: isChild
                      ? int.tryParse(childAgeController.text.trim())
                      : null,
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

  /// Bulk-imports guests from pasted CSV text. Expected columns:
  /// firstName,lastName,groupId,tableId,seat,isUsualCakeSuspect,isChild,childAge
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
                  'Spaltenkopf: firstName,lastName,groupId,tableId,seat,isUsualCakeSuspect,isChild,childAge\n'
                  'Beispiel:\n'
                  'firstName,lastName,groupId,tableId,seat,isUsualCakeSuspect,isChild,childAge\n'
                  'Anna,Muster,muster-familie,1,A1,true,false,\n'
                  'Lina,Muster,muster-familie,1,A2,false,true,7\n'
                  '(groupId, isChild und childAge sind optional)',
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
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
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
                      SnackBar(
                        content: Text('${guests.length} Gäste importiert.'),
                      ),
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

      final groupId = row['groupId'] ?? '';
      final cakeFlagRaw = (row['isUsualCakeSuspect'] ?? '').toLowerCase();
      final isCakeSuspect = ['true', '1', 'ja', 'yes'].contains(cakeFlagRaw);

      final childFlagRaw = (row['isChild'] ?? '').toLowerCase();
      final isChild = ['true', '1', 'ja', 'yes'].contains(childFlagRaw);
      final childAge = isChild ? int.tryParse(row['childAge'] ?? '') : null;

      guests.add(
        Guest(
          id: '',
          firstName: firstName,
          lastName: lastName,
          groupId: groupId.isEmpty ? null : groupId,
          tableId: (row['tableId'] ?? '').isEmpty ? null : row['tableId'],
          seat: (row['seat'] ?? '').isEmpty ? null : row['seat'],
          isUsualCakeSuspect: isCakeSuspect,
          isChild: isChild,
          childAge: childAge,
        ),
      );
    }
    return guests;
  }
}
