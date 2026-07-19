import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/guest.dart';
import '../services/guest_repository.dart';
import '../services/guest_session.dart';

/// A reusable "who are you?" search box. On successful match it stores the
/// guest in [GuestSession] and calls [onIdentified]. Used by RSVP, the
/// hidden seating plan, cake section, and program signup.
class GuestNameSearch extends StatefulWidget {
  final String label;
  final ValueChanged<Guest>? onIdentified;

  const GuestNameSearch({super.key, this.label = 'Dein Name', this.onIdentified});

  @override
  State<GuestNameSearch> createState() => _GuestNameSearchState();
}

class _GuestNameSearchState extends State<GuestNameSearch> {
  final TextEditingController _controller = TextEditingController();
  final GuestRepository _repository = GuestRepository();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final guest = await _repository.findByName(_controller.text);
      if (!mounted) return;
      if (guest == null) {
        setState(() {
          _error = 'Wir konnten dich leider nicht auf der Gästeliste finden. '
              'Bitte überprüfe die Schreibweise deines vollen Namens.';
        });
      } else {
        context.read<GuestSession>().identify(guest);
        widget.onIdentified?.call(guest);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Vorname Nachname',
            prefixIcon: const Icon(Icons.person_search),
          ),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _search,
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Bestätigen'),
        ),
      ],
    );
  }
}
