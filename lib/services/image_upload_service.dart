import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ImageUploadService {
  static const String _cloudName = 'xchdbm68';
  static const String _uploadPreset = 'travelink_trips';

  /// Uploads an image to Cloudinary and returns its secure URL, or null on failure.
  static Future<String?> uploadImage(Uint8List bytes, String fileName) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) return null;
    return jsonDecode(body)['secure_url'] as String?;
  }

  /// Square 256px face-centered version of an uploaded image, for avatars.
  static String avatarUrl(String url) =>
      url.replaceFirst('/upload/', '/upload/c_fill,w_256,h_256,g_face/');
}