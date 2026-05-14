import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

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
  
  static const String _kSystemPrompt = 
    "You are a friendly, professional AI interior designer. "
    "Give very brief advice (maximum 2 sentences). "
    "Always be helpful and creative. "
    "Focus only on wall colors, palettes, room styles, and design advice. "
    "If you suggest a specific color, include its hex code in format #RRGGBB.";

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

    // --- TIER 1: KAGGLE/COLAB LLM (WITH SYSTEM PROMPT + HISTORY) ---
    if (!_kKaggleApiUrl.contains('YOUR_NGROK_ID')) {
      try {
        final httpClient = HttpClient()
          ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true)
          ..connectionTimeout = const Duration(seconds: 15);
        final ioClient = IOClient(httpClient);

        final response = await ioClient.post(
          Uri.parse(_kKaggleApiUrl),
          headers: {
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
          body: jsonEncode({
            'message': userMessage,
            'style': userStyle,
            'history': historyMap,
            'system_prompt': _kSystemPrompt,
          }),
        ).timeout(const Duration(seconds: 90)); // 90s - Better for Kaggle initialization

        ioClient.close();

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          String rawText = data['response'] ?? data['generated_text'] ?? "";
          return _cleanResponse(rawText);
        } else {
          debugPrint('Kaggle Tier returned HTTP ${response.statusCode}');
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
    
    // Improved keyword detection to avoid the "Interesting challenge" repetition
    if (msg.contains('living room') || msg.contains('bedroom') || msg.contains('kitchen') || msg.contains('room')) {
      return "Got it! For a ${msg.contains('room') ? 'space like that' : msg}, would you prefer a warm, cool, or neutral tone for the walls?";
    }

    if (msg.contains('neutral') || msg.contains('cool') || msg.contains('warm')) {
      String hex = "#F5F0E8"; // Neutral white
      if (msg.contains('cool')) hex = "#B0C4DE"; // Light Steel Blue
      if (msg.contains('warm')) hex = "#E2725B"; // Terracotta
      
      return "Excellent choice. $msg tones work well for balance. I suggest starting with a base like $hex. Would you like to see a full 5-color palette for this?";
    }

    if (msg.contains('yes') || msg.contains('palette') || msg.contains('recommend')) {
      return "Here is a balanced palette for you: [0xFFF5F0E8], [0xFF8FAF8A], [0xFF36454F], [0xFF1B2A4A], and [0xFF2D6A6A]. Which one should we try in AR first?";
    }

    if (msg.contains('wall') || msg.contains('color') || msg.contains('colour')) {
      return "For walls, soft neutrals like sage green (#8FAF8A) are very popular right now. Do you want to see how it looks on your own wall?";
    }

    if (msg.contains('save') || msg.contains('done') || msg.contains('finish')) {
      return "Tap the checkmark button at the bottom to save your design to your gallery!";
    }

    return "That's a unique style! Tell me more about the mood you want to create (e.g., calm, energetic, luxury).";
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

  static String _cleanResponse(String text) {
    if (text.isEmpty) return "I'm here to help with your design!";
    
    // Remove leaked prompt headers common in smaller models
    String cleaned = text
      .replaceAll(RegExp(r'^(You are a|System:|Assistant:)', caseSensitive: false), '')
      .replaceAll(_kSystemPrompt, '')
      .trim();

    // If the model repeated the user's message at the start, try to strip it
    if (cleaned.contains('hi Hello!') || cleaned.contains('hi hi')) {
       cleaned = cleaned.split('!').last.trim();
    }
    
    // Ensure it's not too long
    if (cleaned.length > 300) {
      cleaned = "${cleaned.substring(0, 297)}...";
    }

    return cleaned.isEmpty ? "How can I help you design your room today?" : cleaned;
  }
}
