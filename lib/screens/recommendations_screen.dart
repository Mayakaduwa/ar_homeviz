import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'ar_view_screen.dart';
import '../services/user_preferences_service.dart';

// ─── Color Theory Palette Data ────────────────────────────────────────────────
const _kRoomTypes = ['Living Room', 'Bedroom', 'Kitchen', 'Office', 'Dining Room', 'Kids Room'];
const _kMoods = ['Calm', 'Warm', 'Luxury', 'Modern', 'Energetic'];
const _kColorFamilies = [
  {'key': 'blues',    'label': 'Blues',       'sample': Color(0xFF4F8BD6)},
  {'key': 'greens',   'label': 'Greens',      'sample': Color(0xFF3FA37D)},
  {'key': 'neutrals', 'label': 'Neutrals',    'sample': Color(0xFF94A3B8)},
  {'key': 'earth',    'label': 'Earth Tones', 'sample': Color(0xFFB45309)},
  {'key': 'pastels',  'label': 'Pastels',     'sample': Color(0xFFF9A8D4)},
  {'key': 'reds',     'label': 'Reds',        'sample': Color(0xFFE2725B)},
  {'key': 'yellows',  'label': 'Yellows',     'sample': Color(0xFFF59E0B)},
  {'key': 'bw',       'label': 'Black/White', 'sample': Color(0xFF334155)},
];

