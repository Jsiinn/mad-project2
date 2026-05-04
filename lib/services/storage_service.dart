import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  /// Upload a pre/post workout photo scoped to the user's UID
  /// Path: /users/{uid}/photos/{filename}
  /// Returns the download URL stored in Firestore
  Future<String?> uploadWorkoutPhoto({
    required String uid,
    required File imageFile,
    required String workoutId,
    required String type, // 'pre' or 'post'
  }) async {
    try {
      final filename = '${type}_${_uuid.v4()}.jpg';
      // UID-scoped path prevents cross-user access (enforced by Storage rules)
      final ref = _storage.ref('users/$uid/photos/$filename');

      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snap) {
        final progress = snap.bytesTransferred / snap.totalBytes;
        debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Persist download URL to the workout Firestore document
      await _db.collection('workouts').doc(workoutId).update({
        'photoUrls': FieldValue.arrayUnion([
          {'type': type, 'url': downloadUrl, 'uploadedAt': DateTime.now().toIso8601String()}
        ]),
      });

      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint('Storage upload failed: ${e.code} - ${e.message}');
      return null;
    }
  }

  /// Upload user avatar — stored at /users/{uid}/avatar.jpg
  Future<String?> uploadAvatar({
    required String uid,
    required File imageFile,
  }) async {
    try {
      final ref = _storage.ref('users/$uid/avatar.jpg');
      await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();

      await _db.collection('users').doc(uid).update({'avatarUrl': url});
      return url;
    } on FirebaseException catch (e) {
      debugPrint('Avatar upload failed: $e');
      return null;
    }
  }

  /// Delete a photo from Storage — used for cleanup on orphaned uploads
  Future<void> deletePhoto(String uid, String filename) async {
    try {
      await _storage.ref('users/$uid/photos/$filename').delete();
    } catch (e) {
      debugPrint('Delete failed: $e');
    }
  }
}
