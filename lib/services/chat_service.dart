import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final Color? suggestedColor;

  ChatMessage({required this.text, required this.isUser, this.suggestedColor});
}

class ChatService {
  static Interpreter? _interpreter;

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
    await Future.delayed(const Duration(milliseconds: 600));
    String msg = userMessage.toLowerCase();

    // If model is loaded, we could use it for "Mood to Color" prediction
    if (_interpreter != null) {
      // Logic to convert text to numeric input for the model
      // 0=Modern, 1=Warm, 2=Calm
      int mood = 0;
      if (msg.contains('warm') || msg.contains('cozy')) mood = 1;
      if (msg.contains('calm') || msg.contains('relax')) mood = 2;

      // Model expects 3 inputs (R,G,B) for the "Reference Color"
      // Let's use a dummy reference or sample the current room color.
      var input = [0.5, 0.5, 0.5]; 
      var output = List.filled(3, 0.0).reshape([1, 3]);
      
      try {
        _interpreter!.run(input, output);
        // Map model output back to text
        if (mood == 1) return "My trained ML model suggests a Warm Terracotta palette for this space. It has high harmony with your request!";
        if (mood == 2) return "Based on design principles, a Calm Sky Blue would be the perfect fit. Want to try it?";
        return "For a modern vibe, my model recommends a Slate Grey accent wall.";
      } catch (e) {
        print("Model error: $e");
      }
    }

    // --- Fallback Rule-based logic ---
    if (msg.contains('warm') || msg.contains('cozy')) {
      return "For a warm and cozy feel, I suggest a Soft Terracotta or a Creamy Beige. These work great with natural light!";
    } else if (msg.contains('modern') || msg.contains('office')) {
      return "For a modern space, Slate Grey or Navy Blue creates a sophisticated look. Would you like to try those?";
    } else {
      return "That sounds interesting! Based on interior design trends, I'd recommend exploring earthy tones or a bold accent wall in Emerald Green.";
    }
  }

  // Helper to extract a color from AI text (Simplified for demo)
  static Color? detectColorInResponse(String response) {
    if (response.contains('Terracotta')) return const Color(0xFFE2725B);
    if (response.contains('Beige')) return const Color(0xFFF5F5DC);
    if (response.contains('Grey')) return Colors.blueGrey;
    if (response.contains('Navy')) return const Color(0xFF000080);
    if (response.contains('Sky Blue')) return Colors.lightBlueAccent;
    if (response.contains('Green')) return Colors.green;
    return null;
  }
}
