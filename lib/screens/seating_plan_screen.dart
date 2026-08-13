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

class _GuestSeatCard extends StatefulWidget {
  final Guest guest;
  final bool isHighlighted;
  final int seatNumber;

  const _GuestSeatCard({
    required this.guest,
    required this.isHighlighted,
    required this.seatNumber,
  });

  @override
  State<_GuestSeatCard> createState() => _GuestSeatCardState();
}

class _GuestSeatCardState extends State<_GuestSeatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = Tween<double>(
      begin: 0.96,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.isHighlighted) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _GuestSeatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isHighlighted && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = widget.isHighlighted ? colorScheme.primary : Colors.brown;
    final background = widget.isHighlighted
        ? Color.lerp(
            colorScheme.primaryContainer,
            colorScheme.tertiaryContainer,
            _controller.value,
          )!
        : Colors.brown.shade100;

    return ScaleTransition(
      scale: widget.isHighlighted ? _scale : const AlwaysStoppedAnimation(1),
      child: SizedBox(
        width: 64,
        height: 64,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: background,
            border: Border.all(color: accent, width: 2),
            boxShadow: widget.isHighlighted
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.guest.isChild ? Icons.child_care : Icons.person,
                  size: 16,
                  color: accent,
                ),
                if (widget.isHighlighted)
                  const Icon(Icons.star, size: 10, color: Colors.amber),
                Text(
                  widget.guest.firstName.split(' ').first,
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
                  widget.seatNumber.toString(),
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
