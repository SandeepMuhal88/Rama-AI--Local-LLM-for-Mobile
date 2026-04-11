import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'llm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'RAMA AI',
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final LLMService llm = LLMService();

  List<Map<String, String>> chat = [];
  bool isLoading = false;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
  }

  Future<void> _requestStoragePermission() async {
    if (!Platform.isAndroid) return;

    // Request READ_EXTERNAL_STORAGE (needed on Android ≤ 12)
    final readStatus = await Permission.storage.request();

    // Request MANAGE_EXTERNAL_STORAGE (needed on Android 11+)
    final manageStatus = await Permission.manageExternalStorage.request();

    if (!mounted) return;

    if (readStatus.isDenied && manageStatus.isDenied) {
      setState(() {
        _permissionError =
            'Storage permission is required to load the AI model.\n'
            'Please grant "All files access" in App Settings.';
      });
    } else {
      setState(() {
        _permissionError = null;
      });
    }
  }

  void sendMessage() async {
    if (_permissionError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grant storage permission first!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String input = controller.text.trim();
    if (input.isEmpty) return;

    setState(() {
      chat.add({"role": "user", "text": input});
      isLoading = true;
    });

    controller.clear();

    // Run inference in background isolate
    String output = await Future(() => llm.run(input));

    setState(() {
      chat.add({"role": "ai", "text": output});
      isLoading = false;
    });
  }

  Widget buildMessage(Map<String, String> msg) {
    bool isUser = msg["role"] == "user";
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          msg["text"] ?? "",
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RAMA AI"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Permission error banner
          if (_permissionError != null)
            Container(
              width: double.infinity,
              color: Colors.red[100],
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    _permissionError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: const Text('Open App Settings'),
                  ),
                ],
              ),
            ),

          // Model path info banner
          Container(
            width: double.infinity,
            color: Colors.blue[50],
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: const Text(
              '📁 Model: /storage/emulated/0/RAMA_AI/models/model.gguf',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
          ),

          // Chat messages
          Expanded(
            child: chat.isEmpty
                ? const Center(
                    child: Text(
                      'Ask RAMA AI anything...',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: chat.length,
                    itemBuilder: (context, index) {
                      return buildMessage(chat[index]);
                    },
                  ),
          ),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text("Thinking...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),

          // Input row
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => sendMessage(),
                    decoration: InputDecoration(
                      hintText: "Ask something...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: sendMessage,
                  backgroundColor: Colors.deepPurple,
                  child: const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}