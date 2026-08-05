import 'package:flutter/material.dart';

import '../../models/guest.dart';
import '../../services/guest_repository.dart';
import '../../widgets/home_back_button.dart';

const int _tableCount = 10;
const int _seatsPerTable = 10;

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
              if (guest.rsvpStatus == 'attending' && _hasValidSeatAssignment(guest)) {
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

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '10 Tische à 10 Plätze (2 Reihen × 5 Stühle) • Ziehen zum Verschieben oder Tauschen',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _UnseatedGuestsPanel(
                    guests: unseatedAttendingGuests,
                    groupColors: _groupColors,
                    onGuestDropped: _moveGuestToUnseated,
                  ),
                  for (var tableNum = 1; tableNum <= _tableCount; tableNum++)
                    _TableSeatingUI(
                      tableNumber: tableNum,
                      guests: guestsByTable['$tableNum']!,
                      groupColors: _groupColors,
                      onSeatDrop: _moveGuestToSeat,
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

  const _UnseatedGuestsPanel({
    required this.guests,
    required this.groupColors,
    required this.onGuestDropped,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 5; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _SeatDropTarget(
                            guest: seats[i],
                            seatNumber: i + 1,
                            tableNumber: tableNumber,
                            groupColor: _getGroupColor(seats[i]),
                            onSeatDrop: onSeatDrop,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 300,
                    height: 100,
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
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 5; i < _seatsPerTable; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _SeatDropTarget(
                            guest: seats[i],
                            seatNumber: i + 1,
                            tableNumber: tableNumber,
                            groupColor: _getGroupColor(seats[i]),
                            onSeatDrop: onSeatDrop,
                          ),
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
                      fontSize: 12,
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
                  child: _ChairCard(guest: guest!, groupColor: groupColor),
                ),
        );
      },
    );
  }
}

class _ChairCard extends StatelessWidget {
  final Guest guest;
  final Color groupColor;

  const _ChairCard({required this.guest, required this.groupColor});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
              size: 18,
              color: groupColor,
            ),
            Text(
              guest.firstName.split(' ').first,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                height: 0.9,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              guest.groupId ?? '-',
              style: TextStyle(
                fontSize: 7,
                color: groupColor,
                fontWeight: FontWeight.w600,
                height: 0.9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
