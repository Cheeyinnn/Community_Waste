import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class StorageService {
  // ============================================================
  // CLOUDINARY CONFIG
  // ============================================================

  static const String _cloudName = 'dp561rwx';
  static const String _uploadPreset = 'community_waste_upload';

  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  // ============================================================
  // REPORT IMAGE
  // ============================================================

  Future<String> uploadReportImage(File imageFile) async {
    try {
      return await _uploadImage(imageFile);
    } catch (e) {
      throw Exception('Report image upload failed: $e');
    }
  }

  // ============================================================
  // COLLECTOR COMPLETION IMAGE
  // ============================================================

  Future<String> uploadCompletionImage(File imageFile) async {
    try {
      return await _uploadImage(imageFile);
    } catch (e) {
      throw Exception('Completion image upload failed: $e');
    }
  }

  // ============================================================
  // PROFILE IMAGE
  // ============================================================

  Future<String> uploadProfileImage(
    String uid,
    File imageFile,
  ) async {
    try {
      return await _uploadImage(imageFile);
    } catch (e) {
      throw Exception('Profile image upload failed: $e');
    }
  }

  // ============================================================
  // PROFILE IMAGE DELETE
  // ============================================================

  Future<void> deleteProfileImage(String uid) async {
    // Cloudinary image deletion requires a signed request.
    //
    // We intentionally do NOT place the Cloudinary API Secret
    // inside the Flutter application because users could extract it.
    //
    // The profile screen can still remove the photo from the app by
    // clearing the saved profile-photo URL from Firebase.
    //
    // The old Cloudinary file may remain as an unused/orphaned asset.
    //
    // If physical deletion is required later, implement it through
    // a secure backend / Cloud Function.
    return;
  }

  // ============================================================
  // SHARED CLOUDINARY UPLOAD
  // ============================================================

  Future<String> _uploadImage(File imageFile) async {
    if (!await imageFile.exists()) {
      throw Exception('Selected image file does not exist.');
    }

    final uri = Uri.parse(_uploadUrl);

    final request = http.MultipartRequest(
      'POST',
      uri,
    );

    request.fields['upload_preset'] = _uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ),
    );

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 60),
        );

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    Map<String, dynamic>? responseData;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        responseData = decoded;
      }
    } catch (_) {
      responseData = null;
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      final errorMessage =
          responseData?['error'] is Map<String, dynamic>
              ? responseData!['error']['message']?.toString()
              : null;

      throw Exception(
        errorMessage?.trim().isNotEmpty == true
            ? errorMessage
            : 'Cloudinary upload failed '
                '(HTTP ${response.statusCode}).',
      );
    }

    final secureUrl =
        responseData?['secure_url']?.toString().trim() ?? '';

    if (secureUrl.isEmpty) {
      throw Exception(
        'Cloudinary upload succeeded but no image URL was returned.',
      );
    }

    return secureUrl;
  }
}
