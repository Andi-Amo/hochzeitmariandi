import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'cloudinary_config.dart';

/// Result of a successful Cloudinary upload.
class CloudinaryUploadResult {
  final String secureUrl;
  final String publicId;

  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
  });
}

/// Uploads image bytes to Cloudinary using an unsigned upload preset (see
/// [CloudinaryConfig] for setup instructions). Used instead of Firebase
/// Storage, which requires the paid Blaze plan.
class CloudinaryService {
  static String _transformedUrl(String originalUrl, String transformation) {
    final uri = Uri.tryParse(originalUrl);
    if (uri == null ||
        !uri.host.endsWith('cloudinary.com') ||
        !uri.path.contains('/upload/')) {
      return originalUrl;
    }

    return uri
        .replace(
          path: uri.path.replaceFirst('/upload/', '/upload/$transformation/'),
        )
        .toString();
  }

  static String deliveryUrl(
    String originalUrl, {
    required int width,
    required int height,
    required String crop,
  }) {
    final transformation = 'f_auto,q_auto,w_$width,h_$height,c_$crop';
    return _transformedUrl(originalUrl, transformation);
  }

  static String downloadUrl(String originalUrl, {required String fileName}) {
    final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return _transformedUrl(originalUrl, 'fl_attachment:$safeFileName');
  }

  Future<CloudinaryUploadResult> uploadBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/auto/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.unsignedUploadPreset
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      throw Exception(
        'Cloudinary upload failed (${streamedResponse.statusCode}): $responseBody',
      );
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    return CloudinaryUploadResult(
      secureUrl: json['secure_url'] as String,
      publicId: json['public_id'] as String,
    );
  }
}
