import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/wedding_photo.dart';
import '../services/guest_session.dart';
import '../services/photo_repository.dart';
import '../widgets/back_button_widget.dart';
import '../widgets/home_back_button.dart';

/// Live photo gallery: guests can upload photos (camera or gallery, one or
/// several at once) and browse them grouped by hashtag. Hashtags can also be
/// added or edited afterwards from the full-screen photo view.
class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({super.key});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  final PhotoRepository _repository = PhotoRepository();
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;
  String _selectedHashtagFilter = _allPhotosFilter;

  static const String _allPhotosFilter = '__all__';
  static const String _untaggedPhotosFilter = '__untagged__';

  Future<void> _pickAndUploadFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    await _uploadFiles([file]);
  }

  Future<void> _pickAndUploadFromGallery() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty || !mounted) return;

    await _uploadFiles(files);
  }

  Future<void> _uploadFiles(List<XFile> files) async {
    final hashtagsInput = await _showHashtagDialog(photoCount: files.length);
    if (hashtagsInput == null || !mounted) return;

    final uploaderName = context.read<GuestSession>().guest?.fullName;
    setState(() => _uploading = true);

    try {
      for (final file in files) {
        final bytes = await file.readAsBytes();
        await _repository.uploadPhotoBytes(
          bytes: bytes,
          fileName: file.name,
          uploaderName: uploaderName,
          hashtagsInput: hashtagsInput,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              files.length > 1
                  ? '${files.length} Fotos wurden hochgeladen.'
                  : 'Foto wurde hochgeladen.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Hochladen: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<String?> _showHashtagDialog({
    required int photoCount,
    String initialText = '',
    String? titleOverride,
    String confirmLabel = 'Hochladen',
  }) async {
    final controller = TextEditingController(text: initialText);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          titleOverride ??
              (photoCount > 1
                  ? '$photoCount Fotos hochladen'
                  : 'Foto hochladen'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optional: Gib einen oder mehrere Hashtags an, damit die Fotos gemeinsam gruppiert und gefiltert werden.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Hashtags',
                hintText: '#party #standesamt oder party, trauung',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<void> _editHashtags(WeddingPhoto photo) async {
    final initialText = photo.hashtags.join(' ');
    final result = await _showHashtagDialog(
      photoCount: 1,
      initialText: initialText,
      titleOverride: 'Hashtag bearbeiten',
      confirmLabel: 'Speichern',
    );
    if (result == null || !mounted) return;

    try {
      await _repository.updateHashtags(photo.id, result);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Hashtag aktualisiert.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    }
  }

  List<_PhotoCluster> _buildClusters(List<WeddingPhoto> photos) {
    final clusters = <String, List<WeddingPhoto>>{};
    final order = <String>[];

    for (final photo in photos) {
      final key = photo.hashtag ?? '';
      if (!clusters.containsKey(key)) {
        clusters[key] = <WeddingPhoto>[];
        order.add(key);
      }
      clusters[key]!.add(photo);
    }

    return [
      for (final key in order)
        _PhotoCluster(
          title: key.isEmpty ? 'Ohne Hashtag' : key,
          photos: clusters[key]!,
        ),
    ];
  }

  List<String> _buildAvailableHashtags(List<WeddingPhoto> photos) {
    final hashtags = <String>{};
    for (final photo in photos) {
      hashtags.addAll(photo.hashtags);
    }
    final result = hashtags.toList()..sort();
    return result;
  }

  List<WeddingPhoto> _filterPhotos(List<WeddingPhoto> photos) {
    if (_selectedHashtagFilter == _allPhotosFilter) {
      return photos;
    }
    if (_selectedHashtagFilter == _untaggedPhotosFilter) {
      return photos.where((photo) => photo.hashtags.isEmpty).toList();
    }
    return photos
        .where((photo) => photo.hashtags.contains(_selectedHashtagFilter))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          leading: const HomeBackButton(),
          title: const Text('Fotogalerie'),
        ),
        floatingActionButton: _uploading
            ? const FloatingActionButton(
                onPressed: null,
                child: CircularProgressIndicator(color: Colors.white),
              )
            : FloatingActionButton.extended(
                onPressed: () => _showUploadOptions(context),
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Fotos hochladen'),
              ),
        body: StreamBuilder<List<WeddingPhoto>>(
          stream: _repository.watchVisiblePhotos(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final photos = snapshot.data!;
            final availableHashtags = _buildAvailableHashtags(photos);
            final filteredPhotos = _filterPhotos(photos);
            final clusters = _buildClusters(filteredPhotos);

            return Column(
              children: [
                if (photos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Alle'),
                            selected: _selectedHashtagFilter == _allPhotosFilter,
                            onSelected: (_) {
                              setState(() {
                                _selectedHashtagFilter = _allPhotosFilter;
                              });
                            },
                          ),
                          if (photos.any((photo) => photo.hashtags.isEmpty))
                            ChoiceChip(
                              label: const Text('Ohne Hashtag'),
                              selected:
                                  _selectedHashtagFilter == _untaggedPhotosFilter,
                              onSelected: (_) {
                                setState(() {
                                  _selectedHashtagFilter = _untaggedPhotosFilter;
                                });
                              },
                            ),
                          for (final hashtag in availableHashtags)
                            ChoiceChip(
                              label: Text(hashtag),
                              selected: _selectedHashtagFilter == hashtag,
                              onSelected: (_) {
                                setState(() {
                                  _selectedHashtagFilter = hashtag;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: photos.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Noch keine Fotos. Sei die/der Erste und teile einen Schnappschuss!',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : filteredPhotos.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Keine Fotos mit diesem Hashtag gefunden.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: clusters.length,
                          itemBuilder: (context, index) {
                            final cluster = clusters[index];
                            return _PhotoClusterSection(
                              cluster: cluster,
                              onPhotoTap: (photo) => _showFullPhoto(context, photo),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: const BackButtonWidget(),
                ),
              ],
            );
          },
        ),
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
                _pickAndUploadFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Fotos aus Galerie wählen'),
              subtitle: const Text('Ein oder mehrere Fotos auswählen'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAndUploadFromGallery();
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: Image.network(photo.url, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (photo.hashtags.isNotEmpty || photo.uploaderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final hashtag in photo.hashtags)
                            Chip(label: Text(hashtag)),
                          if (photo.uploaderName != null)
                            Chip(
                              avatar: const Icon(Icons.person, size: 18),
                              label: Text(photo.uploaderName!),
                            ),
                        ],
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _editHashtags(photo);
                    },
                    icon: const Icon(Icons.tag),
                    label: Text(
                      photo.hashtags.isEmpty
                          ? 'Hashtag hinzufügen'
                          : 'Hashtag bearbeiten',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCluster {
  final String title;
  final List<WeddingPhoto> photos;

  const _PhotoCluster({
    required this.title,
    required this.photos,
  });
}

class _PhotoClusterSection extends StatelessWidget {
  final _PhotoCluster cluster;
  final ValueChanged<WeddingPhoto> onPhotoTap;

  const _PhotoClusterSection({
    required this.cluster,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  cluster.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${cluster.photos.length})',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: cluster.photos.length,
            itemBuilder: (context, index) {
              final photo = cluster.photos[index];
              return GestureDetector(
                onTap: () => onPhotoTap(photo),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(photo.url, fit: BoxFit.cover),
                      if (photo.hashtag != null)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                photo.hashtag!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
