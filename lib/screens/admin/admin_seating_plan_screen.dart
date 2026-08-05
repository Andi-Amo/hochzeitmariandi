import 'package:flutter/material.dart';

import '../../models/guest.dart';
import '../../services/guest_repository.dart';
import '../../widgets/home_back_button.dart';

/// Admin seating plan with 10 tables, 120 seats each, drag & drop functionality,
/// and group-based color coding for guests.
class AdminSeatingPlanScreen extends StatefulWidget {
  const AdminSeatingPlanScreen({super.key});

  @override
  State<AdminSeatingPlanScreen> createState() => _AdminSeatingPlanScreenState();
}

class _AdminSeatingPlanScreenState extends State<AdminSeatingPlanScreen> {
  final GuestRepository _repository = GuestRepository();
  late Map<String, Color> _groupColors;

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

  Future<void> _updateGuestSeat(Guest guest, String? tableId, String? seat) async {
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

            // Group guests by table
            final guestsByTable = <String, List<Guest>>{};
            for (var i = 1; i <= 10; i++) {
              guestsByTable['$i'] = allGuests
                  .where((g) => g.tableId == '$i')
                  .toList();
            }

            // Build group colors
            _groupColors.clear();
            final groupIds = <String>{};
            for (final g in allGuests) {
              if (g.groupId != null) groupIds.add(g.groupId!);
            }
            var groupNumber = 0;
            for (final groupId in groupIds) {
              _getGroupColor(groupId, groupNumber++);
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '10 Tische à 120 Plätze • Drag & Drop zum Verschieben',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  for (var tableNum = 1; tableNum <= 10; tableNum++)
                    _TableSeatingUI(
                      tableNumber: tableNum,
                      guests: guestsByTable['$tableNum']!,
                      groupColors: _groupColors,
                      onUpdateSeat: _updateGuestSeat,
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

class _TableSeatingUI extends StatefulWidget {
  final int tableNumber;
  final List<Guest> guests;
  final Map<String, Color> groupColors;
  final Function(Guest, String?, String?) onUpdateSeat;

  const _TableSeatingUI({
    required this.tableNumber,
    required this.guests,
    required this.groupColors,
    required this.onUpdateSeat,
  });

  @override
  State<_TableSeatingUI> createState() => _TableSeatingUIState();
}

class _TableSeatingUIState extends State<_TableSeatingUI> {
  late List<Guest?> _seats; // 120 seats per table

  @override
  void initState() {
    super.initState();
    _initializeSeats();
  }

  void _initializeSeats() {
    _seats = List<Guest?>.filled(120, null);
    for (final g in widget.guests) {
      if (g.seat != null) {
        try {
          final seatNumber = int.parse(g.seat!) - 1;
          if (seatNumber >= 0 && seatNumber < 120) {
            _seats[seatNumber] = g;
          }
        } catch (e) {
          // Invalid seat number
        }
      }
    }
  }

  @override
  void didUpdateWidget(_TableSeatingUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guests != widget.guests) {
      _initializeSeats();
    }
  }

  Color _getGroupColor(Guest? guest) {
    if (guest == null) return Colors.transparent;
    return widget.groupColors[guest.groupId] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tisch ${widget.tableNumber}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 12,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.9,
              ),
              itemCount: 120,
              itemBuilder: (context, index) {
                final seatNumber = index + 1;
                final guest = _seats[index];

                return DragTarget<Guest>(
                  onAcceptWithDetails: (details) {
                    setState(() {
                      final draggedGuest = details.data;
                      // Remove from old seat
                      for (int i = 0; i < _seats.length; i++) {
                        if (_seats[i]?.id == draggedGuest.id) {
                          _seats[i] = null;
                        }
                      }
                      // Add to new seat
                      _seats[index] = draggedGuest;
                      widget.onUpdateSeat(
                        draggedGuest,
                        widget.tableNumber.toString(),
                        seatNumber.toString(),
                      );
                    });
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: candidateData.isNotEmpty
                              ? Colors.green
                              : Colors.grey.shade300,
                          width: candidateData.isNotEmpty ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        color: guest != null
                            ? _getGroupColor(guest).withValues(alpha: 0.2)
                            : Colors.grey.shade50,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (guest != null) ...[
                            Draggable<Guest>(
                              data: guest,
                              feedback: _SeatCard(
                                guest: guest,
                                seatNumber: seatNumber,
                                groupColor: _getGroupColor(guest),
                              ),
                              child: _SeatCard(
                                guest: guest,
                                seatNumber: seatNumber,
                                groupColor: _getGroupColor(guest),
                              ),
                            ),
                          ] else
                            Text(
                              seatNumber.toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatCard extends StatelessWidget {
  final Guest guest;
  final int seatNumber;
  final Color groupColor;

  const _SeatCard({
    required this.guest,
    required this.seatNumber,
    required this.groupColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: groupColor.withValues(alpha: 0.3),
        border: Border.all(color: groupColor, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            guest.isChild ? Icons.child_care : Icons.person,
            size: 16,
            color: groupColor,
          ),
          Text(
            guest.groupId ?? '-',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: groupColor,
            ),
          ),
          Text(
            guest.firstName.split(' ').first,
            style: const TextStyle(fontSize: 7),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
