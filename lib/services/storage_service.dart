import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int _maxReportImageBytes =
      10 * 1024 * 1024; // 10 MB

  static const int _maxCompletionImageBytes =
      10 * 1024 * 1024; // 10 MB

  static const int _maxProfileImageBytes =
      5 * 1024 * 1024; // 5 MB

  // ============================================================
  // COMMON HELPERS
  // ============================================================

  Future<void> _validateImageFile(
    File imageFile, {
    required int maxBytes,
    required String label,
  }) async {
    if (!await imageFile.exists()) {
      throw Exception(
        'Selected $label file does not exist.',
      );
    }

    final fileSize = await imageFile.length();

    if (fileSize <= 0) {
      throw Exception(
        'Selected $label file is empty.',
      );
    }

    if (fileSize > maxBytes) {
      final maxMb =
          (maxBytes / (1024 * 1024)).round();

      throw Exception(
        '$label must be $maxMb MB or smaller.',
      );
    }
  }

  String _contentTypeForFile(File file) {
    final path = file.path.toLowerCase();

    if (path.endsWith('.png')) {
      return 'image/png';
    }

    if (path.endsWith('.webp')) {
      return 'image/webp';
    }

    if (path.endsWith('.heic')) {
      return 'image/heic';
    }

    if (path.endsWith('.heif')) {
      return 'image/heif';
    }

    // ImagePicker camera images and most gallery images
    // are JPEG/JPG, so JPEG is the safe fallback.
    return 'image/jpeg';
  }

  SettableMetadata _imageMetadata(File file) {
    return SettableMetadata(
      contentType: _contentTypeForFile(file),
      cacheControl: 'public,max-age=3600',
    );
  }

  Future<String> _uploadImage({
    required Reference ref,
    required File imageFile,
    required int maxBytes,
    required String label,
  }) async {
    await _validateImageFile(
      imageFile,
      maxBytes: maxBytes,
      label: label,
    );

    final uploadTask = await ref.putFile(
      imageFile,
      _imageMetadata(imageFile),
    );

    return uploadTask.ref.getDownloadURL();
  }

  void _requireUid(
    String uid, {
    required String label,
  }) {
    final cleanUid = uid.trim();

    if (cleanUid.isEmpty) {
      throw Exception(
        '$label user ID is missing.',
      );
    }

    if (cleanUid.contains('/')) {
      throw Exception(
        'Invalid $label user ID.',
      );
    }
  }

  // ============================================================
  // REPORT IMAGE
  //
  // Current application path:
  //
  // report_images/report_<timestamp>
  //
  // This path is kept unchanged so it remains compatible with
  // the Storage Rules currently published in Firebase Console.
  // ============================================================

  Future<String> uploadReportImage(
    File imageFile,
  ) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception(
          'You must be logged in to upload a report image.',
        );
      }

      final timestamp =
          DateTime.now().microsecondsSinceEpoch;

      final ref = _storage.ref().child(
            'report_images/report_$timestamp',
          );

      return await _uploadImage(
        ref: ref,
        imageFile: imageFile,
        maxBytes: _maxReportImageBytes,
        label: 'report image',
      );
    } on FirebaseException catch (e) {
      throw Exception(
        'Report image upload failed: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Report image upload failed: $e',
      );
    }
  }

  // ============================================================
  // COLLECTOR COMPLETION IMAGE
  //
  // Current application path:
  //
  // completion_images/completion_<timestamp>
  //
  // This path is kept unchanged so it remains compatible with
  // the Storage Rules currently published in Firebase Console.
  // ============================================================

  Future<String> uploadCompletionImage(
    File imageFile,
  ) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception(
          'Collector must be logged in to upload completion evidence.',
        );
      }

      final timestamp =
          DateTime.now().microsecondsSinceEpoch;

      final ref = _storage.ref().child(
            'completion_images/completion_$timestamp',
          );

      return await _uploadImage(
        ref: ref,
        imageFile: imageFile,
        maxBytes: _maxCompletionImageBytes,
        label: 'completion image',
      );
    } on FirebaseException catch (e) {
      throw Exception(
        'Completion image upload failed: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Completion image upload failed: $e',
      );
    }
  }

  // ============================================================
  // PROFILE IMAGE
  //
  // Current standardized path:
  //
  // profile_pictures/<uid>/profile_image
  // ============================================================

  Future<String> uploadProfileImage(
    String uid,
    File imageFile,
  ) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception(
          'You must be logged in to upload a profile image.',
        );
      }

      final cleanUid = uid.trim();

      _requireUid(
        cleanUid,
        label: 'profile',
      );

      if (user.uid != cleanUid) {
        throw Exception(
          'You can only upload your own profile image.',
        );
      }

      final ref = _storage.ref().child(
            'profile_pictures/$cleanUid/profile_image',
          );

      return await _uploadImage(
        ref: ref,
        imageFile: imageFile,
        maxBytes: _maxProfileImageBytes,
        label: 'profile image',
      );
    } on FirebaseException catch (e) {
      throw Exception(
        'Profile image upload failed: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Profile image upload failed: $e',
      );
    }
  }

  // ============================================================
  // PROFILE IMAGE DELETE
  // ============================================================

  Future<void> deleteProfileImage(
    String uid,
  ) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception(
          'You must be logged in to delete a profile image.',
        );
      }

      final cleanUid = uid.trim();

      _requireUid(
        cleanUid,
        label: 'profile',
      );

      if (user.uid != cleanUid) {
        throw Exception(
          'You can only delete your own profile image.',
        );
      }

      final ref = _storage.ref().child(
            'profile_pictures/$cleanUid/profile_image',
          );

      await ref.delete();
    } on FirebaseException catch (e) {
      // There is nothing to clean up when the file is already gone.
      if (e.code == 'object-not-found') {
        return;
      }

      throw Exception(
        'Profile image deletion failed: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Profile image deletion failed: $e',
      );
    }
  }

  // ============================================================
  // NOTE ABOUT REPORT / COMPLETION CLEANUP
  // ============================================================
  //
  // Report and completion evidence is intentionally NOT exposed
  // through a client delete method here.
  //
  // The currently published Storage Rules make submitted
  // evidence immutable and allow Admin cleanup only. Allowing a
  // normal User or Collector to delete these files by URL would
  // weaken that evidence protection.
  //
  // In the next migration we can move new files to report-ID
  // scoped paths. That will let the app safely delete a failed
  // upload only when the matching Firestore write did not
  // succeed, without allowing submitted evidence to be removed.
  // ============================================================
}
