import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ============================================================
  // REPORT IMAGE
  // ============================================================

  Future<String> uploadReportImage(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('Selected image file does not exist.');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final ref = _storage.ref().child(
            'report_images/report_$timestamp',
          );

      final uploadTask = await ref.putFile(imageFile);

      return await uploadTask.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception(
        'Report image upload failed: ${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception('Report image upload failed: $e');
    }
  }

  // ============================================================
  // COLLECTOR COMPLETION IMAGE
  // ============================================================

  Future<String> uploadCompletionImage(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('Selected image file does not exist.');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final ref = _storage.ref().child(
            'completion_images/completion_$timestamp',
          );

      final uploadTask = await ref.putFile(imageFile);

      return await uploadTask.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception(
        'Completion image upload failed: ${e.message ?? e.code}',
      );
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
      if (!await imageFile.exists()) {
        throw Exception('Selected image file does not exist.');
      }

      // Fixed path so a new profile image replaces the old one.
      final ref = _storage.ref().child(
            'profile_pictures/$uid/profile_image',
          );

      final uploadTask = await ref.putFile(imageFile);

      return await uploadTask.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception(
        'Profile image upload failed: ${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception('Profile image upload failed: $e');
    }
  }

  // ============================================================
  // PROFILE IMAGE DELETE
  // ============================================================

  Future<void> deleteProfileImage(String uid) async {
    try {
      final ref = _storage.ref().child(
            'profile_pictures/$uid/profile_image',
          );

      await ref.delete();
    } on FirebaseException catch (e) {
      // If there is already no image, deletion can safely finish.
      if (e.code == 'object-not-found') {
        return;
      }

      throw Exception(
        'Profile image deletion failed: ${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception('Profile image deletion failed: $e');
    }
  }
}