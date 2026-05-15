import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_loading_screen.dart';
import 'services/ml_service.dart';

// Global list of cameras discovered on startup
List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Discover cameras before the app launches to avoid any startup delay
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Could not find cameras: $e");
  }

  // Initialize AI Models
  await MLService().loadModel();

  // Make the status bar transparent for a full-screen immersive look
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ARHomeVizApp());
}

// ============================================================================
// ROOT APP
// ============================================================================
class ARHomeVizApp extends StatelessWidget {
  const ARHomeVizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR-HomeViz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(primary: Colors.blueAccent),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================================
// SPLASH SCREEN
// ============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // After 3 seconds, move to the auth loading screen
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthLoadingScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo with a soft glow effect
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.4),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset('assets/app_logo.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'AR-ML HOMEVIZ',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'DESIGN YOUR SPACE',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 3,
                color: Colors.white.withOpacity(0.45),
              ),
            ),
            const SizedBox(height: 60),
            const CircularProgressIndicator(
              color: Colors.blueAccent,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ARVisualizationScreen was moved to lib/screens/ar_view_screen.dart
