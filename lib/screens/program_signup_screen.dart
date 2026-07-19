import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/guest.dart';
import '../services/guest_session.dart';
import '../services/program_repository.dart';
import '../widgets/guest_name_search.dart';

/// Simple signup form for guests who want to hold a speech, show a
/// slideshow, or contribute another program item.
class ProgramSignupScreen extends StatefulWidget {
  const ProgramSignupScreen({super.key});

  @override
  State<ProgramSignupScreen> createState() => _ProgramSignupScreenState();
}

class _ProgramSignupScreenState extends State<ProgramSignupScreen> {
  final ProgramRepository _repository = ProgramRepository();
  final TextEditingController _descriptionController = TextEditingController();
  String _type = 'Rede';
  bool _submitted = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit(Guest guest) async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) return;
    await _repository.addItem(
      guestId: guest.id,
      guestName: guest.fullName,
      type: _type,
      description: description,
    );
    if (mounted) setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    final guest = context.watch<GuestSession>().guest;

    return Scaffold(
      appBar: AppBar(title: const Text('Rede / Programmpunkt anmelden')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: guest == null
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Möchtest du eine Rede halten, eine Diashow zeigen, oder '
                      'einen anderen Programmpunkt beitragen? Gib zuerst deinen '
                      'Namen ein.',
                    ),
                    const SizedBox(height: 16),
                    const GuestNameSearch(),
                  ],
                ),
              )
            : _submitted
                ? const Center(
                    child: Text('Danke für deine Anmeldung! Wir freuen uns darauf. 🎉'),
                  )
                : ListView(
                    children: [
                      Text(
                        'Hallo ${guest.fullName}!',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: 'Art des Beitrags'),
                        items: const [
                          DropdownMenuItem(value: 'Rede', child: Text('Rede')),
                          DropdownMenuItem(value: 'Diashow', child: Text('Diashow')),
                          DropdownMenuItem(value: 'Sonstiges', child: Text('Sonstiger Programmpunkt')),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? 'Rede'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Kurze Beschreibung (was hast du geplant?)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _submit(guest),
                        child: const Text('Anmelden'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