const _kPalettes = {
  'Calm': {
    'blues':    [0xFFEAF6FF, 0xFFCFE7FF, 0xFF9CC9FF, 0xFF4F8BD6, 0xFF1E3A5F],
    'greens':   [0xFFEAF7F0, 0xFFCDEFE0, 0xFF9DDCC3, 0xFF3FA37D, 0xFF1E4D3A],
    'neutrals': [0xFFF8FAFC, 0xFFE2E8F0, 0xFF94A3B8, 0xFF475569, 0xFF1E293B],
    'earth':    [0xFFFEF3C7, 0xFFFDE68A, 0xFFF59E0B, 0xFFB45309, 0xFF78350F],
    'pastels':  [0xFFFDF2F8, 0xFFEDE9FE, 0xFFF9A8D4, 0xFFD8B4FE, 0xFFA78BFA],
    'reds':     [0xFFFFF1F2, 0xFFFFE4E6, 0xFFFCA5A5, 0xFFE2725B, 0xFF9F1239],
    'yellows':  [0xFFFFFBEB, 0xFFFEF3C7, 0xFFFCD34D, 0xFFF59E0B, 0xFF92400E],
    'bw':       [0xFFFFFFFF, 0xFFF1F5F9, 0xFF94A3B8, 0xFF334155, 0xFF0F172A],
  },
  'Warm': {
    'blues':    [0xFFFFF7ED, 0xFFFED7AA, 0xFF9CC9FF, 0xFF4F8BD6, 0xFF1E3A5F],
    'greens':   [0xFFFFFBEB, 0xFFFEF3C7, 0xFF86EFAC, 0xFF3FA37D, 0xFF14532D],
    'neutrals': [0xFFFEF9EC, 0xFFFDE68A, 0xFFD4A853, 0xFF92400E, 0xFF451A03],
    'earth':    [0xFFFFF7ED, 0xFFFED7AA, 0xFFF59E0B, 0xFFB45309, 0xFF78350F],
    'pastels':  [0xFFFFF1F2, 0xFFFECDD3, 0xFFFDA4AF, 0xFFFF6B8A, 0xFFBE123C],
    'reds':     [0xFFFFF7ED, 0xFFFED7AA, 0xFFFB923C, 0xFFE2725B, 0xFF9A3412],
    'yellows':  [0xFFFEFCE8, 0xFFFEF08A, 0xFFFBBF24, 0xFFF59E0B, 0xFF78350F],
    'bw':       [0xFFFFFBEB, 0xFFFEF3C7, 0xFFD4A853, 0xFF92400E, 0xFF1C1917],
  },
  'Luxury': {
    'blues':    [0xFFF0F4FF, 0xFFBFD0FF, 0xFF6B85D6, 0xFF1E3A5F, 0xFF0A1628],
    'greens':   [0xFFF0FFF4, 0xFFBFEFD0, 0xFF4A8A6A, 0xFF1E4D3A, 0xFF0A1E18],
    'neutrals': [0xFFFDF8F0, 0xFFD4AF7A, 0xFF8B7355, 0xFF3D2B1F, 0xFF1A0E0A],
    'earth':    [0xFFFFF8F0, 0xFFD4AF7A, 0xFF8B6914, 0xFF4A3000, 0xFF1A0E00],
    'pastels':  [0xFFFDF0FF, 0xFFD4A8E0, 0xFF8B4DAD, 0xFF4A1A6A, 0xFF1A0A2A],
    'reds':     [0xFFFFF0F0, 0xFFD4A0A0, 0xFF8B3A3A, 0xFF4A1010, 0xFF1A0505],
    'yellows':  [0xFFFFFBF0, 0xFFD4C07A, 0xFF8B8014, 0xFF4A4000, 0xFF1A1600],
    'bw':       [0xFFFFFFFF, 0xFFD4C4A0, 0xFF8B7A56, 0xFF2D2520, 0xFF0A0805],
  },
  'Modern': {
    'blues':    [0xFFF8FAFF, 0xFFDBE8FF, 0xFF6B9FE0, 0xFF1E4A8B, 0xFF0D1F3D],
    'greens':   [0xFFF5FAF7, 0xFFCCE8D8, 0xFF5A9E7A, 0xFF1E5A3A, 0xFF0D2018],
    'neutrals': [0xFFF8FAFC, 0xFFCBD5E1, 0xFF64748B, 0xFF1E293B, 0xFF0F172A],
    'earth':    [0xFFFAF5F0, 0xFFD4C4A8, 0xFF8B7355, 0xFF3D2B1F, 0xFF1A0E0A],
    'pastels':  [0xFFFAF8FF, 0xFFE8E0F8, 0xFF9B8EC8, 0xFF3D2B7A, 0xFF150F2A],
    'reds':     [0xFFFAF5F5, 0xFFD4B0B0, 0xFF8B5050, 0xFF3D1A1A, 0xFF150A0A],
    'yellows':  [0xFFFAF8F0, 0xFFD4CCA8, 0xFF8B8050, 0xFF3D3520, 0xFF15120A],
    'bw':       [0xFFFFFFFF, 0xFFF1F5F9, 0xFF64748B, 0xFF1E293B, 0xFF0F172A],
  },
  'Energetic': {
    'blues':    [0xFFE0F0FF, 0xFF80C0FF, 0xFF2080E0, 0xFF0040A0, 0xFF001040],
    'greens':   [0xFFE0FFE8, 0xFF80FFA0, 0xFF20C040, 0xFF007020, 0xFF002808],
    'neutrals': [0xFFFFFFFF, 0xFFE0E0E0, 0xFF808080, 0xFF303030, 0xFF080808],
    'earth':    [0xFFFFF0E0, 0xFFFFA060, 0xFFE05010, 0xFF802800, 0xFF300A00],
    'pastels':  [0xFFFFF0FF, 0xFFFF80FF, 0xFFE020E0, 0xFF800080, 0xFF280028],
    'reds':     [0xFFFFE0E0, 0xFFFF6060, 0xFFE00000, 0xFF800000, 0xFF280000],
    'yellows':  [0xFFFFFFE0, 0xFFFFFF00, 0xFFD0B000, 0xFF806000, 0xFF282000],
    'bw':       [0xFFFFFFFF, 0xFFCCCCCC, 0xFF666666, 0xFF222222, 0xFF000000],
  },
};

