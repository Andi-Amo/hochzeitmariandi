import 'package:flutter/material.dart';

import '../../models/guest.dart';
import '../../services/guest_repository.dart';
import '../../widgets/home_back_button.dart';

const int _tableCount = 10;
const int _seatsPerTable = 10;

// Callback type used to show the move-guest dialog from any guest chip.
typedef _OnGuestTap = void Function(Guest guest);

/// Admin seating plan with drag & drop between chairs and an unseated pool.
class AdminSeatingPlanScreen extends StatefulWidget {
  const AdminSeatingPlanScreen({super.key});

  @override
  State<AdminSeatingPlanScreen> createState() => _AdminSeatingPlanScreenState();
}

class _AdminSeatingPlanScreenState extends State<AdminSeatingPlanScreen> {
  final GuestRepository _repository = GuestRepository();
  late final Map<String, Color> _groupColors;

  @override
  void initState() {
    super.initState();
    _groupColors = {};
  }

  Color _getGroupColor(String? groupId, int groupNumber) {
    if (groupId == null) return Colors.grey;
    if (_groupColors.containsKey(groupId)) {
      return _groupColors[groupId]!;
    }

    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.cyan,
      Colors.lime,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
    ];

    final color = colors[groupNumber % colors.length];
    _groupColors[groupId] = color;
    return color;
  }

  bool _isValidTableId(String? tableId) {
    final tableNumber = int.tryParse(tableId ?? '');
    return tableNumber != null &&
        tableNumber >= 1 &&
        tableNumber <= _tableCount;
  }

  bool _isValidSeat(String? seat) {
    final seatNumber = int.tryParse(seat ?? '');
    return seatNumber != null &&
        seatNumber >= 1 &&
        seatNumber <= _seatsPerTable;
  }

  bool _hasValidSeatAssignment(Guest guest) {
    return _isValidTableId(guest.tableId) && _isValidSeat(guest.seat);
  }

  Future<void> _updateGuestSeat(
    Guest guest,
    String? tableId,
    String? seat,
  ) async {
    final updated = Guest(
      id: guest.id,
      firstName: guest.firstName,
      lastName: guest.lastName,
      groupId: guest.groupId,
      tableId: tableId,
      seat: seat,
      isUsualCakeSuspect: guest.isUsualCakeSuspect,
      isChild: guest.isChild,
      childAge: guest.childAge,
      rsvpStatus: guest.rsvpStatus,
      plusOnes: guest.plusOnes,
      dietaryNotes: guest.dietaryNotes,
    );

    await _repository.updateGuest(updated);
  }

  Future<void> _moveGuestToSeat({
    required Guest draggedGuest,
    required int targetTableNumber,
    required int targetSeatNumber,
    Guest? guestAtTargetSeat,
  }) async {
    final targetTableId = targetTableNumber.toString();
    final targetSeat = targetSeatNumber.toString();
    final sourceTableId = _hasValidSeatAssignment(draggedGuest)
        ? draggedGuest.tableId
        : null;
    final sourceSeat = _hasValidSeatAssignment(draggedGuest)
        ? draggedGuest.seat
        : null;

    if (draggedGuest.tableId == targetTableId &&
        draggedGuest.seat == targetSeat &&
        guestAtTargetSeat?.id == draggedGuest.id) {
      return;
    }

    if (guestAtTargetSeat == null || guestAtTargetSeat.id == draggedGuest.id) {
      await _updateGuestSeat(draggedGuest, targetTableId, targetSeat);
      return;
    }

    await Future.wait([
      _updateGuestSeat(draggedGuest, targetTableId, targetSeat),
      _updateGuestSeat(guestAtTargetSeat, sourceTableId, sourceSeat),
    ]);
  }

  Future<void> _moveGuestToUnseated(Guest guest) async {
    if (!_hasValidSeatAssignment(guest) &&
        (guest.tableId == null || guest.tableId!.isEmpty) &&
        (guest.seat == null || guest.seat!.isEmpty)) {
      return;
    }

    await _updateGuestSeat(guest, null, null);
  }

  void _showMoveDialog(
    BuildContext context,
    Guest guest,
    Map<String, List<Guest>> guestsByTable,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _MoveGuestDialog(
        guest: guest,
        guestsByTable: guestsByTable,
        onMove: (targetTableId, targetSeat) async {
          if (targetTableId == null) {
            await _moveGuestToUnseated(guest);
          } else {
            final tableGuests = guestsByTable[targetTableId] ?? [];
            Guest? guestAtTarget;
            for (final g in tableGuests) {
              if (g.seat == targetSeat.toString() && g.id != guest.id) {
                guestAtTarget = g;
                break;
              }
            }
            await _moveGuestToSeat(
              draggedGuest: guest,
              targetTableNumber: int.parse(targetTableId),
              targetSeatNumber: targetSeat!,
              guestAtTargetSeat: guestAtTarget,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          leading: const HomeBackButton(),
          title: const Text('Sitzplan (Admin)'),
        ),
        body: StreamBuilder<List<Guest>>(
          stream: _repository.watchAllGuests(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allGuests = snapshot.data!;

            final guestsByTable = <String, List<Guest>>{
              for (var i = 1; i <= _tableCount; i++) '$i': <Guest>[],
            };

            final unseatedAttendingGuests = <Guest>[];

            for (final guest in allGuests) {
              if (guest.rsvpStatus == 'attending' &&
                  _hasValidSeatAssignment(guest)) {
                guestsByTable[guest.tableId!]!.add(guest);
              } else if (guest.rsvpStatus == 'attending') {
                unseatedAttendingGuests.add(guest);
              }
            }

            _groupColors.clear();
            final groupIds = <String>{};
            for (final guest in allGuests) {
              if (guest.groupId != null && guest.groupId!.isNotEmpty) {
                groupIds.add(guest.groupId!);
              }
            }

            var groupNumber = 0;
            for (final groupId in groupIds) {
              _getGroupColor(groupId, groupNumber++);
            }

            void onGuestTap(Guest guest) =>
                _showMoveDialog(context, guest, guestsByTable);

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '10 Tische à 10 Plätze (3 lang, 2 schmal) • Ziehen zum Verschieben/Tauschen, oder Tippen für Dialog',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _UnseatedGuestsPanel(
                    guests: unseatedAttendingGuests,
                    groupColors: _groupColors,
                    onGuestDropped: _moveGuestToUnseated,
                    onGuestTap: onGuestTap,
                  ),
                  for (var tableNum = 1; tableNum <= _tableCount; tableNum++)
                    _TableSeatingUI(
                      tableNumber: tableNum,
                      guests: guestsByTable['$tableNum']!,
                      groupColors: _groupColors,
                      onSeatDrop: _moveGuestToSeat,
                      onGuestTap: onGuestTap,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _UnseatedGuestsPanel extends StatelessWidget {
  final List<Guest> guests;
  final Map<String, Color> groupColors;
  final Future<void> Function(Guest guest) onGuestDropped;
  final _OnGuestTap onGuestTap;

  const _UnseatedGuestsPanel({
    required this.guests,
    required this.groupColors,
    required this.onGuestDropped,
    required this.onGuestTap,
  });

  Color _getGroupColor(Guest guest) {
    return groupColors[guest.groupId] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DragTarget<Guest>(
          onAcceptWithDetails: (details) {
            onGuestDropped(details.data);
          },
          builder: (context, candidateData, rejectedData) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ungesetzt (${guests.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hier stehen alle zugesagten Personen ohne Sitzplatz.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? Colors.green.withValues(alpha: 0.08)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: candidateData.isNotEmpty
                          ? Colors.green
                          : Colors.grey.shade300,
                      width: candidateData.isNotEmpty ? 2 : 1,
                    ),
                  ),
                  child: guests.isEmpty
                      ? const Text(
                          'Alle zugesagten Personen haben bereits einen Sitzplatz.',
                        )
                      : Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final guest in guests)
                              SizedBox(
                                width: 84,
                                child: Draggable<Guest>(
                                  data: guest,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: SizedBox(
                                      width: 84,
                                      child: _ChairCard(
                                        guest: guest,
                                        groupColor: _getGroupColor(guest),
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.35,
                                    child: _ChairCard(
                                      guest: guest,
                                      groupColor: _getGroupColor(guest),
                                    ),
                                  ),
                                  child: _ChairCard(
                                    guest: guest,
                                    groupColor: _getGroupColor(guest),
                                    onTap: () => onGuestTap(guest),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TableSeatingUI extends StatelessWidget {
  final int tableNumber;
  final List<Guest> guests;
  final Map<String, Color> groupColors;
  final _OnGuestTap onGuestTap;
  final Future<void> Function({
    required Guest draggedGuest,
    required int targetTableNumber,
    required int targetSeatNumber,
    Guest? guestAtTargetSeat,
  })
  onSeatDrop;

  const _TableSeatingUI({
    required this.tableNumber,
    required this.guests,
    required this.groupColors,
    required this.onSeatDrop,
    required this.onGuestTap,
  });

  List<Guest?> _buildSeats() {
    final seats = List<Guest?>.filled(_seatsPerTable, null);
    for (final guest in guests) {
      final seatIndex = int.tryParse(guest.seat ?? '');
      if (seatIndex != null && seatIndex >= 1 && seatIndex <= _seatsPerTable) {
        seats[seatIndex - 1] = guest;
      }
    }
    return seats;
  }

  Color _getGroupColor(Guest? guest) {
    if (guest == null) return Colors.transparent;
    return groupColors[guest.groupId] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final seats = _buildSeats();
    // Seat layout around the table:
    //   1  2  3      ← top long side
    // 4        5     ← left / right narrow ends
    // 6        7
    //   8  9  10     ← bottom long side

    Widget seatTarget(int index) => _SeatDropTarget(
      guest: seats[index],
      seatNumber: index + 1,
      tableNumber: tableNumber,
      groupColor: _getGroupColor(seats[index]),
      onSeatDrop: onSeatDrop,
      onGuestTap: onGuestTap,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tisch $tableNumber',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  // Top long side: seats 1–3
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: seatTarget(i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Middle row: narrow ends + table body
                  IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left narrow end: seats 4–5
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            seatTarget(3),
                            const SizedBox(height: 8),
                            seatTarget(4),
                          ],
                        ),
                        const SizedBox(width: 10),
                        // Table rectangle
                        Container(
                          width: 220,
                          decoration: BoxDecoration(
                            color: Colors.brown.shade100,
                            border: Border.all(color: Colors.brown, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Tisch $tableNumber',
                              style: TextStyle(
                                color: Colors.brown.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Right narrow end: seats 6–7
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            seatTarget(5),
                            const SizedBox(height: 8),
                            seatTarget(6),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Bottom long side: seats 8–10
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 7; i < 10; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: seatTarget(i),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatDropTarget extends StatelessWidget {
  final Guest? guest;
  final int seatNumber;
  final int tableNumber;
  final Color groupColor;
  final _OnGuestTap onGuestTap;
  final Future<void> Function({
    required Guest draggedGuest,
    required int targetTableNumber,
    required int targetSeatNumber,
    Guest? guestAtTargetSeat,
  })
  onSeatDrop;

  const _SeatDropTarget({
    required this.guest,
    required this.seatNumber,
    required this.tableNumber,
    required this.groupColor,
    required this.onSeatDrop,
    required this.onGuestTap,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Guest>(
      onAcceptWithDetails: (details) {
        onSeatDrop(
          draggedGuest: details.data,
          targetTableNumber: tableNumber,
          targetSeatNumber: seatNumber,
          guestAtTargetSeat: guest,
        );
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: candidateData.isNotEmpty
                  ? Colors.green
                  : Colors.grey.shade300,
              width: candidateData.isNotEmpty ? 3 : 2,
            ),
            color: guest != null
                ? groupColor.withValues(alpha: 0.18)
                : Colors.grey.shade50,
          ),
          child: guest == null
              ? Center(
                  child: Text(
                    seatNumber.toString(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                    ),
                  ),
                )
              : Draggable<Guest>(
                  data: guest!,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: _ChairCard(guest: guest!, groupColor: groupColor),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _ChairCard(guest: guest!, groupColor: groupColor),
                  ),
                  child: _ChairCard(
                    guest: guest!,
                    groupColor: groupColor,
                    onTap: () => onGuestTap(guest!),
                  ),
                ),
        );
      },
    );
  }
}

class _ChairCard extends StatelessWidget {
  final Guest guest;
  final Color groupColor;
  final VoidCallback? onTap;

  const _ChairCard({required this.guest, required this.groupColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: groupColor.withValues(alpha: 0.35),
          border: Border.all(color: groupColor, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                guest.isChild ? Icons.child_care : Icons.person,
                size: 16,
                color: groupColor,
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
                guest.lastName,
                style: TextStyle(
                  fontSize: 10,
                  color: groupColor,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Move-guest dialog
// ---------------------------------------------------------------------------

class _MoveGuestDialog extends StatefulWidget {
  final Guest guest;
  final Map<String, List<Guest>> guestsByTable;
  final Future<void> Function(String? tableId, int? seat) onMove;

  const _MoveGuestDialog({
    required this.guest,
    required this.guestsByTable,
    required this.onMove,
  });

  @override
  State<_MoveGuestDialog> createState() => _MoveGuestDialogState();
}

class _MoveGuestDialogState extends State<_MoveGuestDialog> {
  // null means "Ungesetzt"; '1'..'10' means a table
  String? _selectedTable;
  int? _selectedSeat;
  bool _saving = false;

  String _currentLocation() {
    final g = widget.guest;
    final hasTable = g.tableId != null && g.tableId!.isNotEmpty;
    final hasSeat = g.seat != null && g.seat!.isNotEmpty;
    if (hasTable && hasSeat) return 'Tisch ${g.tableId}, Platz ${g.seat}';
    return 'Ungesetzt';
  }

  Guest? _occupantAt(String tableId, int seatNumber) {
    final tableGuests = widget.guestsByTable[tableId] ?? [];
    for (final g in tableGuests) {
      if (g.seat == seatNumber.toString() && g.id != widget.guest.id) return g;
    }
    return null;
  }

  bool get _canConfirm =>
      !_saving && (_selectedTable == null || _selectedSeat != null);

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _saving = true);
    Navigator.pop(context);
    await widget.onMove(_selectedTable, _selectedSeat);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Guest? swapTarget;
    if (_selectedTable != null && _selectedSeat != null) {
      swapTarget = _occupantAt(_selectedTable!, _selectedSeat!);
    }

    return AlertDialog(
      title: const Text('Gast verschieben'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.guest.fullName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Aktuell: ${_currentLocation()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String?>(
              decoration: const InputDecoration(
                labelText: 'Ziel-Tisch',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              value: _selectedTable,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Ungesetzt'),
                ),
                for (var i = 1; i <= _tableCount; i++)
                  DropdownMenuItem<String?>(
                    value: '$i',
                    child: Text('Tisch $i'),
                  ),
              ],
              onChanged: (value) => setState(() {
                _selectedTable = value;
                _selectedSeat = null;
              }),
            ),
            if (_selectedTable != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Platz',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                value: _selectedSeat,
                items: [
                  for (var i = 1; i <= _seatsPerTable; i++)
                    DropdownMenuItem<int>(
                      value: i,
                      child: Text(() {
                        final occ = _occupantAt(_selectedTable!, i);
                        return occ != null
                            ? 'Platz $i  →  ${occ.fullName}'
                            : 'Platz $i  (frei)';
                      }()),
                    ),
                ],
                onChanged: (v) => setState(() => _selectedSeat = v),
              ),
              if (swapTarget != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      size: 16,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Tauscht Platz mit ${swapTarget.fullName}',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _canConfirm ? _confirm : null,
          child: Text(_selectedTable == null ? 'Auf Ungesetzt' : 'Verschieben'),
        ),
      ],
    );
  }
}
