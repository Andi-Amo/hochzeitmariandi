import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cake_entry.dart';

/// Handles all Firestore access for the `cakes` collection.
class CakeRepository {
  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('cakes');

  Stream<List<CakeEntry>> watchAllCakes() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CakeEntry.fromFirestore).toList());
  }

  Future<void> addCake({
    required String guestId,
    required String guestName,
    required String cakeDescription,
  }) async {
    final entry = CakeEntry(
      id: '',
      guestId: guestId,
      guestName: guestName,
      cakeDescription: cakeDescription,
    );
    await _collection.add(entry.toMap());
  }

  Future<void> updateCake(String cakeId, String cakeDescription) async {
    await _collection.doc(cakeId).update({'cakeDescription': cakeDescription});
  }

  Future<void> deleteCake(String cakeId) async {
    await _collection.doc(cakeId).delete();
  }
}
