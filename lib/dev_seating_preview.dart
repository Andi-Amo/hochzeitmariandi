// TEMPORARY dev-only preview harness to visually iterate on the seating
// plan floor layout without needing Firebase/auth. Not part of the app;
// run directly with: flutter run -d web-server -t lib/dev_seating_preview.dart
// Delete this file when done.
import 'package:flutter/material.dart';

void main() {
  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Seating preview')),
        body: const _PreviewBody(),
      ),
    );
  }
}

// Synthetic (non-real) guest names, chosen to mimic the length/shape of
// real names (some short, some long double-barreled) seen in the app.
List<String> _namesFor(int tableNumber, int count) {
  const pool = [
    'Anna Beispiel-Muster',
    'Tom Kurz',
    'Franziska Langname-Nachname',
    'Bert Ohlsen',
    'Katharina Vorderberg',
    'Max Kleinschmidt',
    'Renate Oberhauser-Lange',
    'Erich Graf',
    'Sabine Wolkenstein',
    'Dieter Kurzmann',
    'Waltraud Süttlerlein',
    'Jakob Brandtner',
    'Helene Städterling',
    'Lars Vogelsang',
    'Marion Hinterhuber',
    'Klaus Wiesengrund',
  ];
  return List.generate(count, (i) => pool[(tableNumber + i) % pool.length]);
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody();

  static const List<int> _backRowTables = [7, 5, 3, 1];
  static const List<int> _frontRowTables = [9, 8, 6, 4, 2];

  int _seatCountForTable(int tableNumber) => tableNumber == 9 ? 16 : 10;

  @override
  Widget build(BuildContext context) {
    Widget buildTable(int tableNumber) {
      final seatCount = _seatCountForTable(tableNumber);
      final names = _namesFor(tableNumber, seatCount);
      return _RoomTable(
        tableNumber: tableNumber,
        seatNames: names,
        highlightedName: 'Max Kleinschmidt',
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
                const Text('Hallo Max Kleinschmidt, dein Tisch ist hervorgehoben.'),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F5E6),
                    border: Border.all(color: Colors.black54, width: 2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  clipBehavior: Clip.antiAlias,
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: AspectRatio(
                    aspectRatio: 2.7,
                    child: FittedBox(
                    fit: BoxFit.contain,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const _EingangLabel(),
                        const SizedBox(width: 24),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                for (final t in _backRowTables) ...[
                                  buildTable(t),
                                  if (t != _backRowTables.last) const SizedBox(width: 20),
                                ],
                              ],
                            ),
                            const SizedBox(height: 40),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                for (final t in _frontRowTables) ...[
                                  buildTable(t),
                                  if (t != _frontRowTables.last) const SizedBox(width: 20),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _EingangLabel extends StatelessWidget {
  const _EingangLabel();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black54),
        ),
        child: const RotatedBox(
          quarterTurns: 1,
          child: Text('Eingang'),
        ),
      ),
    );
  }
}

class _RoomTable extends StatelessWidget {
  final int tableNumber;
  final List<String> seatNames;
  final String highlightedName;

  const _RoomTable({
    required this.tableNumber,
    required this.seatNames,
    required this.highlightedName,
  });

  bool get _isLongTable => tableNumber == 9 && seatNames.length >= 16;

  @override
  Widget build(BuildContext context) {
    final isLong = _isLongTable;
    final seats = seatNames;
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
        border: Border.all(color: Colors.black54, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('Tisch $tableNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _seatChip(BuildContext context, String name, {required bool large}) {
    final isHighlighted = name == highlightedName;
    final size = large ? 48.0 : 40.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isHighlighted ? Colors.orange.shade100 : Colors.brown.shade100,
        border: Border.all(color: isHighlighted ? Colors.amber : Colors.black54, width: isHighlighted ? 2 : 1),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          name,
          maxLines: 2,
          softWrap: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.0, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _seatRow(BuildContext context, List<String> names, {required bool large}) {
    final chips = <Widget>[];
    for (final name in names) {
      if (chips.isNotEmpty) chips.add(SizedBox(width: large ? 6 : 4));
      chips.add(_seatChip(context, name, large: large));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: chips);
  }

  Widget _seatColumn(BuildContext context, List<String> names, {required bool large}) {
    final chips = <Widget>[];
    for (final name in names) {
      if (chips.isNotEmpty) chips.add(SizedBox(height: large ? 6 : 4));
      chips.add(_seatChip(context, name, large: large));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: chips);
  }
}
