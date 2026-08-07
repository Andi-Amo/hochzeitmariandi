import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/back_button_widget.dart';
import '../widgets/home_back_button.dart';

class HotelScreen extends StatelessWidget {
  const HotelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          leading: const HomeBackButton(),
          title: const Text('Hotels'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Hier sind die Hotels in der Nähe des Kleinen Kursaals, '
                  'wo die Feier stattfindet. Das Brautpaar und die meisten Gäste übernachten im Premier Inn.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _HotelCard(
              name: 'Premier Inn Bad Cannstatt',
              note:
                  'Hier übernachten das Brautpaar und die meisten Gäste.\n'
                  'Direkt am Kursaal – ca. 1 Minute zu Fuß.',
              address: 'König-Karl-Str. 2, 70372 Stuttgart-Bad Cannstatt',
              mapsUrl: 'https://maps.app.goo.gl/XzU9mABPEhiEdJQM8',
              bookingUrl:
                  'https://www.premierinn.com/de/de/hotels/germany/stuttgart/stuttgart-bad-cannstatt.html',
            ),
            const SizedBox(height: 12),
            const _HotelCard(
              name: 'Hotel Motel One Stuttgart-Bad Cannstatt',
              note: 'Ca. 12 Minuten zu Fuß zum Kursaal.',
              address: 'König-Karl-Str. 20, 70372 Stuttgart-Bad Cannstatt',
              mapsUrl: 'https://maps.app.goo.gl/58AM6s7f5PuHfQWQA',
            ),
            const SizedBox(height: 24),
            Center(child: const BackButtonWidget()),
          ],
        ),
      ),
    );
  }
}

class _HotelCard extends StatelessWidget {
  final String name;
  final String note;
  final String address;
  final String mapsUrl;
  final String? bookingUrl;

  const _HotelCard({
    required this.name,
    required this.note,
    required this.address,
    required this.mapsUrl,
    this.bookingUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.hotel_outlined,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(note, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(mapsUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('In Maps öffnen'),
                ),
                if (bookingUrl != null)
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(bookingUrl!),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_browser_outlined),
                    label: const Text('Zur Website'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
