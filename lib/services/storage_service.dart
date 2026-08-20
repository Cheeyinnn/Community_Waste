import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadReportImage(File imageFile) async {
    try {
      final String fileName =
          'report_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final Reference ref = _storage
          .ref()
          .child('report_images')
          .child(fileName);

      await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));

      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Report image upload failed: $e');
    }
  }

  Future<String> uploadCompletionImage(File imageFile) async {
    try {
      final String fileName =
          'completion_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final Reference ref = _storage
          .ref()
          .child('completion_images')
          .child(fileName);

      await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));

      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Completion image upload failed: $e');
    }
  }

  Future<String> uploadProfileImage(String uid, File imageFile) async {
    try {
      final Reference ref = _storage
          .ref()
          .child('profile_pictures')
          .child('$uid.jpg');

      await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));

      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Profile image upload failed: $e');
    }
  }

  Future<void> deleteProfileImage(String uid) async {
    try {
      final Reference ref = _storage
          .ref()
          .child('profile_pictures')
          .child('$uid.jpg');

      await ref.delete();
    } catch (e) {
      throw Exception('Profile image delete failed: $e');
    }
  }
}
