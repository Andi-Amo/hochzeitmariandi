import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cake_entry.dart';
import '../models/guest.dart';
import '../services/cake_repository.dart';
import '../services/guest_session.dart';
import '../widgets/guest_name_search.dart';

/// Cake section: shows the list/overview of already-planned cakes and a
/// signup form. Guests flagged as `isUsualCakeSuspect` automatically get a
/// reminder popup asking if they'd like to bring a cake again.
class CakeScreen extends StatefulWidget {
  const CakeScreen({super.key});

  @override
  State<CakeScreen> createState() => _CakeScreenState();
}

class _CakeScreenState extends State<CakeScreen> {
  final CakeRepository _repository = CakeRepository();
  final TextEditingController _descriptionController = TextEditingController();
  bool _popupShownForGuest = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _maybeShowReminderPopup(Guest guest) {
    if (_popupShownForGuest || !guest.isUsualCakeSuspect) return;
    _popupShownForGuest = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kleine Erinnerung 🍰'),
          content: Text(
            'Hallo ${guest.firstName}! Wie wir dich kennen, backst du gerne '
            'einen Kuchen für besondere Anlässe. Möchtest du auch dieses Mal '
            'einen Kuchen mitbringen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Vielleicht später'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                FocusScope.of(context).requestFocus(FocusNode());
              },
              child: const Text('Ja, gerne!'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _submit(Guest guest) async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) return;
    await _repository.addCake(
      guestId: guest.id,
      guestName: guest.fullName,
      cakeDescription: description,
    );
    _descriptionController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Danke! Dein Kuchen wurde eingetragen.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final guest = context.watch<GuestSession>().guest;
    if (guest != null) _maybeShowReminderPopup(guest);

    return Scaffold(
      appBar: AppBar(title: const Text('Kuchensektion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (guest == null) ...[
              const Text(
                'Möchtest du einen Kuchen mitbringen? Gib zuerst deinen Namen ein.',
              ),
              const SizedBox(height: 16),
              const GuestNameSearch(),
              const SizedBox(height: 24),
            ] else ...[
              Text(
                'Hallo ${guest.fullName}! Trag hier ein, welchen Kuchen du mitbringst.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'z.B. "Zitronenkuchen" oder "Käsesahnetorte"',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _submit(guest),
                icon: const Icon(Icons.cake),
                label: const Text('Kuchen eintragen'),
              ),
              const SizedBox(height: 24),
            ],
            const Divider(),
            const SizedBox(height: 8),
            Text('Bereits geplante Kuchen', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            StreamBuilder<List<CakeEntry>>(
              stream: _repository.watchAllCakes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final cakes = snapshot.data!;
                if (cakes.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Noch keine Kuchen eingetragen. Sei die/der Erste!'),
                  );
                }
                return Column(
                  children: cakes
                      .map(
                        (c) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.cake_outlined),
                            title: Text(c.cakeDescription),
                            subtitle: Text('von ${c.guestName}'),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
