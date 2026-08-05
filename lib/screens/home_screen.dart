import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/ios_install_hint.dart';

/// Landing page with general wedding info and navigation into the feature
/// sections. Update the placeholder texts below with your actual wedding
/// details (date, location, timeline, dress code, ...).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Hochzeit von Mariandi',
            style: GoogleFonts.dancingScript(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const IosInstallHint(),
            Image.asset(
              'images/paar.jpg',
              width: double.infinity,
              height: 750,
              fit: BoxFit.contain,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Info und Timetable:',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Datum: 05.09.2026\n'
                      'Ort der Trauung: Schloss Solitude 1, 70197 Stuttgart-West\n'
                      'Ort der Feier: Kleiner Kursaal Bad Cannstatt, Königspl. 1, 70372 Stuttgart-Bad Cannstatt\n'
                      'Ablauf:\n'
                      '· Treffpunkt vor Trauung 12:30 Uhr an der Ostseite des Schloss Solitude\n'
                      '· Gemeinsames Einlaufen in den Trausaal 12:45 Uhr\n'
                      '· Trauung 13:00 Uhr\n'
                      '· Sektverabschiedung am Schloss 13:45 Uhr\n'
                      '· Autokorso nach Bad Cannstatt 14:45 Uhr\n'
                      '· Sektempfang am Kursaal 15:30 Uhr\n'
                      '· Kuchenbuffet ab 16:00 Uhr\n'
                      '· Essen ab 18:30 Uhr\n'
                      'Dresscode: Come as you are! (Feierlich, bequem, wie auch immer du dich am wohlsten fühlst.)',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _NavCard(
              icon: Icons.mail_outline,
              title: 'Auf Einladung antworten (RSVP)',
              subtitle: 'Sag uns, ob du kommen kannst.',
              onTap: () => context.go('/rsvp'),
            ),
            _NavCard(
              icon: Icons.event_seat_outlined,
              title: 'Sitzplan',
              subtitle: 'Finde deinen Platz.',
              onTap: () => context.go('/seating'),
            ),
            _NavCard(
              icon: Icons.cake_outlined,
              title: 'Kuchensektion',
              subtitle: 'Kuchen mitbringen & Übersicht ansehen.',
              onTap: () => context.go('/cakes'),
            ),
            _NavCard(
              icon: Icons.photo_camera_outlined,
              title: 'Fotogalerie',
              subtitle: 'Fotos hochladen und live ansehen.',
              onTap: () => context.go('/photos'),
            ),
            _NavCard(
              icon: Icons.mic_outlined,
              title: 'Rede / Programmpunkt anmelden',
              subtitle: 'Möchtest du etwas beitragen?',
              onTap: () => context.go('/program'),
            ),
            _NavCard(
              icon: Icons.location_city_rounded,
              title: 'Location & Parking',
              subtitle: 'Location der Trauung & Feier und Parkmöglichkeiten.',
              onTap: () => context.go('/location'),
            ),
            const Divider(height: 32),
            _NavCard(
              icon: Icons.android,
              title: 'Android-App herunterladen',
              subtitle:
                  'Installiere die App direkt als APK (kein Play Store nötig).',
              onTap: () => launchUrl(
                Uri.parse('https://github.com/Andi-Amo/wedapp/releases/latest'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            const Divider(height: 32),
            _NavCard(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Admin-Bereich',
              subtitle: 'Nur für das Brautpaar.',
              onTap: () => context.go('/admin'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
