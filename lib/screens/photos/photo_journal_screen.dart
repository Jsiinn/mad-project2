import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';

class PhotoJournalScreen extends StatefulWidget {
  const PhotoJournalScreen({super.key});

  @override
  State<PhotoJournalScreen> createState() => _PhotoJournalScreenState();
}

class _PhotoJournalScreenState extends State<PhotoJournalScreen> {
  final _storageService = StorageService();
  final _picker = ImagePicker();
  bool _blurPhotos = false;
  bool _uploading = false;

  Future<void> _pickAndUpload(String type) async {
    final auth = context.read<AuthService>();
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploading = true);

    // Use most recent workout id — in production you'd select which workout
    final workouts = await FirebaseFirestore.instance
        .collection('workouts')
        .where('uid', isEqualTo: auth.uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (workouts.docs.isEmpty) {
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log a workout first before adding photos')),
        );
      }
      return;
    }

    final workoutId = workouts.docs.first.id;
    final url = await _storageService.uploadWorkoutPhoto(
      uid: auth.uid!,
      imageFile: File(picked.path),
      workoutId: workoutId,
      type: type,
    );

    setState(() => _uploading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(url != null ? 'Photo uploaded!' : 'Upload failed — please retry'),
          backgroundColor: url != null ? const Color(0xFF0057FF) : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Journal', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Row(children: [
            const Text('Blur', style: TextStyle(color: Colors.grey, fontSize: 13)),
            Switch(
              value: _blurPhotos,
              onChanged: (v) => setState(() => _blurPhotos = v),
              activeColor: const Color(0xFF0057FF),
            ),
          ]),
        ],
      ),
      body: Column(children: [
        // Upload buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _uploading ? null : () => _pickAndUpload('pre'),
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Before Photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF0057FF)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _uploading ? null : () => _pickAndUpload('post'),
                icon: const Icon(Icons.upload_outlined),
                label: const Text('After Photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFFF3B30)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ),

        if (_uploading)
          const LinearProgressIndicator(color: Color(0xFF0057FF)),

        // Photo grid from Firestore workout docs
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('workouts')
                .where('uid', isEqualTo: auth.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              // Flatten all photo URLs from all workouts
              final allPhotos = <Map<String, dynamic>>[];
              for (final doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final photos = List<Map<String, dynamic>>.from(data['photoUrls'] ?? []);
                allPhotos.addAll(photos);
              }

              if (allPhotos.isEmpty) {
                return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No photos yet', style: TextStyle(color: Colors.white, fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Upload before & after photos to track progress',
                    style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                ]));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: allPhotos.length,
                itemBuilder: (context, i) {
                  final photo = allPhotos[i];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(fit: StackFit.expand, children: [
                      CachedNetworkImage(
                        imageUrl: photo['url'] ?? '',
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: const Color(0xFF141824),
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                        errorWidget: (_, __, ___) => Container(color: const Color(0xFF141824),
                          child: const Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                      if (_blurPhotos)
                        Container(color: Colors.black87, child: const Center(
                          child: Icon(Icons.blur_on, color: Colors.white54, size: 40))),
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: photo['type'] == 'pre'
                                ? const Color(0xFF0057FF) : const Color(0xFFFF3B30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(photo['type'] == 'pre' ? 'BEFORE' : 'AFTER',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
