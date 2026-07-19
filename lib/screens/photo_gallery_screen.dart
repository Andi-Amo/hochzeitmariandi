import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/wedding_photo.dart';
import '../services/guest_session.dart';
import '../services/photo_repository.dart';

/// Live photo gallery: guests can upload photos (from gallery or straight
/// from the camera) and see everyone's uploads immediately in a grid.
class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({super.key});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  final PhotoRepository _repository = PhotoRepository();
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;

  Future<void> _pickAndUpload(ImageSource source) async {
    final XFile? file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;

    final uploaderName = context.read<GuestSession>().guest?.fullName;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      await _repository.uploadPhotoBytes(
        bytes: bytes,
        fileName: file.name,
        uploaderName: uploaderName,
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fotogalerie')),
      floatingActionButton: _uploading
          ? const FloatingActionButton(
              onPressed: null,
              child: CircularProgressIndicator(color: Colors.white),
            )
          : FloatingActionButton.extended(
              onPressed: () => _showUploadOptions(context),
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Foto hochladen'),
            ),
      body: StreamBuilder<List<WeddingPhoto>>(
        stream: _repository.watchVisiblePhotos(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final photos = snapshot.data!;
          if (photos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Noch keine Fotos. Sei die/der Erste und teile einen Schnappschuss!',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              return GestureDetector(
                onTap: () => _showFullPhoto(context, photo),
                child: Image.network(photo.url, fit: BoxFit.cover),
              );
            },
          );
        },
      ),
    );
  }

  void _showUploadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Foto aufnehmen'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAndUpload(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Aus Galerie wählen'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAndUpload(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFullPhoto(BuildContext context, WeddingPhoto photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(child: Image.network(photo.url)),
      ),
    );
  }
}
