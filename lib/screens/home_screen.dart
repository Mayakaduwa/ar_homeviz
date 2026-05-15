import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'ar_view_screen.dart';
import 'my_gallery_screen.dart';
import 'profile_screen.dart';
import 'recommendations_screen.dart';
import 'chat_bot_screen.dart';
import 'saved_palettes_screen.dart';
import '../services/ml_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = "User";

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}/name').get();
      if (snapshot.exists && mounted) {
        setState(() {
          _userName = snapshot.value.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // --- Header Section ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                        ),
                        Text(
                          _userName,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    _profileIcon(),
                  ],
                ),
              ),
            ),

            // --- Main Actions Grid ---
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildListDelegate([
                  _featureCard(
                    title: 'AR Interior Design',
                    subtitle: 'Visualize colors in real-time',
                    icon: Icons.view_in_ar_rounded,
                    color: Colors.blueAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ARVisualizationScreen())),
                  ),
                  _featureCard(
                    title: 'AI Decor Chatbot',
                    subtitle: 'Get smart design advice',
                    icon: Icons.auto_awesome_rounded,
                    color: Colors.purpleAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatBotScreen())),
                  ),
                  _featureCard(
                    title: 'My Gallery',
                    subtitle: 'Designs & Palettes',
                    icon: Icons.bookmark_rounded,
                    color: Colors.amberAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPalettesScreen())),
                  ),
                  _featureCard(
                    title: 'Color Palettes',
                    subtitle: 'AI recommendations',
                    icon: Icons.palette_rounded,
                    color: Colors.greenAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecommendationsScreen())),
                  ),
                ]),
              ),
            ),

            // --- Model Selection Toggle ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.settings_suggest_rounded, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 12),
                      const Text('ML Engine:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      _versionToggle(1),
                      const SizedBox(width: 8),
                      _versionToggle(2),
                    ],
                  ),
                ),
              ),
            ),

            // --- Stats / Info Section ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Design Tip of the Day',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Using cool colors like blue and green can make a small room feel more spacious and calm.',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileIcon() {
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'logout') {
          FirebaseAuth.instance.signOut();
        } else if (val == 'profile') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'profile', child: Text('Profile Settings')),
        const PopupMenuItem(value: 'logout', child: Text('Logout', style: TextStyle(color: Colors.redAccent))),
      ],
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
        ),
        child: const CircleAvatar(
          backgroundColor: Color(0xFF1E293B),
          child: Icon(Icons.person, color: Colors.white),
        ),
      ),
    );
  }

  Widget _versionToggle(int version) {
    final isSelected = MLService().currentModelVersion == version;
    return GestureDetector(
      onTap: () => setState(() => MLService().setModelVersion(version)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'v$version',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon in the next phase!'),
        backgroundColor: Colors.blueGrey[800],
      ),
    );
  }
}
