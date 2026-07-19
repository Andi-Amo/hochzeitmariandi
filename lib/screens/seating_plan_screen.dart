import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/guest.dart';
import '../services/guest_repository.dart';
import '../services/guest_session.dart';
import '../widgets/guest_name_search.dart';

/// The "hidden" seating plan: only reachable after the guest identifies
/// themselves. Shows all tables, highlighting the guest's own table/seat.
class SeatingPlanScreen extends StatelessWidget {
  const SeatingPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final guest = context.watch<GuestSession>().guest;

    return Scaffold(
      appBar: AppBar(title: const Text('Sitzplan')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: guest == null
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Der Sitzplan ist nur für eingeladene Gäste sichtbar. '
                      'Bitte gib deinen Namen ein.',
                    ),
                    const SizedBox(height: 16),
                    const GuestNameSearch(),
                  ],
                ),
              )
            : _SeatingPlanBody(currentGuest: guest),
      ),
    );
  }
}

class _SeatingPlanBody extends StatelessWidget {
  final Guest currentGuest;

  const _SeatingPlanBody({required this.currentGuest});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Guest>>(
      stream: GuestRepository().watchAllGuests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final guests = snapshot.data!;
        final Map<String, List<Guest>> byTable = {};
        for (final g in guests) {
          final table = g.tableId ?? 'Nicht zugeordnet';
          byTable.putIfAbsent(table, () => []).add(g);
        }
        final tableIds = byTable.keys.toList()..sort();

        return ListView(
          children: [
            Text(
              'Hallo ${currentGuest.fullName}, dein Tisch ist hervorgehoben.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            for (final tableId in tableIds)
              _TableCard(
                tableId: tableId,
                guests: byTable[tableId]!,
                currentGuestId: currentGuest.id,
              ),
          ],
        );
      },
    );
  }
}

class _TableCard extends StatelessWidget {
  final String tableId;
  final List<Guest> guests;
  final String currentGuestId;

  const _TableCard({
    required this.tableId,
    required this.guests,
    required this.currentGuestId,
  });

  @override
  Widget build(BuildContext context) {
    final isMyTable = guests.any((g) => g.id == currentGuestId);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: isMyTable ? colorScheme.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isMyTable
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tisch $tableId',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: guests.map((g) {
                final isMe = g.id == currentGuestId;
                return Chip(
                  avatar: isMe ? const Icon(Icons.star, size: 18) : null,
                  label: Text(g.fullName + (g.seat != null ? ' (${g.seat})' : '')),
                  backgroundColor: isMe ? colorScheme.primary : null,
                  labelStyle: isMe ? TextStyle(color: colorScheme.onPrimary) : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
