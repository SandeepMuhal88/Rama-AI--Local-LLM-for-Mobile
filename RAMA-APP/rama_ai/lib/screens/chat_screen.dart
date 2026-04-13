import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import '../models/chat_message.dart';
import '../services/llm_service.dart';
import '../utils/response_cleaner.dart';
import '../widgets/shared_widgets.dart';
import 'profile_setup_screen.dart';
import 'model_manager_screen.dart';

// ─── Isolate helper (top-level so compute() can serialize it) ─────────────────
Future<String> runInferenceIsolate(List<String> args) async {
  final svc = LLMService();
  final raw  = await svc.run(args[0], args[1]);
  return cleanLLMResponse(raw);
}

// ─── Chat Screen ──────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final _focus  = FocusNode();

  final List<ChatMessage> _messages = [];
  bool    _thinking     = false;
  bool    _inputFocused = false;
  String? _activeModelPath;

  // User profile
  String _userName   = '';
  int    _userAvatar = 0;

  // Thinking-dots animation
  late AnimationController _dotCtrl;
  late Animation<double>   _dotAnim;

  static const _kAvatarEmojis = ['🧑', '👩', '👨', '🧙', '🦸', '🤖', '🦊', '🐼'];
  static const _kSuggestions  = [
    'What is machine learning?',
    'Write a Python function to reverse a string',
    'Explain quantum computing in simple terms',
    'What are the benefits of meditation?',
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _dotAnim = Tween<double>(begin: 0, end: 1).animate(_dotCtrl);

    _focus.addListener(() => setState(() => _inputFocused = _focus.hasFocus));
    appTheme.addListener(() { if (mounted) setState(() {}); });

    _init();
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _requestPermissions();
    await _loadProfile();
    await _loadSavedModel();
    await _refreshModels();
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName   = prefs.getString('user_name') ?? 'Friend';
      _userAvatar = prefs.getInt('user_avatar')  ?? 0;
    });
  }

  Future<void> _loadSavedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('active_model_path');
    if (saved != null && File(saved).existsSync()) {
      if (mounted) setState(() => _activeModelPath = saved);
    }
  }

  Future<void> _refreshModels() async {
    final models = await LLMService.listModels();
    if (!mounted) return;
    if (_activeModelPath == null && models.isNotEmpty) {
      await _setActiveModel(models.first.path);
    } else {
      setState(() {});
    }
  }

  Future<void> _setActiveModel(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_model_path', path);
    if (mounted) setState(() => _activeModelPath = path);
  }

  // ── Greeting ─────────────────────────────────────────────────────────────────
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5)  return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }

  String get _greetingEmoji {
    final h = DateTime.now().hour;
    if (h < 5)  return '🌙';
    if (h < 12) return '☀️';
    if (h < 17) return '🌤';
    if (h < 21) return '🌆';
    return '🌙';
  }

  // ── Send ─────────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _thinking) return;

    if (_activeModelPath == null) {
      setState(() => _messages.add(ChatMessage(
            MessageRole.error,
            '⚠️ No model loaded. Tap ⚙️ to add one.',
          )));
      _scrollToBottom();
      return;
    }

    _ctrl.clear();
    setState(() {
      _messages.add(ChatMessage(MessageRole.user, text));
      _thinking = true;
    });
    _scrollToBottom();

    final String modelPath  = _activeModelPath!;
    final String userPrompt = text;
    final String reply;

    try {
      reply = await compute(runInferenceIsolate, [modelPath, userPrompt]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(MessageRole.error, 'Error: $e'));
          _thinking = false;
        });
        _scrollToBottom();
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        reply.startsWith('Error:') ? MessageRole.error : MessageRole.ai,
        reply,
      ));
      _thinking = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // ── Theme helpers ─────────────────────────────────────────────────────────────
  Color get _bg      => appTheme.isDark ? RamaColors.darkBg      : RamaColors.lightBg;
  Color get _surface => appTheme.isDark ? RamaColors.darkSurface  : RamaColors.lightSurface;
  Color get _card    => appTheme.isDark ? RamaColors.darkCard     : RamaColors.lightCard;
  Color get _border  => appTheme.isDark ? RamaColors.darkBorder   : RamaColors.lightBorder;
  Color get _text    => appTheme.isDark ? RamaColors.darkText     : RamaColors.lightText;
  Color get _sub     => appTheme.isDark ? RamaColors.darkTextSub  : RamaColors.lightTextSub;
  Color get _dim     => appTheme.isDark ? RamaColors.darkTextDim  : RamaColors.lightTextDim;
  Color get _accent  => appTheme.accent;

  String _modelName() {
    if (_activeModelPath == null) return 'No model loaded';
    final fn = _activeModelPath!.split('/').last;
    return fn.length > 30 ? '${fn.substring(0, 28)}…' : fn;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: GestureDetector(
                onTap: () => _focus.unfocus(),
                child: _messages.isEmpty && !_thinking
                    ? _buildEmptyState()
                    : _buildMessageList(),
              ),
            ),
            if (_thinking) _buildThinkingBar(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: appTheme.isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Hero(tag: 'rama_logo', child: LogoBadge(size: 38, accent: _accent)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RAMA AI',
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.8,
                    )),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _modelName(),
                    key: ValueKey(_activeModelPath),
                    style: TextStyle(color: _sub, fontSize: 10.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Status dot
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _activeModelPath != null
                  ? const Color(0xFF4CAF50)
                  : Colors.orange,
              boxShadow: [
                BoxShadow(
                  color: (_activeModelPath != null
                          ? const Color(0xFF4CAF50)
                          : Colors.orange)
                      .withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          // Dark/light toggle
          RamaIconBtn(
            icon: appTheme.isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            tooltip: appTheme.isDark ? 'Light mode' : 'Dark mode',
            color: _accent, bg: _card, border: _border,
            onTap: () async {
              appTheme.toggle();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('theme_dark', appTheme.isDark);
              SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    appTheme.isDark ? Brightness.light : Brightness.dark,
              ));
            },
          ),
          const SizedBox(width: 6),
          // Model manager
          RamaIconBtn(
            icon: Icons.tune_rounded,
            tooltip: 'Model Manager',
            color: _accent, bg: _card, border: _border,
            onTap: _openModelManager,
          ),
          const SizedBox(width: 6),
          // Profile
          RamaIconBtn(
            icon: Icons.manage_accounts_rounded,
            tooltip: 'Edit Profile',
            color: _accent, bg: _card, border: _border,
            onTap: _openProfile,
          ),
          const SizedBox(width: 6),
          // Clear
          if (_messages.isNotEmpty)
            RamaIconBtn(
              icon: Icons.delete_sweep_rounded,
              tooltip: 'Clear chat',
              color: _sub, bg: _card, border: _border,
              onTap: () => setState(() => _messages.clear()),
            ),
        ],
      ),
    );
  }

  // ── Empty / Greeting State ────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LogoBadge(size: 84, accent: _accent),
          const SizedBox(height: 22),

          // Personalised greeting card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accent.withValues(alpha: 0.15),
                  _accent.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_greetingEmoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_greeting, $_userName!',
                      style: TextStyle(
                        color: _text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      "I'm ready — what's on your mind?",
                      style: TextStyle(color: _sub, fontSize: 12.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Avatar + name row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _kAvatarEmojis[_userAvatar.clamp(0, _kAvatarEmojis.length - 1)],
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                _userName,
                style: TextStyle(
                  color: _sub,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          if (_activeModelPath == null) ...[
            ActionCard(
              icon: Icons.download_rounded,
              title: 'Load a Model',
              subtitle: 'Browse your device for a .gguf model file',
              color: _accent,
              onTap: _openModelManager,
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                'TRY ASKING',
                style: TextStyle(
                  color: _dim,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            ..._kSuggestions.map(
              (s) => SuggestionChip(
                label: s,
                card: _card, border: _border,
                text: _text, sub: _sub, dim: _dim,
                onTap: () {
                  _ctrl.text = s;
                  _send();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) => MessageBubble(
        message: _messages[i],
        isLast: i == _messages.length - 1,
        userName: _userName,
        userAvatarEmoji:
            _kAvatarEmojis[_userAvatar.clamp(0, _kAvatarEmojis.length - 1)],
        accent: _accent,
        isDark: appTheme.isDark,
        card: _card,
        border: _border,
        textColor: _text,
        subColor: _sub,
        dimColor: _dim,
      ),
    );
  }

  // ── Thinking bar ──────────────────────────────────────────────────────────────
  Widget _buildThinkingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          LogoBadge(size: 28, accent: _accent),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: _dotAnim,
            builder: (ctx, child2) => Row(
              children: List.generate(3, (i) {
                final phase =
                    (((_dotAnim.value * 3) - i) % 3 + 3) % 3;
                final opacity = phase < 1
                    ? phase
                    : (phase < 2 ? 1.0 : 3.0 - phase);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent.withValues(
                        alpha: 0.25 + opacity.clamp(0.0, 1.0) * 0.75),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 10),
          Text('Generating response…',
              style: TextStyle(color: _sub, fontSize: 12.5)),
        ],
      ),
    );
  }

  // ── Input area ────────────────────────────────────────────────────────────────
  Widget _buildInputArea() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(
          top: BorderSide(
            color: _inputFocused ? _accent.withValues(alpha: 0.4) : _border,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: appTheme.isDark ? 0.25 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _inputFocused
                      ? _accent.withValues(alpha: 0.5)
                      : _border,
                  width: 1.2,
                ),
              ),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                style: TextStyle(color: _text, fontSize: 14.5, height: 1.45),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Message Rama AI…',
                  hintStyle: TextStyle(color: _dim, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SendButton(
            enabled: _ctrl.text.trim().isNotEmpty && !_thinking,
            thinking: _thinking,
            accent: _accent, card: _card, border: _border,
            onTap: _send,
          ),
        ],
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────────
  void _openModelManager() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx2, a1, a2) => ModelManagerScreen(
          activeModelPath: _activeModelPath,
          onModelSelected: _setActiveModel,
        ),
        transitionsBuilder: (ctx2, anim, a2, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1), end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    ).then((_) => _refreshModels());
  }

  void _openProfile() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx2, a1, a2) => const ProfileSetupScreen(),
        transitionsBuilder: (ctx2, anim, a2, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1), end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    ).then((_) => _loadProfile());
  }
}
