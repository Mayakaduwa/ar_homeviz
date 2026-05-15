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
import 'user_preferences_service.dart';

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

  static const String _kKaggleApiUrl = 'https://transfer-certainty-wick.ngrok-free.dev/chat';
  static const String _kGeminiApiKey = 'REPLACE_WITH_YOUR_GEMINI_KEY';
  
  static const String _kSystemPrompt = 
    "You are a friendly, professional AI interior designer. "
    "Give brief, professional advice. Focus only on wall colors and design. "
    "If you suggest a specific color, include its hex code (e.g. #8FAF8A).";

  static Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/color_reco_model.tflite');
    } catch (e) {
      debugPrint("Local chat fallback: $e");
    }
  }

  static Future<String> getAIResponse(String userMessage, List<ChatMessage> history) async {
    final user = FirebaseAuth.instance.currentUser;
    String userStyle = "Modern";
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}/preferredStyle').get();
      if (snapshot.exists) userStyle = snapshot.value.toString();
    }

    // Format history for the new Kaggle logic (Phi-3 style)
    List<Map<String, String>> historyMap = history.reversed.take(6).toList().reversed.map((m) => {
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.text,
    }).toList();

    try {
      final httpClient = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      final ioClient = IOClient(httpClient);

      final response = await ioClient.post(
        Uri.parse(_kKaggleApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'message': userMessage,
          'history': historyMap,
          'system_prompt': "$_kSystemPrompt User preference: $userStyle.",
        }),
      ).timeout(const Duration(seconds: 60));

      ioClient.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String rawText = data['response'] ?? data['generated_text'] ?? "";
        return _cleanResponse(rawText);
      }
    } catch (e) {
      debugPrint('Kaggle Tier failed: $e');
    }

    if (_kGeminiApiKey != 'REPLACE_WITH_YOUR_GEMINI_KEY') {
      try {
        final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _kGeminiApiKey);
        final chat = model.startChat(history: history.map((m) => 
          Content(m.isUser ? 'user' : 'model', [TextPart(m.text)])
        ).toList());
        final response = await chat.sendMessage(Content.text(userMessage));
        return response.text ?? "I'm here to help!";
      } catch (e) {}
    }

    return _smartLocalFallback(userMessage);
  }

  static Future<String> getMultimodalResponse(String message, File imageFile) async {
    if (_kGeminiApiKey == 'REPLACE_WITH_YOUR_GEMINI_KEY') return "Gemini Key Required for images.";
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _kGeminiApiKey);
      final bytes = await imageFile.readAsBytes();
      final content = [Content.multi([TextPart(message), DataPart('image/jpeg', bytes)])];
      final response = await model.generateContent(content);
      return response.text ?? "Analysis complete.";
    } catch (e) {
      return "Sorry, I couldn't process the image right now.";
    }
  }

  static String _smartLocalFallback(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('hi') || msg.contains('hello')) return "Hello! How can I help you design your room today?";
    if (msg.contains('color') || msg.contains('wall')) return "For a fresh look, I recommend soft neutrals like sage green (#8FAF8A).";
    return "That's an interesting idea! Tell me more about your style.";
  }

  static String _cleanResponse(String text) {
    if (text.isEmpty) return "I'm here to help with your design!";
    
    // The new Kaggle server handles stripping natively, but we do a safety check
    String cleaned = text
      .replaceAll(RegExp(r'^(System:|Assistant:|Response:|AI:)', caseSensitive: false), '')
      .trim();

    if (cleaned.length > 500) cleaned = "${cleaned.substring(0, 497)}...";
    return cleaned.isEmpty ? "How can I help you design your room today?" : cleaned;
  }

  static Future<void> saveMessage(ChatMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseDatabase.instance.ref('users/${user.uid}/chats').push().set(message.toJson());
    }
  }

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

  static Future<void> clearChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await FirebaseDatabase.instance.ref('users/${user.uid}/chats').remove();
  }

  static Color? detectColorInResponse(String response) {
    final hexRegex = RegExp(r'#([0-9a-fA-F]{6})');
    final match = hexRegex.firstMatch(response);
    if (match != null) return Color(int.parse('FF${match.group(1)!}', radix: 16));
    return null;
  }
}
