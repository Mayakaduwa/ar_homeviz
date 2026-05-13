import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import 'ar_view_screen.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  File? _selectedImage;
  List<ChatMessage> _currentMessages = [];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await showModalBottomSheet<XFile>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async => Navigator.pop(context, await picker.pickImage(source: ImageSource.camera)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async => Navigator.pop(context, await picker.pickImage(source: ImageSource.gallery)),
            ),
          ],
        ),
      ),
    );

    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty && _selectedImage == null) return;

    final String userText = _controller.text.trim();
    final File? image = _selectedImage;

    // 1. Save user message to Firebase
    final userMsg = ChatMessage(text: userText, isUser: true);
    await ChatService.saveMessage(userMsg);

    setState(() {
      _controller.clear();
      _selectedImage = null;
      _isTyping = true;
    });
    _scrollToBottom();

    // 2. Get AI Response with History
    String response;
    if (image != null) {
      response = await ChatService.getMultimodalResponse(userText.isEmpty ? "What do you think?" : userText, image);
    } else {
      response = await ChatService.getAIResponse(userText, _currentMessages);
    }

    final Color? suggestedColor = ChatService.detectColorInResponse(response);

    // 3. Save AI message to Firebase
    final aiMsg = ChatMessage(text: response, isUser: false, suggestedColor: suggestedColor);
    await ChatService.saveMessage(aiMsg);

    if (mounted) {
      setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('AI DECOR AGENT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white38),
            onPressed: () => ChatService.clearChat(),
            tooltip: 'Clear Conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatService.getChatStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _currentMessages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                _currentMessages = snapshot.data ?? [];
                
                if (_currentMessages.isEmpty) {
                  return _buildWelcomeState();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: _currentMessages.length,
                  itemBuilder: (context, index) => _buildMessageBubble(_currentMessages[index]),
                );
              },
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.only(left: 20, bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('AI is thinking...', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontStyle: FontStyle.italic)),
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 60, color: Colors.blueAccent.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('New Conversation', style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Ask me about colors, styles, or room layouts.', style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blueAccent : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isUser ? 20 : 0),
            bottomRight: Radius.circular(message.isUser ? 0 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(color: message.isUser ? Colors.white : Colors.white70, fontSize: 14),
            ),
            if (message.suggestedColor != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ARVisualizationScreen(
                    initialColor: message.suggestedColor,
                  )));
                },
                icon: Icon(Icons.palette_rounded, size: 16, color: message.suggestedColor),
                label: const Text('APPLY TO ROOM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_selectedImage != null)
              Container(
                height: 60,
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_selectedImage!, width: 60, height: 60, fit: BoxFit.cover),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      onPressed: () => setState(() => _selectedImage = null),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file_rounded, color: Colors.blueAccent),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.blueAccent),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
