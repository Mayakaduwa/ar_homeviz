import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class MyGalleryScreen extends StatefulWidget {
  const MyGalleryScreen({super.key});

  @override
  State<MyGalleryScreen> createState() => _MyGalleryScreenState();
}

class _MyGalleryScreenState extends State<MyGalleryScreen> {
  List<File> _designs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalDesigns();
  }

  Future<void> _loadLocalDesigns() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final String designsPath = '${directory.path}/Designs';
      final designsDir = Directory(designsPath);

      if (await designsDir.exists()) {
        final List<FileSystemEntity> files = designsDir.listSync();
        final List<File> pngFiles = files
            .whereType<File>()
            .where((file) => file.path.endsWith('.png'))
            .toList();
        
        // Sort by date (newest first)
        pngFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        setState(() {
          _designs = pngFiles;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading gallery: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('MY DESIGNS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _designs.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _designs.length,
                  itemBuilder: (context, index) => _buildGalleryItem(_designs[index]),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 24),
          Text(
            'No designs saved yet',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('Start Designing'),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryItem(File file) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(file),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(file, fit: BoxFit.cover),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                    ),
                  ),
                  child: Text(
                    file.path.split('/').last.split('_').first, // "Design"
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(File file) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: Image.file(file)),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: ElevatedButton.icon(
                onPressed: () => _deleteDesign(file),
                icon: const Icon(Icons.delete_outline),
                label: const Text('DELETE DESIGN'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDesign(File file) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Design?', style: TextStyle(color: Colors.white)),
        content: const Text('This will permanently remove the image from your phone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await file.delete();
      Navigator.pop(context); // Close full screen
      _loadLocalDesigns(); // Refresh grid
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Design deleted')));
    }
  }
}
