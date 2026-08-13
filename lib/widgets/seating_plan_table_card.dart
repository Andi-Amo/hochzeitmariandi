import 'package:flutter/material.dart';

import '../models/guest.dart';

typedef SeatingPlanSeatBuilder =
    Widget Function(BuildContext context, Guest? guest, int seatNumber);

class SeatingPlanTableCard extends StatelessWidget {
  final int tableNumber;
  final List<Guest?> seats;
  final SeatingPlanSeatBuilder seatBuilder;
  final bool showEmptySeats;
  final EdgeInsetsGeometry margin;

  const SeatingPlanTableCard({
    super.key,
    required this.tableNumber,
    required this.seats,
    required this.seatBuilder,
    this.showEmptySeats = true,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  bool _shouldRenderSeat(Guest? guest) {
    return showEmptySeats || guest != null;
  }

  Widget _seatSlot(BuildContext context, int index) {
    final guest = index < seats.length ? seats[index] : null;
    if (!_shouldRenderSeat(guest)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: seatBuilder(context, guest, index + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seatCount = seats.length;

    return Card(
      margin: margin,
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
                      for (var i = 0; i < 3 && i < seatCount; i++)
                        _seatSlot(context, i),
                    ],
                  ),
                  const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (seatCount >= 4) _seatSlot(context, 3),
                            if (seatCount >= 5) ...[
                              const SizedBox(height: 8),
                              _seatSlot(context, 4),
                            ],
                          ],
                        ),
                        const SizedBox(width: 10),
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
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (seatCount >= 6) _seatSlot(context, 5),
                            if (seatCount >= 7) ...[
                              const SizedBox(height: 8),
                              _seatSlot(context, 6),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (seatCount > 7)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 7; i < seatCount; i++)
                          _seatSlot(context, i),
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
