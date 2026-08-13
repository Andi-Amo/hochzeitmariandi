import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/js_interop.dart';

import '../widgets/home_back_button.dart';
import '../widgets/back_button_widget.dart';
import '../widgets/seating_plan_table_card.dart';

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

  List<Guest?> _buildSeatsForTable(List<Guest> guests) {
    const seatCount = 10;
    final seats = List<Guest?>.filled(seatCount, null);
    for (final guest in guests) {
      final seatIndex = int.tryParse(guest.seat ?? '');
      if (seatIndex != null && seatIndex >= 1 && seatIndex <= seatCount) {
        seats[seatIndex - 1] = guest;
      }
    }
    return seats;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Guest>>(
      stream: GuestRepository().watchAllGuests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final guests = snapshot.data!.where((g) => g.rsvpStatus == 'attending');
        final tables = <int, List<Guest>>{
          for (var i = 1; i <= 10; i++) i: <Guest>[],
        };
        final unseated = <Guest>[];

        for (final guest in guests) {
          final tableNumber = int.tryParse(guest.tableId ?? '');
          if (tableNumber != null && tables.containsKey(tableNumber)) {
            tables[tableNumber]!.add(guest);
          } else {
            unseated.add(guest);
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            const gap = 16.0;
            final cardWidth = (constraints.maxWidth - 32 - gap) / 2;

            return ListView(
              children: [
                Text(
                  'Hallo ${currentGuest.fullName}, dein Tisch ist hervorgehoben.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (
                        var tableNumber = 1;
                        tableNumber <= 10;
                        tableNumber++
                      )
                        SizedBox(
                          width: cardWidth,
                          child: SeatingPlanTableCard(
                            tableNumber: tableNumber,
                            seats: _buildSeatsForTable(tables[tableNumber]!),
                            showEmptySeats: false,
                            margin: EdgeInsets.zero,
                            seatBuilder: (context, guest, seatNumber) {
                              if (guest == null) {
                                return const SizedBox.shrink();
                              }
                              return _GuestSeatCard(
                                guest: guest,
                                isHighlighted: guest.id == currentGuest.id,
                                seatNumber: seatNumber,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                if (unseated.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Ungesetzt',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final guest in unseated)
                          _GuestListChip(
                            guest: guest,
                            isHighlighted: guest.id == currentGuest.id,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _GuestSeatCard extends StatelessWidget {
  final Guest guest;
  final bool isHighlighted;
  final int seatNumber;

  const _GuestSeatCard({
    required this.guest,
    required this.isHighlighted,
    required this.seatNumber,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = isHighlighted ? colorScheme.primary : Colors.brown;

    return SizedBox(
      width: 64,
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: 0.25),
          border: Border.all(color: accent, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                guest.isChild ? Icons.child_care : Icons.person,
                size: 16,
                color: accent,
              ),
              Text(
                guest.firstName.split(' ').first,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                seatNumber.toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: accent,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestListChip extends StatelessWidget {
  final Guest guest;
  final bool isHighlighted;

  const _GuestListChip({required this.guest, required this.isHighlighted});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: isHighlighted ? const Icon(Icons.star, size: 18) : null,
      label: Text(
        guest.fullName + (guest.seat != null ? ' (${guest.seat})' : ''),
      ),
      backgroundColor: isHighlighted ? colorScheme.primary : null,
      labelStyle: isHighlighted
          ? TextStyle(color: colorScheme.onPrimary)
          : null,
    );
  }
}
