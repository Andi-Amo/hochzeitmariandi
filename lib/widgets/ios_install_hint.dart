import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shows a dismissible banner on iOS Safari suggesting guests add the app
/// to their home screen (since a real App Store release isn't planned —
/// see the project plan). Hidden on all other platforms and once dismissed.
class IosInstallHint extends StatefulWidget {
  const IosInstallHint({super.key});

  @override
  State<IosInstallHint> createState() => _IosInstallHintState();
}

class _IosInstallHintState extends State<IosInstallHint> {
  bool _dismissed = false;

  bool get _isIosWeb => kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (!_isIosWeb || _dismissed) return const SizedBox.shrink();

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.ios_share),
        title: const Text('Tipp für iPhone/iPad'),
        subtitle: const Text(
          'Füge diese Seite über "Teilen" → "Zum Home-Bildschirm" hinzu, '
          'um sie wie eine App zu nutzen.',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _dismissed = true),
        ),
      ),
    );
  }
}
