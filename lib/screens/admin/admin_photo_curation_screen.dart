import 'package:flutter/material.dart';

import '../../models/wedding_photo.dart';
import '../../services/cloudinary_service.dart';
import '../../services/photo_repository.dart';
import '../../widgets/home_back_button.dart';

/// Admin screen to curate the live photo gallery: hide inappropriate/
/// duplicate photos or delete them permanently.
class AdminPhotoCurationScreen extends StatelessWidget {
  const AdminPhotoCurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = PhotoRepository();

    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          leading: const HomeBackButton(),
          title: const Text('Fotos kuratieren'),
        ),
        body: StreamBuilder<List<WeddingPhoto>>(
          stream: repository.watchAllPhotosForAdmin(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final photos = snapshot.data!;
            if (photos.isEmpty) {
              return const Center(child: Text('Noch keine Fotos hochgeladen.'));
            }
            return GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: photo.hidden ? 0.3 : 1,
                      child: Image.network(
                        CloudinaryService.deliveryUrl(
                          photo.url,
                          width: 480,
                          height: 480,
                          crop: 'fill',
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(
                              color: Color(0x11000000),
                              child: Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                      ),
                    ),
                    if (photo.hashtags.isNotEmpty || photo.uploaderName != null)
                      Positioned(
                        left: 6,
                        right: 36,
                        bottom: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (photo.hashtags.isNotEmpty)
                                  Text(
                                    photo.hashtags.join(' '),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (photo.uploaderName != null)
                                  Text(
                                    photo.uploaderName!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'toggle') {
                            await repository.setHidden(photo.id, !photo.hidden);
                          } else if (value == 'delete') {
                            await repository.deletePhoto(photo);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              photo.hidden ? 'Wieder einblenden' : 'Ausblenden',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Löschen'),
                          ),
                        ],
                        child: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.black54,
                          child: Icon(
                            Icons.more_vert,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
