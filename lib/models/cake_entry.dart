import 'package:cloud_firestore/cloud_firestore.dart';

/// A cake pledged by a guest, stored in the `cakes` collection.
class CakeEntry {
  final String id;
  final String guestId;
  final String guestName;
  final String cakeDescription;
  final DateTime? createdAt;

  const CakeEntry({
    required this.id,
    required this.guestId,
    required this.guestName,
    required this.cakeDescription,
    this.createdAt,
  });

  factory CakeEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['createdAt'];
    return CakeEntry(
      id: doc.id,
      guestId: data['guestId'] as String? ?? '',
      guestName: data['guestName'] as String? ?? '',
      cakeDescription: data['cakeDescription'] as String? ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'guestId': guestId,
      'guestName': guestName,
      'cakeDescription': cakeDescription,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
