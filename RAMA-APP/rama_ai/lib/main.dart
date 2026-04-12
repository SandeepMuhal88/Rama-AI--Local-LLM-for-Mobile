import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'llm_service.dart';
import 'model_manager_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const RamaApp());
}

// ─── App ──────────────────────────────────────────────────────────────────────
class RamaApp extends StatelessWidget {
  const RamaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RAMA AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        fontFamily: 'sans-serif',
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6C63FF),
          surface: const Color(0xFF1A1A2E),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

// ─── Message model ────────────────────────────────────────────────────────────
class ChatMessage {
  final String role; // 'user' | 'ai' | 'error'
  final String text;
  final DateTime time;
  ChatMessage(this.role, this.text) : time = DateTime.now();
}

// ─── Chat Screen ──────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final LLMService _llm = LLMService();
  late AnimationController _typingAnim;

  List<ChatMessage> _messages = [];
  bool _thinking = false;
  String? _activeModelPath;
  String? _permError;

  // ── Colour palette ──────────────────────────────────────────────────────────
  static const Color _bg       = Color(0xFF0D0D1A);
  static const Color _surface  = Color(0xFF1A1A2E);
  static const Color _accent   = Color(0xFF6C63FF);
  static const Color _userBubble = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _typingAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _init();
  }

  @override
  void dispose() {
    _typingAnim.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _requestPermissions();
    await _loadSavedModel();
    await _refreshModels();
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  Future<void> _loadSavedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('active_model_path');
    if (saved != null && File(saved).existsSync()) {
      setState(() => _activeModelPath = saved);
    }
  }

  Future<void> _refreshModels() async {
    final models = await LLMService.listModels();
    if (_activeModelPath == null && models.isNotEmpty) {
      _setActiveModel(models.first.path);
    } else if (!mounted) {
      return;
    } else {
      setState(() {});
    }
  }

  Future<void> _setActiveModel(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_model_path', path);
    if (mounted) setState(() => _activeModelPath = path);
  }

  // ── Send ────────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    if (_activeModelPath == null) {
      _addMessage(ChatMessage(
        'error',
        '⚠️ No model loaded. Tap the brain icon to download one.',
      ));
      return;
    }

    _ctrl.clear();
    setState(() {
      _messages.add(ChatMessage('user', text));
      _thinking = true;
    });
    _scrollToBottom();

    final reply = await _llm.run(_activeModelPath!, text);

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(reply.startsWith('Error:') ? 'error' : 'ai', reply));
      _thinking = false;
    });
    _scrollToBottom();
  }

  void _addMessage(ChatMessage m) => setState(() => _messages.add(m));

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            if (_activeModelPath != null) _buildModelBanner(),
            Expanded(child: _buildMessageList()),
            if (_thinking) _buildTypingIndicator(),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  Widget _buildAppBar() => Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: _surface,
          border: Border(bottom: BorderSide(color: Colors.white12)),
        ),
        child: Row(
          children: [
            // Logo
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RAMA AI',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.5)),
                Text('100% Offline · On-device',
                    style: TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
            const Spacer(),
            // Model manager button
            GestureDetector(
              onTap: _openModelManager,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withOpacity(0.3)),
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: _accent, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            // Clear chat
            if (_messages.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _messages.clear()),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_sweep_rounded,
                      color: Colors.white38, size: 20),
                ),
              ),
          ],
        ),
      );

  // ── Model banner ─────────────────────────────────────────────────────────────
  Widget _buildModelBanner() {
    final name = _activeModelPath?.split('/').last ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: _accent.withOpacity(0.06),
      child: Row(
        children: [
          const Icon(Icons.storage_rounded, color: Colors.white24, size: 13),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white30, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: _openModelManager,
            child: const Text('Change',
                style: TextStyle(color: _accent, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  // ── Message list ─────────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    if (_messages.isEmpty) return _buildEmptyState();

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text('RAMA AI',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(
              _activeModelPath == null
                  ? 'Download a model to start chatting'
                  : 'Your private AI, fully offline',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            if (_activeModelPath == null) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _openModelManager,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Download a Model',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _buildBubble(ChatMessage msg) {
    final isUser  = msg.role == 'user';
    final isError = msg.role == 'error';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.80),
        decoration: BoxDecoration(
          color: isUser
              ? _userBubble
              : isError
                  ? Colors.red.withOpacity(0.15)
                  : _surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isError
              ? Border.all(color: Colors.red.withOpacity(0.4))
              : isUser
                  ? null
                  : Border.all(color: Colors.white10),
          boxShadow: [
            if (isUser)
              BoxShadow(
                color: _accent.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 10),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isError ? 'Error' : 'Rama',
                    style: TextStyle(
                      color: isError ? Colors.red : _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            SelectableText(
              msg.text,
              style: TextStyle(
                color: isUser
                    ? Colors.white
                    : isError
                        ? Colors.red[300]
                        : Colors.white.withOpacity(0.87),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Typing indicator ─────────────────────────────────────────────────────────
  Widget _buildTypingIndicator() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 10),
            ),
            const SizedBox(width: 8),
            ...List.generate(
              3,
              (i) => AnimatedBuilder(
                animation: _typingAnim,
                builder: (_, __) {
                  final phase = (_typingAnim.value + i * 0.3).clamp(0.0, 1.0);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.3 + phase * 0.7),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text('Thinking…',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );

  // ── Input bar ─────────────────────────────────────────────────────────────────
  Widget _buildInput() => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF12122A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  maxLines: 4,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: 'Ask something…',
                    hintStyle: TextStyle(color: Colors.white24),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _thinking ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: _thinking
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: _thinking ? Colors.white12 : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: _thinking ? Colors.white24 : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      );

  void _openModelManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModelManagerScreen(
          activeModelPath: _activeModelPath,
          onModelSelected: _setActiveModel,
        ),
      ),
    ).then((_) => _refreshModels());
  }
}