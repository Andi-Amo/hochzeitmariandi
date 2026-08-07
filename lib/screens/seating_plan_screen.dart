import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/js_interop.dart';

import '../widgets/home_back_button.dart';
import '../widgets/back_button_widget.dart';

import '../models/guest.dart';
import '../services/auth_service.dart';
import '../services/guest_repository.dart';
import '../services/guest_session.dart';
import '../services/wedding_config.dart';
import '../widgets/guest_name_search.dart';

/// The "hidden" seating plan: only reachable after the guest identifies
/// themselves, and only once [WeddingConfig.seatingPlanUnlockTime] has
/// passed (stays locked with a countdown until then). Admins (logged in
/// via email/password) can preview it early.
class SeatingPlanScreen extends StatefulWidget {
  const SeatingPlanScreen({super.key});

  @override
  State<SeatingPlanScreen> createState() => _SeatingPlanScreenState();
}

class _SeatingPlanScreenState extends State<SeatingPlanScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Re-check the unlock time once a second so the countdown updates and
    // the plan reveals itself automatically at the unlock moment, without
    // requiring the guest to refresh the page.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guest = context.watch<GuestSession>().guest;
    final now = DateTime.now();
    final isUnlocked =
        !now.isBefore(WeddingConfig.seatingPlanUnlockTime) ||
        AuthService().isAdmin;

    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          leading: const HomeBackButton(),
          title: const Text('Sitzplan'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: !isUnlocked
                    ? _LockedCountdown(
                        unlockTime: WeddingConfig.seatingPlanUnlockTime,
                        now: now,
                      )
                    : guest == null
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
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: const BackButtonWidget(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedCountdown extends StatefulWidget {
  final DateTime unlockTime;
  final DateTime now;

  const _LockedCountdown({required this.unlockTime, required this.now});

  @override
  State<_LockedCountdown> createState() => _LockedCountdownState();
}

class _LockedCountdownState extends State<_LockedCountdown> {
  @override
  void initState() {
    super.initState();
    _playCountdownSound();
  }

  @override
  void dispose() {
    _stopCountdownSound();
    super.dispose();
  }

  void _playCountdownSound() {
    try {
      callJsMethod('playCountdownSoundLoop', []);
    } catch (e) {
      print('Countdown sound error: $e');
    }
  }

  void _stopCountdownSound() {
    try {
      callJsMethod('stopCountdownSound', []);
    } catch (e) {
      print('Countdown sound stop error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.unlockTime.difference(widget.now);
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_clock_outlined, size: 48),
          const SizedBox(height: 16),
          Text(
            'Der Sitzplan wird erst am Hochzeitstag freigeschaltet.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (!remaining.isNegative)
            Text(
              'Noch $days Tage, $hours Std. $minutes Min. $seconds Sek.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
        ],
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
        final guests = snapshot.data!
            .where((g) => g.rsvpStatus == 'attending')
            .toList();
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
                  label: Text(
                    g.fullName + (g.seat != null ? ' (${g.seat})' : ''),
                  ),
                  backgroundColor: isMe ? colorScheme.primary : null,
                  labelStyle: isMe
                      ? TextStyle(color: colorScheme.onPrimary)
                      : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
