import 'package:flutter_test/flutter_test.dart';
import 'package:wedapp/services/cloudinary_service.dart';

void main() {
  group('CloudinaryService.deliveryUrl', () {
    test('adds a bounded automatic image transformation', () {
      const original =
          'https://res.cloudinary.com/demo/image/upload/v123/photos/wedding.jpg';

      expect(
        CloudinaryService.deliveryUrl(
          original,
          width: 480,
          height: 480,
          crop: 'fill',
        ),
        'https://res.cloudinary.com/demo/image/upload/'
        'f_auto,q_auto,w_480,h_480,c_fill/v123/photos/wedding.jpg',
      );
    });

    test('keeps non-Cloudinary URLs unchanged', () {
      const original = 'https://example.com/photo.jpg';

      expect(
        CloudinaryService.deliveryUrl(
          original,
          width: 480,
          height: 480,
          crop: 'fill',
        ),
        original,
      );
    });

    test('creates an attachment URL with a safe download name', () {
      const original =
          'https://res.cloudinary.com/demo/image/upload/v123/photos/wedding.jpg';

      expect(
        CloudinaryService.downloadUrl(
          original,
          fileName: 'Hochzeitsfoto Sommer 2026!',
        ),
        'https://res.cloudinary.com/demo/image/upload/'
        'fl_attachment:Hochzeitsfoto_Sommer_2026_/v123/photos/wedding.jpg',
      );
    });
  });
}
