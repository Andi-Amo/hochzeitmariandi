import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/home_back_button.dart';
import '../widgets/back_button_widget.dart';

class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          leading: const HomeBackButton(),
          title: const Text('Location & Parking'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _LocationCard(
              title: 'Schloss Solitude',
              images: const ['images/solitude.jpg', 'images/solitude1.jpg'],
              description:
                  'Ort der Trauung!\nAdresse: Solitude 1, 70197 Stuttgart-West',
              mapsUrl: 'https://share.google/wabjDedqupcY9EpID',
            ),
            const SizedBox(height: 16),
            _LocationCard(
              title: 'Kleiner Kursaal Bad Cannstatt',
              images: const ['images/kursaal.jpg', 'images/kursaal1.jpg'],
              description:
                  'Ort der Feier!\nAdresse: Königspl. 1, 70372 Stuttgart-Bad Cannstatt',
              mapsUrl: 'https://share.google/rCIRJl2YM8YCwrJ7Y',
            ),
            const SizedBox(height: 24),
            Text(
              'Parkmöglichkeiten',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Wir empfehlen, frühzeitig nach einem Parkplatz am Schloss Solitude zu suchen. '
              'Es gibt mehrere Trauungen an dem Tag und viele Gäste werden mit dem Auto anreisen.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _ParkingSection(
              title: '1. Parken am Schloss Solitude',
              spots: _solitudeParking,
            ),
            const SizedBox(height: 20),
            _ParkingSection(
              title: '2. Parken am kleinen Kurpark',
              spots: _kurparkParking,
            ),
            const SizedBox(height: 24),
            Center(
              child: const BackButtonWidget(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String title;
  final List<String> images;
  final String description;
  final String? mapsUrl;

  const _LocationCard({
    required this.title,
    required this.images,
    required this.description,
    this.mapsUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < images.length; i++) ...[
                  Expanded(
                    child: SizedBox(
                      height: 200,
                      child: Image(
                        image: AssetImage(images[i]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (i == 0 && images.length > 1) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(description, style: const TextStyle(fontSize: 22)),
            if (mapsUrl != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(mapsUrl!),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('In Maps öffnen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ParkingSpot {
  final String name;
  final String note;
  final String mapsUrl;

  const _ParkingSpot({
    required this.name,
    required this.note,
    required this.mapsUrl,
  });
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
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
