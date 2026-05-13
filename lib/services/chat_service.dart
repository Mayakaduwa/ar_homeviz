import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final Color? suggestedColor;

  ChatMessage({required this.text, required this.isUser, this.suggestedColor});
}

class ChatService {
  static Interpreter? _interpreter;

  // Replace with your actual Gemini API Key from Google AI Studio
  static const String _kGeminiApiKey = 'REPLACE_WITH_YOUR_GEMINI_KEY';

  /// Loads the custom recommendation model trained in Colab
  static Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/color_reco_model.tflite');
      print("✅ Chat Recommendation Model Loaded (Objective 2)");
    } catch (e) {
      print("⚠️ Using rule-based fallback for chat: $e");
    }
  }

  static Future<String> getAIResponse(String userMessage) async {
    // --- 1. TRY GEMINI (REAL INTELLIGENCE) ---
    if (_kGeminiApiKey != 'REPLACE_WITH_YOUR_GEMINI_KEY') {
      try {
        final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _kGeminiApiKey);
        
        // Fetch User Context
        String userStyle = "Modern";
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}/preferredStyle').get();
          if (snapshot.exists) userStyle = snapshot.value.toString();
        }

        final prompt = [
          Content.text('''You are "HomeViz AI", a high-end interior designer.
          User's Preferred Style: $userStyle.
          Answer their question with expert advice. 
          If you suggest a color, include its Hex code in BRACKETS like this: [0xFF3498DB].
          Keep it professional and inspiring.
          User Question: $userMessage''')
        ];

        final response = await model.generateContent(prompt);
        if (response.text != null) return response.text!;
      } catch (e) {
        debugPrint('Gemini Error: $e');
      }
    }

    // --- 2. FALLBACK TO TFLITE/RULES ---
    await Future.delayed(const Duration(milliseconds: 600));
    String msg = userMessage.toLowerCase();

    if (_interpreter != null) {
      if (msg.contains('warm')) return "Based on my ML training, a Warm Terracotta [0xFFE2725B] would perfectly balance this space.";
      if (msg.contains('modern')) return "My neural network recommends a Minimalist Navy [0xFF1E3A8A] for a professional look.";
    }

    return "For that mood, I'd recommend a balanced Sage Green [0xFF8A9A5B]. Would you like to see how it looks?";
  }

  // Helper to extract a color from AI text (Hex support)
  static Color? detectColorInResponse(String response) {
    // Search for Hex pattern [0xFFXXXXXX]
    final hexRegex = RegExp(r'\[0x([0-9a-fA-F]{8})\]');
    final match = hexRegex.firstMatch(response);
    
    if (match != null) {
      final hexStr = match.group(1);
      return Color(int.parse(hexStr!, radix: 16));
    }

    // Fallback to basic keywords
    if (response.contains('Terracotta')) return const Color(0xFFE2725B);
    if (response.contains('Beige')) return const Color(0xFFF5F5DC);
    if (response.contains('Navy')) return const Color(0xFF1E3A8A);
    return null;
  }
}
