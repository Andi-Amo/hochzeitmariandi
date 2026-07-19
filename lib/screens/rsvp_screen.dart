import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/guest.dart';
import '../services/guest_repository.dart';
import '../services/guest_session.dart';
import '../widgets/guest_name_search.dart';

/// RSVP flow: guest identifies themselves by name, then submits attendance,
/// plus-ones, and dietary notes.
class RsvpScreen extends StatefulWidget {
  const RsvpScreen({super.key});

  @override
  State<RsvpScreen> createState() => _RsvpScreenState();
}

class _RsvpScreenState extends State<RsvpScreen> {
  final GuestRepository _repository = GuestRepository();
  String _status = 'attending';
  int _plusOnes = 0;
  final TextEditingController _notesController = TextEditingController();
  bool _saving = false;
  bool _saved = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit(Guest guest) async {
    setState(() => _saving = true);
    try {
      await _repository.updateRsvp(
        guestId: guest.id,
        rsvpStatus: _status,
        plusOnes: _plusOnes,
        dietaryNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (mounted) setState(() => _saved = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guest = context.watch<GuestSession>().guest;

    return Scaffold(
      appBar: AppBar(title: const Text('Auf Einladung antworten')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: guest == null
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bitte gib deinen Namen ein, damit wir deine Einladung finden.',
                    ),
                    const SizedBox(height: 16),
                    const GuestNameSearch(),
                  ],
                ),
              )
            : _saved
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 64),
                        const SizedBox(height: 16),
                        Text('Danke, ${guest.firstName}! Deine Antwort wurde gespeichert.'),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      Text(
                        'Hallo ${guest.fullName}!',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'attending', label: Text('Ich komme')),
                          ButtonSegment(value: 'declined', label: Text('Ich kann leider nicht')),
                        ],
                        selected: {_status},
                        onSelectionChanged: (s) => setState(() => _status = s.first),
                      ),
                      const SizedBox(height: 16),
                      if (_status == 'attending') ...[
                        Text('Anzahl Begleitpersonen', style: Theme.of(context).textTheme.titleMedium),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _plusOnes > 0 ? () => setState(() => _plusOnes--) : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('$_plusOnes', style: const TextStyle(fontSize: 18)),
                            IconButton(
                              onPressed: () => setState(() => _plusOnes++),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Allergien / Essenswünsche (optional)',
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ElevatedButton(
                        onPressed: _saving ? null : () => _submit(guest),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Antwort absenden'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
