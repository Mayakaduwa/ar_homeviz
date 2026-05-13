import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class ChatMessage {
  final String text;
  final bool isUser;
  final Color? suggestedColor;
  final int timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.suggestedColor,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'suggestedColor': suggestedColor?.value,
    'timestamp': timestamp,
  };

  factory ChatMessage.fromJson(Map<dynamic, dynamic> json) => ChatMessage(
    text: json['text'],
    isUser: json['isUser'],
    suggestedColor: json['suggestedColor'] != null ? Color(json['suggestedColor']) : null,
    timestamp: json['timestamp'],
  );
}

class ChatService {
  static Interpreter? _interpreter;

  // YOUR actual Ngrok URL from Kaggle
  static const String _kKaggleApiUrl = 'https://transfer-certainty-wick.ngrok-free.dev/chat';
  
  // REPLACE with your actual Gemini API Key
  static const String _kGeminiApiKey = 'REPLACE_WITH_YOUR_GEMINI_KEY';

  static Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/color_reco_model.tflite');
    } catch (e) {
      debugPrint("Using rule-based fallback for chat: $e");
    }
  }

  /// Sends a message and receives a response with HISTORY context
  static Future<String> getAIResponse(String userMessage, List<ChatMessage> history) async {
    final user = FirebaseAuth.instance.currentUser;
    String userStyle = "Modern";
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}/preferredStyle').get();
      if (snapshot.exists) userStyle = snapshot.value.toString();
    }

    // Format last 6 messages for context (3 exchanges)
    List<Map<String, String>> historyMap = history.reversed.take(6).toList().reversed.map((m) => {
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.text,
    }).toList();

    // BUG-004: System prompt — prevents Phi-3 from re-introducing itself or asking
    // the same questions repeatedly
    const String systemPrompt =
      'You are an expert interior design AI assistant for the AR-HomeViz app. '
      'The user is designing their home and wants color advice. '
      'Never introduce yourself again. Never ask for the user name. '
      'Keep all responses under 3 short sentences. '
      'Focus only on wall colors, palettes, room styles, and design advice. '
      'If you suggest a specific color, include its hex code in format #RRGGBB.';

    // --- TIER 1: KAGGLE/COLAB LLM (WITH SYSTEM PROMPT + HISTORY) ---
    if (!_kKaggleApiUrl.contains('YOUR_NGROK_ID')) {
      try {
        final response = await http.post(
          Uri.parse(_kKaggleApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': userMessage,
            'style': userStyle,
            'history': historyMap,
            'system_prompt': systemPrompt, // BUG-004 fix
          }),
        ).timeout(const Duration(seconds: 12));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['response'] ?? "I'm thinking...";
        }
      } catch (e) {
        debugPrint('Kaggle Tier failed: $e');
      }
    }

    // --- TIER 2: GEMINI API (WITH HISTORY) ---
    if (_kGeminiApiKey != 'REPLACE_WITH_YOUR_GEMINI_KEY') {
      try {
        final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _kGeminiApiKey);
        final chat = model.startChat(history: history.map((m) => 
          Content(m.isUser ? 'user' : 'model', [TextPart(m.text)])
        ).toList());

        final prompt = 'User Preference: $userStyle. User Message: $userMessage. Keep it conversational and brief.';
        final response = await chat.sendMessage(Content.text(prompt));
        return response.text ?? "I have no words.";
      } catch (e) {
        debugPrint('Gemini failed: $e');
      }
    }

    // --- TIER 3: SMART LOCAL FALLBACK (BUG-004 fix) ---
    return _smartLocalFallback(userMessage);
  }

  /// BUG-004: Smart rule-based fallback that doesn't repeat questions
  static String _smartLocalFallback(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('hi') || msg.contains('hello') || msg.contains('hey')) {
      return "Great to chat! What room are you designing today — living room, bedroom, or something else?";
    }
    if (msg.contains('wall') && (msg.contains('color') || msg.contains('colour'))) {
      return "For walls, soft neutrals like warm white (#F5F0E8) or sage green (#8FAF8A) are trending. Would you like a full 5-color palette?";
    }
    if (msg.contains('floor')) {
      return "For floors, warm oak tones or charcoal grey work beautifully. Try pairing with lighter walls for contrast.";
    }
    if (msg.contains('bedroom')) {
      return "Bedrooms look stunning in soft blues (#B0C4DE) or lavender (#C8A2C8) — they promote relaxation and better sleep.";
    }
    if (msg.contains('living room') || msg.contains('lounge')) {
      return "Living rooms shine in warm terracotta (#E2725B) or deep teal (#2D6A6A). Which mood are you going for — cozy or modern?";
    }
    if (msg.contains('modern') || msg.contains('minimal')) {
      return "For a modern look, try crisp white (#FFFFFF) with charcoal grey (#36454F) accents. Add a bold accent wall in navy (#1B2A4A).";
    }
    if (msg.contains('recommend') || msg.contains('suggest') || msg.contains('palette')) {
      return "I'd suggest Warm Neutrals: beige (#F5F5DC), taupe (#8B8680), cream (#FFFDD0), and warm white (#FAF9F6). Would you like to try this in AR?";
    }
    if (msg.contains('save') || msg.contains('done') || msg.contains('finish')) {
      return "Tap the checkmark button at the bottom to save your design to your gallery!";
    }
    return "That's an interesting design challenge! I'd focus on the wall color first — would you prefer a warm, cool, or neutral tone for this space?";
  }

  /// Multimodal chat for analyzing images (Gemini-only for now)
  static Future<String> getMultimodalResponse(String message, File imageFile) async {
    if (_kGeminiApiKey == 'REPLACE_WITH_YOUR_GEMINI_KEY') {
      return "Please set your Gemini API key to use image analysis.";
    }

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _kGeminiApiKey);
      final bytes = await imageFile.readAsBytes();
      final content = [
        Content.multi([
          TextPart(message),
          DataPart('image/jpeg', bytes),
        ])
      ];
      final response = await model.generateContent(content);
      return response.text ?? "I've analyzed the image but have no words.";
    } catch (e) {
      return "Sorry, I couldn't process the image right now.";
    }
  }

  /// Firebase: Save message to the cloud
  static Future<void> saveMessage(ChatMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseDatabase.instance.ref('users/${user.uid}/chats').push().set(message.toJson());
  }

  /// Firebase: Load history from the cloud
  static Stream<List<ChatMessage>> getChatStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    
    return FirebaseDatabase.instance.ref('users/${user.uid}/chats').orderByChild('timestamp').onValue.map((event) {
      final Map<dynamic, dynamic>? data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];
      
      return data.values.map((m) => ChatMessage.fromJson(m)).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
  }

  /// Firebase: Clear chat
  static Future<void> clearChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseDatabase.instance.ref('users/${user.uid}/chats').remove();
  }

  /// BUG-010: Detects color from AI response — supports [0xFF...], #RRGGBB, and named colors
  static Color? detectColorInResponse(String response) {
    // Format 1: [0xFFRRGGBB] (our original format)
    final hexLongRegex = RegExp(r'\[0x([0-9a-fA-F]{8})\]');
    final match1 = hexLongRegex.firstMatch(response);
    if (match1 != null) return Color(int.parse(match1.group(1)!, radix: 16));

    // Format 2: #RRGGBB (standard web hex — most LLMs output this)
    final hexShortRegex = RegExp(r'#([0-9a-fA-F]{6})');
    final match2 = hexShortRegex.firstMatch(response);
    if (match2 != null) return Color(int.parse('FF${match2.group(1)!}', radix: 16));

    // Format 3: Named colors commonly used in interior design
    final lower = response.toLowerCase();
    if (lower.contains('terracotta')) return const Color(0xFFE2725B);
    if (lower.contains('sage green') || lower.contains('sage')) return const Color(0xFF8FAF8A);
    if (lower.contains('navy')) return const Color(0xFF1B2A4A);
    if (lower.contains('charcoal')) return const Color(0xFF36454F);
    if (lower.contains('teal')) return const Color(0xFF2D6A6A);
    if (lower.contains('lavender')) return const Color(0xFFC8A2C8);
    if (lower.contains('beige')) return const Color(0xFFF5F5DC);
    if (lower.contains('cream')) return const Color(0xFFFFFDD0);
    return null;
  }
}
