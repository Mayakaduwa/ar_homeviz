import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'ar_view_screen.dart';

class SavedPalettesScreen extends StatefulWidget {
  const SavedPalettesScreen({super.key});

  @override
  State<SavedPalettesScreen> createState() => _SavedPalettesScreenState();
}

class _SavedPalettesScreenState extends State<SavedPalettesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _designs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Load saved recommendations — sort client-side to avoid Firebase index requirement
      final recoSnap = await FirebaseDatabase.instance
          .ref('users/${user.uid}/recommendations')
          .get();
      if (recoSnap.exists) {
        final data = recoSnap.value as Map<dynamic, dynamic>;
        final list = data.entries.map((e) {
          final v = Map<String, dynamic>.from(e.value as Map);
          v['id'] = e.key;
          return v;
        }).toList();
        list.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
        _recommendations = list;
      }

      // Load design history — sort client-side to avoid Firebase index requirement
      final histSnap = await FirebaseDatabase.instance
          .ref('users/${user.uid}/history')
          .get();
      if (histSnap.exists) {
        final data = histSnap.value as Map<dynamic, dynamic>;
        final list = data.entries.map((e) {
          final v = Map<String, dynamic>.from(e.value as Map);
          v['id'] = e.key;
          return v;
        }).toList();
        list.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
        _designs = list;
      }
    } catch (e) {
      debugPrint('Load palettes error: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _deleteRecommendation(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseDatabase.instance.ref('users/${user.uid}/recommendations/$id').remove();
    setState(() => _recommendations.removeWhere((r) => r['id'] == id));
  }

  Future<void> _deleteDesign(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Delete from Firebase
    await FirebaseDatabase.instance.ref('users/${user.uid}/history/$id').remove();
    // Try to delete local file too
    final item = _designs.firstWhere((d) => d['id'] == id, orElse: () => {});
    if (item.containsKey('localPath')) {
      try { await File(item['localPath']).delete(); } catch (_) {}
    }
    setState(() => _designs.removeWhere((d) => d['id'] == id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('MY SAVED PALETTES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: [
            Tab(text: 'RECOMMENDATIONS (${_recommendations.length})'),
            Tab(text: 'MY DESIGNS (${_designs.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRecommendationsTab(),
                _buildDesignsTab(),
              ],
            ),
    );
  }

  Widget _buildRecommendationsTab() {
    if (_recommendations.isEmpty) {
      return _emptyState(
        Icons.bookmark_border_rounded,
        'No saved recommendations yet',
        'Go to Color Recommendations and save a palette.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recommendations.length,
      itemBuilder: (_, i) {
        final item = _recommendations[i];
        final List rawPalette = item['palette'] ?? [];
        final palette = rawPalette.map((h) => Color(int.parse('FF$h', radix: 16))).toList();
        final ts = item['timestamp'];
        final date = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item['roomType'] ?? 'Room'} · ${item['mood'] ?? ''}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        if (date != null)
                          Text('${date.day}/${date.month}/${date.year}',
                            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => _deleteRecommendation(item['id']),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Palette swatches
              Row(
                children: palette.map((c) => Expanded(
                  child: Container(
                    height: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 10),
              if (item['harmony'] != null)
                Text(item['harmony'], style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, height: 1.4)),
              const SizedBox(height: 12),
              // Try in AR button
              if (palette.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                      ARVisualizationScreen(initialColor: palette[2 < palette.length ? 2 : 0]))),
                    icon: const Icon(Icons.view_in_ar_rounded, size: 16, color: Colors.blueAccent),
                    label: const Text('TRY IN AR', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blueAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesignsTab() {
    if (_designs.isEmpty) {
      return _emptyState(
        Icons.photo_library_outlined,
        'No designs saved yet',
        'Capture a room photo and save your colored design.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _designs.length,
      itemBuilder: (_, i) {
        final item = _designs[i];
        final localPath = item['localPath'] as String?;
        final colorHex = item['colorHex'] as String?;
        final color = colorHex != null ? Color(int.parse('FF$colorHex', radix: 16)) : Colors.blueAccent;
        final ts = item['timestamp'];
        final date = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Image Preview
              if (localPath != null && File(localPath).existsSync())
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Image.file(File(localPath), fit: BoxFit.cover),
                )
              else
                Container(
                  height: 80,
                  color: color.withOpacity(0.3),
                  child: Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.white38)),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(width: 20, height: 20, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item['target']?.toString().capitalize() ?? 'Design'} Design',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          if (date != null)
                            Text('${date.day}/${date.month}/${date.year}',
                              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _deleteDesign(item['id']),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState(IconData icon, String title, String sub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(sub, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() => isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
}
