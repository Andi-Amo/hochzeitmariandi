import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/guest.dart';

/// Handles all Firestore access for the `guests` collection.
class GuestRepository {
  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('guests');

  Future<List<Guest>> fetchAllGuests() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map(Guest.fromFirestore).toList();
  }

  Stream<List<Guest>> watchAllGuests() {
    return _collection.snapshots().map(
      (snap) => snap.docs.map(Guest.fromFirestore).toList(),
    );
  }

  /// Fetches all guests belonging to the same household or family group.
  Future<List<Guest>> fetchGuestsByGroup(String groupId) async {
    if (groupId.trim().isEmpty) return [];

    final querySnapshot = await _collection
        .where('groupId', isEqualTo: groupId)
        .get();

    return querySnapshot.docs.map(Guest.fromFirestore).toList();
  }

  /// Alias for fetchGuestsByGroup for backwards compatibility
  Future<List<Guest>> fetchGuestsByGroupId(String groupId) async {
    return fetchGuestsByGroup(groupId);
  }

  /// Searches for guests matching the query.
  /// Returns ALL matching guests if multiple exist (e.g. searching "Schmidt"
  /// returns all Schmidts, or searching "Anna" returns all Annas).
  Future<List<Guest>> searchGuests(String query) async {
    final normalizedQuery = query.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (normalizedQuery.isEmpty) return [];

    final allGuests = await fetchAllGuests();
    final matches = <Guest>[];

    for (final guest in allGuests) {
      final normFirst = guest.firstName.trim().toLowerCase();
      final normLast = guest.lastName.trim().toLowerCase();
      final normFull = guest.normalizedName;

      // Match exact full name, or if query is contained in first/last/full name
      if (normFull == normalizedQuery ||
          normFirst == normalizedQuery ||
          normLast == normalizedQuery ||
          normFirst.contains(normalizedQuery) ||
          normLast.contains(normalizedQuery)) {
        matches.add(guest);
      }
    }

    return matches;
  }

  /// Finds a single guest by name matching (fallback)
  Future<Guest?> findByName(String query) async {
    final results = await searchGuests(query);
    return results.isNotEmpty ? results.first : null;
  }

  /// One-time batch script to backfill `groupId` (set to null if missing)
  /// across all existing documents in Firestore.
  Future<void> backfillGroupIdToAllGuests() async {
    final snapshot = await _collection.get();
    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      if (!doc.data().containsKey('groupId')) {
        batch.update(doc.reference, {'groupId': null});
      }
    }

    await batch.commit();
  }

  /// Updates the RSVP status for an existing guest document.
  Future<void> updateRsvp({
    required String guestId,
    required String rsvpStatus,
    required int plusOnes,
    String? dietaryNotes,
    bool isChild = false,
    int? childAge,
  }) async {
    final updateData = <String, dynamic>{
      'rsvpStatus': rsvpStatus,
      'plusOnes': plusOnes,
      'dietaryNotes': dietaryNotes,
      'isChild': isChild,
      'childAge': isChild ? childAge : null,
    };

    if (rsvpStatus == 'declined') {
      updateData['tableId'] = null;
      updateData['seat'] = null;
    }

    await _collection.doc(guestId).update(updateData);
  }

  /// Creates and saves a new +1 companion directly linked to a primary guest's group.
  Future<DocumentReference> addPlusOneGuest({
    required String primaryGuestId,
    required String? groupId,
    required String firstName,
    required String lastName,
    required bool isChild,
  }) async {
    // Fall back to primaryGuestId as the groupId if no group exists yet
    final effectiveGroupId = (groupId != null && groupId.isNotEmpty)
        ? groupId
        : primaryGuestId;

    final companionMap = {
      'firstName': firstName.trim().isEmpty ? 'Begleitung' : firstName.trim(),
      'lastName': lastName.trim().isEmpty ? '' : lastName.trim(),
      'rsvpStatus': 'attending',
      'groupId': effectiveGroupId,
      'isChild': isChild,
      'plusOnes': 0,
      'dietaryNotes': null,
      'isPlusOneOf': primaryGuestId, // Reference to primary guest
    };

    return await _collection.add(companionMap);
  }

  /// Adds or overwrites a guest document.
  Future<void> addGuest(Guest guest) async {
    if (guest.id.isEmpty) {
      await _collection.add(guest.toMap());
    } else {
      await _collection.doc(guest.id).set(guest.toMap());
    }
  }

  /// Creates a guest document and returns the reference.
  Future<DocumentReference> createGuest(Guest guest) async {
    if (guest.id.isEmpty) {
      return await _collection.add(guest.toMap());
    } else {
      final docRef = _collection.doc(guest.id);
      await docRef.set(guest.toMap());
      return docRef;
    }
  }

  Future<void> updateGuest(Guest guest) async {
    await _collection.doc(guest.id).update(guest.toMap());
  }

  Future<void> deleteGuest(String guestId) async {
    await _collection.doc(guestId).delete();
  }
}
