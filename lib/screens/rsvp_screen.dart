import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/guest.dart';
import '../services/guest_repository.dart';
import '../services/guest_session.dart';

/// Reformed RSVP Flow with First/Last name matching, family group loading,
/// clear Adult/Child dropdowns, and interactive +1 registration.
class RsvpScreen extends StatefulWidget {
  const RsvpScreen({super.key});

  @override
  State<RsvpScreen> createState() => _RsvpScreenState();
}

class _RsvpScreenState extends State<RsvpScreen> {
  final GuestRepository _repository = GuestRepository();

  // Search controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  // State
  bool _isSearching = false;
  List<Guest> _groupGuests = [];
  List<Guest> _suggestedGuests = [];
  bool _noMatchFound = false;

  // Track state per guest ID in the group
  final Map<String, _GuestRsvpFormState> _formStates = {};

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  // Calculate simple string distance for "Did you mean?" suggestions
  int _levenshteinDistance(String s1, String s2) {
    s1 = s1.toLowerCase().trim();
    s2 = s2.toLowerCase().trim();
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[s2.length];
  }

  Future<void> _performSearch() async {
    final fn = _firstNameController.text.trim();
    final ln = _lastNameController.text.trim();

    if (fn.isEmpty && ln.isEmpty) return;

    setState(() {
      _isSearching = true;
      _noMatchFound = false;
      _suggestedGuests.clear();
      _groupGuests.clear();
    });

    try {
      final allGuests = await _repository.fetchAllGuests();

      // 1. Try Exact Match (Case-insensitive)
      final exactMatches = allGuests.where((g) {
        final matchFn = fn.isEmpty || g.firstName.toLowerCase() == fn.toLowerCase();
        final matchLn = ln.isEmpty || g.lastName.toLowerCase() == ln.toLowerCase();
        return matchFn && matchLn;
      }).toList();

      if (exactMatches.isNotEmpty) {
        final matchedGuest = exactMatches.first;
        context.read<GuestSession>().identify(matchedGuest);

        // Fetch all guests in the same family / household group if groupId exists
        if (matchedGuest.groupId != null && matchedGuest.groupId!.isNotEmpty) {
          _groupGuests = allGuests.where((g) => g.groupId == matchedGuest.groupId).toList();
        } else {
          _groupGuests = [matchedGuest];
        }

        _initFormStates(_groupGuests);
      } else {
        // 2. Fuzzy Match / Smart Suggestions
        final searchString = '$fn $ln'.trim();
        final sorted = List<Guest>.from(allGuests)
          ..sort((a, b) {
            final scoreA = _levenshteinDistance(searchString, '${a.firstName} ${a.lastName}');
            final scoreB = _levenshteinDistance(searchString, '${b.firstName} ${b.lastName}');
            return scoreA.compareTo(scoreB);
          });

        _suggestedGuests = sorted.take(3).toList();
        _noMatchFound = true;
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectGuestFromSuggestions(Guest guest) async {
    _firstNameController.text = guest.firstName;
    _lastNameController.text = guest.lastName;
    await _performSearch();
  }

  void _initFormStates(List<Guest> guests) {
    for (var g in guests) {
      _formStates[g.id] = _GuestRsvpFormState(
        status: g.rsvpStatus ?? 'attending',
        isChild: g.isChild,
        childAgeController: TextEditingController(text: g.childAge != null ? '${g.childAge}' : ''),
        notesController: TextEditingController(text: g.dietaryNotes ?? ''),
        hasPlusOne: g.plusOnes > 0,
        plusOneFirstNameController: TextEditingController(),
        plusOneLastNameController: TextEditingController(),
        plusOneIsChild: false,
      );
    }
  }

  Future<void> _submitAll() async {
    for (var entry in _formStates.entries) {
      final guestId = entry.key;
      final form = entry.value;

      final age = int.tryParse(form.childAgeController.text.trim());
      
      // Calculate plusOne count (1 if enabled, 0 if disabled)
      final plusOneCount = form.hasPlusOne ? 1 : 0;

      await _repository.updateRsvp(
        guestId: guestId,
        rsvpStatus: form.status,
        plusOnes: plusOneCount,
        dietaryNotes: form.notesController.text.trim().isEmpty ? null : form.notesController.text.trim(),
        isChild: form.isChild,
        childAge: form.isChild ? age : null,
      );
    }

    if (mounted) {
      setState(() {
        for (var f in _formStates.values) {
          f.isSaved = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeGuest = context.watch<GuestSession>().guest;

    return Scaffold(
      appBar: AppBar(title: const Text('Auf Einladung antworten')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: activeGuest == null || _groupGuests.isEmpty
            ? _buildSearchSection()
            : _buildRsvpFormSection(),
      ),
    );
  }

  // --- Search Section ---
  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bitte gib deinen Vor- und Nachnamen ein, damit wir deine Einladung finden.',
          style: TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Vorname',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Nachname',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSearching ? null : _performSearch,
            icon: _isSearching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: const Text('Einladung suchen'),
          ),
        ),
        if (_noMatchFound) ...[
          const SizedBox(height: 24),
          const Text(
            'Kein genauer Treffer gefunden. Meintest du einen dieser Namen?',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._suggestedGuests.map(
            (g) => Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('${g.firstName} ${g.lastName}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _selectGuestFromSuggestions(g),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // --- Multi-Guest / Family RSVP Section ---
  Widget _buildRsvpFormSection() {
    final allSaved = _formStates.values.every((f) => f.isSaved);

    if (allSaved) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.check_circle, color: Colors.green, size: 72),
            const SizedBox(height: 16),
            const Text(
              'Vielen Dank! Deine Antworten wurden gespeichert. 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  _groupGuests.clear();
                  context.read<GuestSession>().clear();
                });
              },
              child: const Text('Andere Einladung suchen'),
            )
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_groupGuests.length > 1) ...[
          Text(
            'Familien-/Gruppeneinladung',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text('Du kannst hier für alle Personen deiner Gruppe antworten:'),
          const SizedBox(height: 16),
        ],
        ..._groupGuests.map((guest) => _buildSingleGuestCard(guest)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _submitAll,
            child: const Text('Alle Antworten absenden'),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleGuestCard(Guest guest) {
    final form = _formStates[guest.id]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${guest.firstName} ${guest.lastName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Attending / Declined Segmented Button
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'attending', label: Text('Ich komme')),
                ButtonSegment(value: 'declined', label: Text('Ich kann leider nicht')),
              ],
              selected: {form.status},
              onSelectionChanged: (s) => setState(() => form.status = s.first),
            ),

            if (form.status == 'attending') ...[
              const SizedBox(height: 16),

              // Adult / Child Dropdown
              DropdownButtonFormField<bool>(
                value: form.isChild,
                decoration: const InputDecoration(
                  labelText: 'Ich bin',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: false, child: Text('Erwachsen')),
                  DropdownMenuItem(value: true, child: Text('Kind')),
                  DropdownMenuItem(value: true, child: Text('Geistlich Kind geblieben esse aber wie ein Erwachsener')),
                ],
                onChanged: (val) => setState(() => form.isChild = val ?? false),
              ),

              if (form.isChild) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: form.childAgeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Alter des Kindes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Plus-One Line & Toggle Button
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Ich möchte eine Begleitperson anmelden (+1)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Switch(
                          value: form.hasPlusOne,
                          onChanged: (val) => setState(() => form.hasPlusOne = val),
                        ),
                      ],
                    ),
                    if (form.hasPlusOne) ...[
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: form.plusOneFirstNameController,
                              decoration: const InputDecoration(
                                labelText: 'Vorname Begleitung',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: form.plusOneLastNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nachname Begleitung',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<bool>(
                        value: form.plusOneIsChild,
                        decoration: const InputDecoration(
                          labelText: 'Begleitperson ist ein...',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: false, child: Text('Erwachsen')),
                          DropdownMenuItem(value: true, child: Text('Kind')),
                        ],
                        onChanged: (v) => setState(() => form.plusOneIsChild = v ?? false),
                      ),
                    ]
                  ],
                ),
              ),

              const SizedBox(height: 12),
              TextField(
                controller: form.notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Allergien / Unverträglichkeiten / Essenswünsche',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Helper state container for each individual guest in a family group
class _GuestRsvpFormState {
  String status;
  bool isChild;
  TextEditingController childAgeController;
  TextEditingController notesController;

  bool hasPlusOne;
  TextEditingController plusOneFirstNameController;
  TextEditingController plusOneLastNameController;
  bool plusOneIsChild;

  bool isSaved = false;

  _GuestRsvpFormState({
    required this.status,
    required this.isChild,
    required this.childAgeController,
    required this.notesController,
    required this.hasPlusOne,
    required this.plusOneFirstNameController,
    required this.plusOneLastNameController,
    required this.plusOneIsChild,
  });
}