import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadReportImage(File imageFile) async {
    try {
      final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = _storage.ref().child('report_images').child(fileName);

      await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Image upload failed: $e');
    }
  }
}