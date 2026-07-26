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
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final matches = await _repository.searchGuests(query);
      if (!mounted) return;

      if (matches.isEmpty) {
        setState(() {
          _error = 'Wir konnten dich leider nicht auf der Gästeliste finden. '
              'Bitte überprüfe die Schreibweise deines Namens.';
        });
      } else if (matches.length == 1) {
        _selectGuest(matches.first);
      } else {
        // Multiple matches found (e.g. surname search) -> show picker
        _showGuestSelectionDialog(matches);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Fehler bei der Suche. Bitte versuche es erneut.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectGuest(Guest guest) {
    context.read<GuestSession>().identify(guest);
    widget.onIdentified?.call(guest);
  }

  void _showGuestSelectionDialog(List<Guest> matches) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bitte wähle deinen Namen aus:'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: matches.length,
            itemBuilder: (ctx, index) {
              final g = matches[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(g.fullName),
                subtitle: g.groupId != null ? Text('Gruppe: ${g.groupId}') : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _selectGuest(g);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
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
            hintText: 'Vorname oder Nachname',
            prefixIcon: const Icon(Icons.person_search),
          ),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
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