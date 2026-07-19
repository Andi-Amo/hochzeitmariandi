import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/program_item.dart';

/// Handles all Firestore access for the `programItems` collection.
class ProgramRepository {
  final CollectionReference<Map<String, dynamic>> _collection = FirebaseFirestore
      .instance
      .collection('programItems');

  Stream<List<ProgramItem>> watchAllItems() {
    return _collection.orderBy('createdAt', descending: true).snapshots().map(
      (snap) => snap.docs.map(ProgramItem.fromFirestore).toList(),
    );
  }

  Future<void> addItem({
    required String guestId,
    required String guestName,
    required String type,
    required String description,
  }) async {
    final item = ProgramItem(
      id: '',
      guestId: guestId,
      guestName: guestName,
      type: type,
      description: description,
    );
    await _collection.add(item.toMap());
  }

  Future<void> deleteItem(String itemId) async {
    await _collection.doc(itemId).delete();
  }
}
