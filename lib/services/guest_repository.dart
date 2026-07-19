import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/guest.dart';

/// Handles all Firestore access for the `guests` collection.
class GuestRepository {
  final CollectionReference<Map<String, dynamic>> _collection = FirebaseFirestore
      .instance
      .collection('guests');

  Future<List<Guest>> fetchAllGuests() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map(Guest.fromFirestore).toList();
  }

  Stream<List<Guest>> watchAllGuests() {
    return _collection.snapshots().map(
      (snap) => snap.docs.map(Guest.fromFirestore).toList(),
    );
  }

  /// Finds a guest by matching first + last name (case/whitespace-insensitive).
  /// Returns null if no unique match is found.
  Future<Guest?> findByName(String query) async {
    final normalizedQuery = query.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (normalizedQuery.isEmpty) return null;

    final guests = await fetchAllGuests();
    for (final guest in guests) {
      if (guest.normalizedName == normalizedQuery) {
        return guest;
      }
    }
    return null;
  }

  Future<void> updateRsvp({
    required String guestId,
    required String rsvpStatus,
    required int plusOnes,
    String? dietaryNotes,
    bool isChild = false,
    int? childAge,
  }) async {
    await _collection.doc(guestId).update({
      'rsvpStatus': rsvpStatus,
      'plusOnes': plusOnes,
      'dietaryNotes': dietaryNotes,
      'isChild': isChild,
      'childAge': isChild ? childAge : null,
    });
  }

  Future<void> addGuest(Guest guest) async {
    await _collection.doc(guest.id.isEmpty ? null : guest.id).set(
      guest.toMap(),
    );
  }

  Future<void> updateGuest(Guest guest) async {
    await _collection.doc(guest.id).update(guest.toMap());
  }

  Future<void> deleteGuest(String guestId) async {
    await _collection.doc(guestId).delete();
  }
}