String _harmonyText(String mood, String family) {
  if (mood == 'Modern' || family == 'bw' || family == 'neutrals')
    return 'Neutral / Monochrome — clean, minimal contrast for a modern look.';
  if (mood == 'Luxury') return 'Accent + Neutrals — deep base tones with a premium accent.';
  if (mood == 'Energetic') return 'Triadic / Vibrant — bold colors for high energy.';
  if (mood == 'Calm') return 'Analogous — nearby tones for a soft, relaxing feel.';
  if (mood == 'Warm') return 'Warm Complement — warm base with a cooler contrast.';
  return 'Balanced — visually pleasant and versatile.';
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  String _roomType = 'Living Room';
  String _mood = 'Calm';
  String _familyKey = 'blues';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadStoredPreferences();
  }

  Future<void> _loadStoredPreferences() async {
    final prefs = await UserPreferencesService.getPreferences();
    if (mounted) {
      setState(() {
        if (prefs['roomType'] != null) _roomType = prefs['roomType']!;
        if (prefs['mood'] != null) _mood = prefs['mood']!;
      });
    }
  }

  List<Color> get _palette {
    final moodMap = _kPalettes[_mood] ?? _kPalettes['Calm']!;
    final raw = moodMap[_familyKey] ?? moodMap['blues']!;
    return raw.map((v) => Color(v)).toList();
  }

  String get _harmony => _harmonyText(_mood, _familyKey);

  Future<void> _saveRecommendation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseDatabase.instance.ref('users/${user.uid}/recommendations').push().set({
        'roomType': _roomType,
        'mood': _mood,
        'colorFamily': _familyKey,
        'palette': _palette.map((c) => c.value.toRadixString(16).substring(2).toUpperCase()).toList(),
        'harmony': _harmony,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      // Also update preferences
      await FirebaseDatabase.instance.ref('users/${user.uid}').update({
        'preferences': {
          'roomType': _roomType,
          'mood': _mood,
          'colorFamily': _familyKey,
          'lastPalette': _palette.map((c) => c.value.toRadixString(16)).toList(),
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recommendation saved! ✓'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Try again.'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _tryInAR() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('VISUALIZE THIS PALETTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13)),
              const SizedBox(height: 20),
              _sheetTile(Icons.camera_alt_rounded, 'Capture Room Photo', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ARVisualizationScreen(initialColor: _palette[2])));
              }),
              const SizedBox(height: 12),
              _sheetTile(Icons.photo_library_rounded, 'Choose from Gallery', () async {
                final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (picked != null && context.mounted) {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ARVisualizationScreen(
                    initialImage: File(picked.path), initialColor: _palette[2],
                  )));
                }
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      tileColor: Colors.white.withOpacity(0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('COLOR RECOMMENDATIONS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Room Type ──────────────────────────────────────────────────
            _sectionLabel('ROOM TYPE'),
            const SizedBox(height: 10),
            _chipRow(_kRoomTypes, _roomType, (v) => setState(() => _roomType = v)),
            const SizedBox(height: 24),

            // ── Mood ───────────────────────────────────────────────────────
            _sectionLabel('MOOD'),
            const SizedBox(height: 10),
            _chipRow(_kMoods, _mood, (v) => setState(() => _mood = v)),
            const SizedBox(height: 24),

            // ── Color Family ───────────────────────────────────────────────
            _sectionLabel('COLOUR FAMILY'),
            const SizedBox(height: 10),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _kColorFamilies.length,
                itemBuilder: (_, i) {
                  final f = _kColorFamilies[i];
                  final key = f['key'] as String;
                  final label = f['label'] as String;
                  final sample = f['sample'] as Color;
                  final selected = _familyKey == key;
                  return GestureDetector(
                    onTap: () => setState(() => _familyKey = key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? sample.withOpacity(0.25) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: selected ? sample : Colors.white12, width: selected ? 2 : 1),
                      ),
                      child: Row(
                        children: [
                          Container(width: 14, height: 14, decoration: BoxDecoration(color: sample, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white60, fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // ── Palette Result ─────────────────────────────────────────────
            _sectionLabel('YOUR 5-COLOUR PALETTE'),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: palette.map((c) => Expanded(
                      child: Container(
                        height: 72,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: c.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: Colors.blueAccent.withOpacity(0.7), size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Harmony: $_harmony', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.4)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Hex codes
                  Row(
                    children: palette.map((c) {
                      final hex = '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
                      return Expanded(
                        child: Text(hex, textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Action Buttons ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _tryInAR,
                icon: const Icon(Icons.view_in_ar_rounded),
                label: const Text('TRY IN AR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _saveRecommendation,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
                    : const Icon(Icons.bookmark_rounded, color: Colors.blueAccent),
                label: const Text('SAVE RECOMMENDATION', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blueAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
  );

  Widget _chipRow(List<String> items, String selected, ValueChanged<String> onSelect) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: items.map((item) {
        final isSelected = item == selected;
        return GestureDetector(
          onTap: () => onSelect(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white12),
            ),
            child: Text(item, style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            )),
          ),
        );
      }).toList(),
    );
  }
}
