import 'package:cloud_firestore/cloud_firestore.dart';

/// A photo uploaded to the live gallery, stored in the `photos` collection.
class WeddingPhoto {
  final String id;
  final String url;
  final String storagePath;
  final DateTime? uploadedAt;
  final String? uploaderName;
  final List<String> hashtags;
  final bool hidden;

  const WeddingPhoto({
    required this.id,
    required this.url,
    required this.storagePath,
    this.uploadedAt,
    this.uploaderName,
    this.hashtags = const [],
    this.hidden = false,
  });

  String? get hashtag => hashtags.isEmpty ? null : hashtags.first;

  factory WeddingPhoto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final ts = data['uploadedAt'];
    final rawHashtags = data['hashtags'];
    final legacyHashtag = data['hashtag'] as String?;
    final hashtags = rawHashtags is List
        ? rawHashtags.whereType<String>().toList()
        : legacyHashtag == null || legacyHashtag.isEmpty
        ? <String>[]
        : <String>[legacyHashtag];
    return WeddingPhoto(
      id: doc.id,
      url: data['url'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      uploadedAt: ts is Timestamp ? ts.toDate() : null,
      uploaderName: data['uploaderName'] as String?,
      hashtags: hashtags,
      hidden: data['hidden'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'storagePath': storagePath,
      'uploadedAt': FieldValue.serverTimestamp(),
      'uploaderName': uploaderName,
      'hashtag': hashtag,
      'hashtags': hashtags,
      'hidden': hidden,
    };
  }
}
