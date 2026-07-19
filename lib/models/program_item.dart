import 'package:cloud_firestore/cloud_firestore.dart';

/// A signup for a speech / slideshow / other program item, stored in the
/// `programItems` collection.
class ProgramItem {
  final String id;
  final String guestId;
  final String guestName;
  final String type; // e.g. 'Rede', 'Diashow', 'Sonstiges'
  final String description;
  final DateTime? createdAt;

  const ProgramItem({
    required this.id,
    required this.guestId,
    required this.guestName,
    required this.type,
    required this.description,
    this.createdAt,
  });

  factory ProgramItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final ts = data['createdAt'];
    return ProgramItem(
      id: doc.id,
      guestId: data['guestId'] as String? ?? '',
      guestName: data['guestName'] as String? ?? '',
      type: data['type'] as String? ?? 'Sonstiges',
      description: data['description'] as String? ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'guestId': guestId,
      'guestName': guestName,
      'type': type,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
