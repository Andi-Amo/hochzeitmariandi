import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/wedding_photo.dart';
import 'cloudinary_service.dart';

/// Handles photo uploads (to Cloudinary) and metadata in the `photos`
/// Firestore collection. Uploaded photos appear immediately in the live
/// gallery (no moderation queue); curation (hiding/deleting) happens
/// afterwards in the admin area.
///
/// Note: image files themselves live in Cloudinary (unsigned upload), not
/// Firebase Storage — see [CloudinaryService] for why. `storagePath` on
/// [WeddingPhoto] holds the Cloudinary `public_id` for reference, but actual
/// deletion of the remote asset requires a signed Cloudinary API call (which
/// needs a server-side secret we don't have client-side), so "deleting" a
/// photo here only removes its Firestore entry — the file remains in
/// Cloudinary's free-tier storage, harmlessly unused.
class PhotoRepository {
  final CollectionReference<Map<String, dynamic>> _collection = FirebaseFirestore
      .instance
      .collection('photos');
  final CloudinaryService _cloudinary = CloudinaryService();

  Stream<List<WeddingPhoto>> watchVisiblePhotos() {
    return _collection
        .where('hidden', isEqualTo: false)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(WeddingPhoto.fromFirestore).toList());
  }

  /// Admin stream that includes hidden photos too, for curation.
  Stream<List<WeddingPhoto>> watchAllPhotosForAdmin() {
    return _collection.orderBy('uploadedAt', descending: true).snapshots().map(
      (snap) => snap.docs.map(WeddingPhoto.fromFirestore).toList(),
    );
  }

  String? _normalizeHashtag(String? hashtag) {
    final trimmed = hashtag?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final withoutWhitespace = trimmed.replaceAll(RegExp(r'\s+'), '');
    final withoutHash = withoutWhitespace.startsWith('#')
        ? withoutWhitespace.substring(1)
        : withoutWhitespace;
    if (withoutHash.isEmpty) return null;

    return '#${withoutHash.toLowerCase()}';
  }

  List<String> _normalizeHashtags(String? rawHashtags) {
    final trimmed = rawHashtags?.trim() ?? '';
    if (trimmed.isEmpty) return const [];

    final parts = trimmed.split(RegExp(r'[\s,;]+'));
    final normalized = <String>[];
    final seen = <String>{};

    for (final part in parts) {
      final hashtag = _normalizeHashtag(part);
      if (hashtag != null && seen.add(hashtag)) {
        normalized.add(hashtag);
      }
    }

    return normalized;
  }

  Future<void> uploadPhotoBytes({
    required Uint8List bytes,
    required String fileName,
    String? uploaderName,
    String? hashtagsInput,
  }) async {
    final result = await _cloudinary.uploadBytes(bytes: bytes, fileName: fileName);
    final hashtags = _normalizeHashtags(hashtagsInput);

    final photo = WeddingPhoto(
      id: '',
      url: result.secureUrl,
      storagePath: result.publicId,
      uploaderName: uploaderName,
      hashtags: hashtags,
    );
    await _collection.add(photo.toMap());
  }

  Future<void> setHidden(String photoId, bool hidden) async {
    await _collection.doc(photoId).update({'hidden': hidden});
  }

  /// Updates the hashtags of an already-uploaded photo (raw, free-form input
  /// such as "#party #standesamt" or "party, trauung").
  Future<void> updateHashtags(String photoId, String? hashtagsInput) async {
    final hashtags = _normalizeHashtags(hashtagsInput);
    await _collection.doc(photoId).update({
      'hashtag': hashtags.isEmpty ? null : hashtags.first,
      'hashtags': hashtags,
    });
  }

  Future<void> deletePhoto(WeddingPhoto photo) async {
    // Only removes the Firestore entry; see class doc comment above.
    await _collection.doc(photo.id).delete();
  }
}
