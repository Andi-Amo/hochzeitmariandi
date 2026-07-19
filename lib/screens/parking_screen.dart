import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// One parking option: a name, an optional note (walking time, free hours,
/// ...), and a Google Maps link opened via [url_launcher] instead of ever
/// showing the raw URL.
class _ParkingSpot {
  final String name;
  final String note;
  final String mapsUrl;

  const _ParkingSpot({required this.name, required this.note, required this.mapsUrl});
}

const _solitudeParking = [
  _ParkingSpot(
    name: 'Parkplatz an der Solitude',
    note: '8 Minuten zu Fuß',
    mapsUrl: 'https://share.google/G7UWdLk9T9ohRbZZi',
  ),
  _ParkingSpot(
    name: 'Parkplatz Biegel',
    note: '12 Minuten zu Fuß',
    mapsUrl: 'https://share.google/WVN1VcByeAYgGQy9H',
  ),
  _ParkingSpot(
    name: 'Parkplatz Forsthaus 2',
    note: '13 Minuten zu Fuß',
    mapsUrl: 'https://share.google/NXPkY1e9geNAwVeGk',
  ),
  _ParkingSpot(
    name: 'Parkplatz Solitudetor',
    note: '18 Minuten zu Fuß',
    mapsUrl: 'https://share.google/9iELX3gJ3LmeWU4aZ',
  ),
];

const _kurparkParking = [
  _ParkingSpot(
    name: 'Tiefgarage Am Kursaal',
    note: '1 Minute zu Fuß',
    mapsUrl: 'https://share.google/ZTSt9F3ShZP8Q3hLT',
  ),
  _ParkingSpot(
    name: 'Öffentlicher Parkplatz am Kurpark',
    note: '2 Minuten zu Fuß · 2 Stunden kostenlos',
    mapsUrl: 'https://maps.app.goo.gl/pjVc7zzsgSV1gktD6',
  ),
  _ParkingSpot(
    name: 'Parkhaus Mühlgrün',
    note: 'gute 10 Minuten zu Fuß',
    mapsUrl: 'https://maps.app.goo.gl/76H9iwJK65e7vdis5',
  ),
];

/// Overview of parking options near the ceremony (Schloss Solitude) and the
/// reception (kleiner Kurpark), each linking out to Google Maps.
class ParkingScreen extends StatelessWidget {
  const ParkingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parken')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ParkingSection(
            title: '1. Parken am Schloss Solitude',
            spots: _solitudeParking,
          ),
          SizedBox(height: 24),
          _ParkingSection(
            title: '2. Parken am kleinen Kurpark',
            spots: _kurparkParking,
          ),
        ],
      ),
    );
  }
}

class _ParkingSection extends StatelessWidget {
  final String title;
  final List<_ParkingSpot> spots;

  const _ParkingSection({required this.title, required this.spots});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < spots.length; i++) ...[
                _ParkingSpotTile(spot: spots[i]),
                if (i != spots.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ParkingSpotTile extends StatelessWidget {
  final _ParkingSpot spot;

  const _ParkingSpotTile({required this.spot});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.local_parking_outlined),
      title: Text(spot.name),
      subtitle: Text(spot.note),
      trailing: TextButton.icon(
        icon: const Icon(Icons.map_outlined, size: 18),
        label: const Text('In Maps öffnen'),
        onPressed: () => launchUrl(
          Uri.parse(spot.mapsUrl),
          mode: LaunchMode.externalApplication,
        ),
      ),
    );
  }
}
