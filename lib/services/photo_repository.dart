import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/wedding_photo.dart';

/// Handles photo uploads to Firebase Storage and metadata in the
/// `photos` collection. Uploaded photos appear immediately in the live
/// gallery (no moderation queue); curation (hiding/deleting) happens
/// afterwards in the admin area.
class PhotoRepository {
  final CollectionReference<Map<String, dynamic>> _collection = FirebaseFirestore
      .instance
      .collection('photos');
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

  Future<void> uploadPhotoBytes({
    required Uint8List bytes,
    required String fileName,
    String? uploaderName,
  }) async {
    final storagePath = 'photos/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref(storagePath);
    await ref.putData(bytes);
    final url = await ref.getDownloadURL();

    final photo = WeddingPhoto(
      id: '',
      url: url,
      storagePath: storagePath,
      uploaderName: uploaderName,
    );
    await _collection.add(photo.toMap());
  }

  Future<void> setHidden(String photoId, bool hidden) async {
    await _collection.doc(photoId).update({'hidden': hidden});
  }

  Future<void> deletePhoto(WeddingPhoto photo) async {
    await _collection.doc(photo.id).delete();
    try {
      await _storage.ref(photo.storagePath).delete();
    } catch (_) {
      // Storage object may already be gone; ignore.
    }
  }
}
