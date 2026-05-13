import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  String _selectedStyle = "Modern";
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _styles = ["Modern", "Minimalist", "Vintage", "Luxury", "Bohemian", "Industrial"];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? "User";
          _selectedStyle = data['preferredStyle'] ?? "Modern";
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseDatabase.instance.ref('users/${user.uid}').update({
        'name': _nameController.text.trim(),
        'preferredStyle': _selectedStyle,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('PROFILE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Avatar Section ---
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blueAccent.withOpacity(0.1),
                          child: const Icon(Icons.person, size: 50, color: Colors.blueAccent),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          FirebaseAuth.instance.currentUser?.email ?? "",
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- Name Field ---
                  const Text('DISPLAY NAME', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      hintText: "Enter your name",
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Style Preference ---
                  const Text('INTERIOR STYLE PREFERENCE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _styles.map((style) {
                      final isSelected = _selectedStyle == style;
                      return ChoiceChip(
                        label: Text(style),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedStyle = style);
                        },
                        selectedColor: Colors.blueAccent,
                        backgroundColor: Colors.white.withOpacity(0.05),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 60),

                  // --- Action Buttons ---
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSaving 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        FirebaseAuth.instance.signOut();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('LOGOUT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
