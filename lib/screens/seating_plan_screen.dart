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
                    ? const _GuestSearchPanel()
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
      debugPrint('Countdown sound error: $e');
    }
  }

  void _stopCountdownSound() {
    try {
      callJsMethod('stopCountdownSound', []);
    } catch (e) {
      debugPrint('Countdown sound stop error: $e');
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

class _GuestSearchPanel extends StatefulWidget {
  const _GuestSearchPanel();

  @override
  State<_GuestSearchPanel> createState() => _GuestSearchPanelState();
}

class _GuestSearchPanelState extends State<_GuestSearchPanel> {
  final GuestRepository _repository = GuestRepository();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Guest> _suggestions = [];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  int _levenshteinDistance(String s1, String s2) {
    s1 = s1.toLowerCase().trim();
    s2 = s2.toLowerCase().trim();
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final v0 = List<int>.generate(s2.length + 1, (i) => i);
    final v1 = List<int>.filled(s2.length + 1, 0);

    for (var i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < s2.length; j++) {
        final cost = s1[i] == s2[j] ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
      for (var j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[s2.length];
  }

  Future<void> _search() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final query = '$firstName $lastName'.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _suggestions = [];
    });

    try {
      final matches = await _repository.searchGuests(query);
      if (!mounted) return;

      if (matches.isEmpty) {
        final allGuests = await _repository.fetchAllGuests();
        if (!mounted) return;

        final ranked = <({Guest guest, int distance})>[];
        for (final guest in allGuests) {
          final distance = _levenshteinDistance(query, guest.fullName);
          ranked.add((guest: guest, distance: distance));
        }
        ranked.sort((a, b) => a.distance.compareTo(b.distance));

        setState(() {
          _error = 'Kein exakter Treffer gefunden. Vielleicht meinst du:';
          _suggestions = ranked.take(5).map((entry) => entry.guest).toList();
        });
      } else if (matches.length == 1) {
        _selectGuest(matches.first);
      } else {
        _showSelectGuestDialog(matches);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Fehler bei der Suche. Bitte versuche es erneut.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectGuest(Guest guest) {
    context.read<GuestSession>().identify(guest);
  }

  void _showSelectGuestDialog(List<Guest> matches) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bitte wähle deinen Namen aus:'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: matches.length,
            itemBuilder: (ctx, index) {
              final g = matches[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(g.fullName),
                subtitle: g.groupId != null
                    ? Text('Gruppe: ${g.groupId}')
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _selectGuest(g);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Der Sitzplan ist nur für eingeladene Gäste sichtbar. Bitte gib deinen Vor- und Nachnamen ein.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _firstNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Vorname',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lastNameController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Nachname',
              prefixIcon: Icon(Icons.person_search),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loading ? null : _search,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: const Text('Suchen'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: Theme.of(context).textTheme.titleSmall),
          ],
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  for (final guest in _suggestions)
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(guest.fullName),
                      subtitle: guest.groupId != null
                          ? Text('Gruppe: ${guest.groupId}')
                          : null,
                      onTap: () => _selectGuest(guest),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeatingPlanBody extends StatelessWidget {
  final Guest currentGuest;

  const _SeatingPlanBody({required this.currentGuest});

  int _seatCountForTable(int tableNumber) {
    return tableNumber == 9 ? 16 : 10;
  }

  List<Guest?> _buildSeatsForTable(int tableNumber, List<Guest> guests) {
    final seatCount = _seatCountForTable(tableNumber);
    final seats = List<Guest?>.filled(seatCount, null);
    for (final guest in guests) {
      final seatIndex = int.tryParse(guest.seat ?? '');
      if (seatIndex != null && seatIndex >= 1 && seatIndex <= seatCount) {
        seats[seatIndex - 1] = guest;
      }
    }
    return seats;
  }

  // The venue's actual layout (see images/canvas.png) has four square
  // tables in the back row and a long banquet table plus four more square
  // tables in the front row, closest to the entrance.
  static const List<int> _backRowTables = [7, 5, 3, 1];
  static const List<int> _frontRowTables = [9, 8, 6, 4, 2];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Guest>>(
      stream: GuestRepository().watchAllGuests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final attendees = snapshot.data!.where((g) => g.rsvpStatus == 'attending');
        final tables = <int, List<Guest>>{
          for (var i = 1; i <= 9; i++) i: <Guest>[],
        };
        final unseated = <Guest>[];

        for (final guest in attendees) {
          final tableNumber = int.tryParse(guest.tableId ?? '');
          if (tableNumber != null && tables.containsKey(tableNumber)) {
            tables[tableNumber]!.add(guest);
          } else {
            unseated.add(guest);
          }
        }

        Widget buildTable(int tableNumber) {
          final guestsAtTable = tables[tableNumber] ?? const [];
          return _RoomTable(
            tableNumber: tableNumber,
            seats: _buildSeatsForTable(tableNumber, guestsAtTable),
            highlightedGuestId: currentGuest.id,
            isHighlighted: guestsAtTable.any((guest) => guest.id == currentGuest.id),
          );
        }

        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hallo ${currentGuest.fullName}, dein Tisch ist hervorgehoben.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F5E6),
                        border: Border.all(color: Colors.black54, width: 2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const _EingangLabel(),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 20,
                                  runSpacing: 20,
                                  children: [
                                    for (final tableNumber in _backRowTables)
                                      buildTable(tableNumber),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 20,
                                  runSpacing: 20,
                                  children: [
                                    for (final tableNumber in _frontRowTables)
                                      buildTable(tableNumber),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unseated.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Ungesetzt',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small rotated label marking the entrance ("Eingang"), matching the
/// venue's floor plan (images/canvas.png).
class _EingangLabel extends StatelessWidget {
  const _EingangLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black54),
      ),
      child: const RotatedBox(
        quarterTurns: 1,
        child: Text('Eingang'),
      ),
    );
  }
}

/// A single table rendered with its own natural size (no hard-coded pixel
/// positions), so it can never overflow regardless of how many seats are
/// filled or how long guest names are. Tables lay themselves out as:
/// a row of seats on top, a row on the bottom, and the table itself
/// flanked by a column of seats on the left and right.
class _RoomTable extends StatelessWidget {
  final int tableNumber;
  final List<Guest?> seats;
  final String highlightedGuestId;
  final bool isHighlighted;

  const _RoomTable({
    required this.tableNumber,
    required this.seats,
    required this.highlightedGuestId,
    required this.isHighlighted,
  });

  bool get _isLongTable => tableNumber == 9 && seats.length >= 16;

  @override
  Widget build(BuildContext context) {
    final isLong = _isLongTable;
    final accent = isHighlighted ? Theme.of(context).colorScheme.primary : Colors.orange;
    final borderColor = isHighlighted ? Theme.of(context).colorScheme.primary : Colors.black54;

    final topSeats = isLong
        ? [seats[0], seats[1], seats[2], seats[3], seats[4], seats[5]]
        : [seats[0], seats[1], seats[2]];
    final leftSeats = isLong ? [seats[6], seats[7]] : [seats[3], seats[4]];
    final rightSeats = isLong ? [seats[8], seats[9]] : [seats[5], seats[6]];
    final bottomSeats = isLong
        ? [seats[10], seats[11], seats[12], seats[13], seats[14], seats[15]]
        : [seats[7], seats[8], seats[9]];

    final tableBox = Container(
      width: isLong ? 170.0 : 92.0,
      height: isLong ? 64.0 : 52.0,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFF8C3A),
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(10),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Text(
        'Tisch $tableNumber',
        style: TextStyle(
          fontSize: isLong ? 16 : 13,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _seatRow(context, topSeats, large: isLong),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _seatColumn(context, leftSeats, large: isLong),
            const SizedBox(width: 8),
            tableBox,
            const SizedBox(width: 8),
            _seatColumn(context, rightSeats, large: isLong),
          ],
        ),
        const SizedBox(height: 6),
        _seatRow(context, bottomSeats, large: isLong),
      ],
    );
  }

  Widget _seatChip(BuildContext context, Guest guest, {required bool large}) {
    final isSeatHighlighted = guest.id == highlightedGuestId;
    final size = large ? 48.0 : 40.0;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSeatHighlighted
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.brown.shade100,
        border: Border.all(
          color: isSeatHighlighted ? Colors.amber : Colors.black54,
          width: isSeatHighlighted ? 2 : 1,
        ),
        boxShadow: isSeatHighlighted
            ? [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          guest.fullName,
          maxLines: 2,
          softWrap: true,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.0,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  /// Builds a horizontal line of seat chips, skipping unassigned seats
  /// entirely so the table stays compact instead of showing empty gaps.
  Widget _seatRow(BuildContext context, List<Guest?> guests, {required bool large}) {
    final chips = <Widget>[];
    for (final guest in guests) {
      if (guest == null) continue;
      if (chips.isNotEmpty) chips.add(SizedBox(width: large ? 6 : 4));
      chips.add(_seatChip(context, guest, large: large));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: chips);
  }

  /// Same as [_seatRow] but stacked vertically for the left/right sides.
  Widget _seatColumn(BuildContext context, List<Guest?> guests, {required bool large}) {
    final chips = <Widget>[];
    for (final guest in guests) {
      if (guest == null) continue;
      if (chips.isNotEmpty) chips.add(SizedBox(height: large ? 6 : 4));
      chips.add(_seatChip(context, guest, large: large));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: chips);
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
