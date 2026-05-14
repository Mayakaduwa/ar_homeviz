import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isSending = false;
  bool _sent = false;
  String? _emailError;

  bool _isValidEmail(String v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());

  Future<void> _sendReset() async {
    final email = _emailController.text.trim();
    setState(() { _emailError = null; });

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email address');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      return;
    }

    setState(() => _isSending = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() { _sent = true; _isSending = false; });
    } on FirebaseAuthException catch (e) {
      setState(() => _isSending = false);
      String msg = 'Could not send reset email. Please try again.';
      if (e.code == 'user-not-found') msg = 'No account found with this email address.';
      if (e.code == 'invalid-email') msg = 'Invalid email format.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Try again.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset_rounded, color: Colors.blueAccent, size: 36),
            ),
            const SizedBox(height: 28),
            const Text('Reset Password', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              _sent
                ? 'A reset link has been sent to your email. Check your inbox (and spam folder).'
                : 'Enter your registered email address and we will send you a password reset link.',
              style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 40),

            if (!_sent) ...[
              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  errorText: _emailError,
                  errorStyle: const TextStyle(color: Colors.redAccent),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSending
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('SEND RESET LINK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),
            ] else ...[
              // Success state
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Check your inbox at:\n${_emailController.text.trim()}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => setState(() { _sent = false; _emailController.clear(); }),
                  child: const Text('Send to a different email', style: TextStyle(color: Colors.blueAccent)),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Login', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
