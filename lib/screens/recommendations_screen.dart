import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'ar_view_screen.dart';

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  static const Map<String, List<Map<String, dynamic>>> _expertPalettes = {
    'Living Room': [
      {'name': 'Modern Minimal', 'colors': [0xFFF1F5F9, 0xFF94A3B8, 0xFF475569, 0xFF1E293B], 'mood': 'Calm'},
      {'name': 'Urban Warmth', 'colors': [0xFFFEF3C7, 0xFFF59E0B, 0xFFB45309, 0xFF78350F], 'mood': 'Cozy'},
    ],
    'Bedroom': [
      {'name': 'Serene Sky', 'colors': [0xFFE0F2FE, 0xFF7DD3FC, 0xFF0EA5E9, 0xFF0369A1], 'mood': 'Relaxing'},
      {'name': 'Sage Sanctuary', 'colors': [0xFFF0FDF4, 0xFF86EFAC, 0xFF22C55E, 0xFF15803D], 'mood': 'Natural'},
    ],
    'Office': [
      {'name': 'Deep Focus', 'colors': [0xFFF8FAFC, 0xFFCBD5E1, 0xFF334155, 0xFF0F172A], 'mood': 'Professional'},
      {'name': 'Creative Spark', 'colors': [0xFFFFF7ED, 0xFFFDBA74, 0xFFF97316, 0xFFC2410C], 'mood': 'Energetic'},
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('COLOR PALETTES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: _expertPalettes.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key.toUpperCase(),
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...entry.value.map((palette) => _buildPaletteCard(context, palette)),
              const SizedBox(height: 32),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaletteCard(BuildContext context, Map<String, dynamic> palette) {
    final List<int> colors = palette['colors'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () => _handlePaletteTap(context, palette),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(palette['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(palette['mood'], style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: colors.map((hex) => Expanded(
                  child: Container(
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Color(hex),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.view_in_ar_rounded, color: Colors.white.withOpacity(0.3), size: 16),
                  const SizedBox(width: 8),
                  Text('TAP TO TRY IN YOUR ROOM', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePaletteTap(BuildContext context, Map<String, dynamic> palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('VISUALIZE THIS PALETTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 24),
              _optionTile(
                context,
                icon: Icons.camera_alt_rounded,
                title: 'Capture Room Photo',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ARVisualizationScreen(
                    initialColor: Color(palette['colors'][0]),
                  )));
                },
              ),
              const SizedBox(height: 16),
              _optionTile(
                context,
                icon: Icons.photo_library_rounded,
                title: 'Choose from Gallery',
                onTap: () async {
                  final picker = ImagePicker();
                  final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null && context.mounted) {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ARVisualizationScreen(
                      initialImage: File(pickedFile.path),
                      initialColor: Color(palette['colors'][0]),
                    )));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      tileColor: Colors.white.withOpacity(0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
