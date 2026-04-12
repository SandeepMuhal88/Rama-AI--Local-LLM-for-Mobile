import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'llm_service.dart';
import 'model_manager_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class RamaColors {
  static const bg        = Color(0xFF080814);
  static const surface   = Color(0xFF10101F);
  static const card      = Color(0xFF161628);
  static const border    = Color(0xFF252540);
  static const accent    = Color(0xFF7C6EF5);
  static const accentAlt = Color(0xFF9B7EFF);
  static const userBg    = Color(0xFF2A2060);
  static const error     = Color(0xFFE57373);
  static const text      = Color(0xFFEAEAF8);
  static const textSub   = Color(0xFF8888AA);
  static const textDim   = Color(0xFF44445A);
}

// ─── Isolate helper – runs LLM on a separate thread so UI never freezes ───────
Future<String> _runInference(List<String> args) async {
  // args[0] = modelPath, args[1] = prompt
  final svc = LLMService();
  return svc.run(args[0], args[1]);
}

// ─── App ──────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: RamaColors.bg,
  ));
  runApp(const RamaApp());
}

class RamaApp extends StatelessWidget {
  const RamaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RAMA AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: RamaColors.bg,
        fontFamily: 'sans-serif',
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: RamaColors.accent,
          surface: RamaColors.surface,
          onSurface: RamaColors.text,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: RamaColors.accent,
          selectionColor: Color(0x557C6EF5),
          selectionHandleColor: RamaColors.accent,
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

// ─── Message model ────────────────────────────────────────────────────────────
enum MessageRole { user, ai, error }

class ChatMessage {
  final MessageRole role;
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
  final TextEditingController _ctrl  = TextEditingController();
  final ScrollController       _scroll = ScrollController();
  final FocusNode              _focus = FocusNode();

  final List<ChatMessage> _messages = [];
  bool   _thinking        = false;
  bool   _inputFocused    = false;
  String? _activeModelPath;

  // Dots animation for "thinking" indicator
  late AnimationController _dotCtrl;
  late Animation<double>   _dotAnim;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _dotAnim = Tween<double>(begin: 0, end: 1).animate(_dotCtrl);

    _focus.addListener(() => setState(() => _inputFocused = _focus.hasFocus));
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

  // ── Send ─────────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _thinking) return;

    if (_activeModelPath == null) {
      setState(() => _messages.add(
            ChatMessage(MessageRole.error,
                '⚠️ No model loaded. Tap the brain icon to add one.'),
          ));
      _scrollToBottom();
      return;
    }

    _ctrl.clear();
    setState(() {
      _messages.add(ChatMessage(MessageRole.user, text));
      _thinking = true;
    });
    _scrollToBottom();

    // Snapshot path + prompt as plain Strings before the background call.
    // compute() sends _runInference as a direct top-level function reference
    // (no closure → no `this` → no AnimationController → no crash).
    final String modelPath  = _activeModelPath!;
    final String userPrompt = text;

    final String reply;
    try {
      reply = await compute(_runInference, [modelPath, userPrompt]);
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
          _scroll.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _modelName() {
    if (_activeModelPath == null) return 'No model';
    final filename = _activeModelPath!.split('/').last;
    // Shorten to meaningful name
    return filename.length > 30 ? '${filename.substring(0, 28)}…' : filename;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RamaColors.bg,
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
        color: RamaColors.surface,
        border: const Border(
          bottom: BorderSide(color: RamaColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo
          _LogoBadge(),
          const SizedBox(width: 10),
          // Title + model name
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RAMA AI',
                  style: TextStyle(
                    color: RamaColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.8,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _activeModelPath != null
                        ? _modelName()
                        : '100% Offline · On-device',
                    key: ValueKey(_activeModelPath),
                    style: const TextStyle(
                      color: RamaColors.textSub,
                      fontSize: 10.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Status dot
          Container(
            width: 8,
            height: 8,
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
          // Model manager
          _IconBtn(
            icon: Icons.tune_rounded,
            tooltip: 'Model Manager',
            color: RamaColors.accent,
            onTap: _openModelManager,
          ),
          const SizedBox(width: 6),
          // Clear
          if (_messages.isNotEmpty)
            _IconBtn(
              icon: Icons.delete_sweep_rounded,
              tooltip: 'Clear chat',
              color: RamaColors.textSub,
              onTap: () => setState(() => _messages.clear()),
            ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          _LogoBadge(size: 88),
          const SizedBox(height: 24),
          const Text(
            'RAMA AI',
            style: TextStyle(
              color: RamaColors.text,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _activeModelPath != null
                ? 'Your private AI — fully offline & on-device'
                : 'Add a model to start chatting',
            style: const TextStyle(
              color: RamaColors.textSub,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (_activeModelPath == null) ...[
            _ActionCard(
              icon: Icons.download_rounded,
              title: 'Load a Model',
              subtitle: 'Browse your device for a .gguf model file',
              color: RamaColors.accent,
              onTap: _openModelManager,
            ),
          ] else ...[
            // Quick-start prompts
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'TRY ASKING',
                style: TextStyle(
                  color: RamaColors.textDim,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            ..._kSuggestions.map(
              (s) => _SuggestionChip(
                label: s,
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

  static const _kSuggestions = [
    'What is machine learning?',
    'Write a Python function to reverse a string',
    'Explain quantum computing in simple terms',
    'What are the benefits of meditation?',
  ];

  // ── Message list ──────────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _MessageBubble(
        message: _messages[i],
        isLast: i == _messages.length - 1,
      ),
    );
  }

  // ── Thinking bar ────────────────────────────────────────────────────────────
  Widget _buildThinkingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _LogoBadge(size: 28),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: _dotAnim,
            builder: (context2, child2) => Row(
              children: List.generate(3, (i) {
                final phase = (((_dotAnim.value * 3) - i) % 3 + 3) % 3;
                final opacity = (phase < 1)
                    ? phase
                    : (phase < 2)
                        ? 1.0
                        : 3.0 - phase;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: RamaColors.accent.withValues(alpha: 
                        (0.25 + opacity.clamp(0.0, 1.0) * 0.75)),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Generating response…',
            style: TextStyle(color: RamaColors.textSub, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  // ── Input area ────────────────────────────────────────────────────────────────
  Widget _buildInputArea() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: RamaColors.surface,
        border: Border(
          top: BorderSide(
            color: _inputFocused
                ? RamaColors.accent.withValues(alpha: 0.4)
                : RamaColors.border,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: RamaColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _inputFocused
                      ? RamaColors.accent.withValues(alpha: 0.5)
                      : RamaColors.border,
                  width: 1.2,
                ),
              ),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                style: const TextStyle(
                  color: RamaColors.text,
                  fontSize: 14.5,
                  height: 1.45,
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Message Rama AI…',
                  hintStyle: TextStyle(color: RamaColors.textDim, fontSize: 14),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          _SendButton(
            enabled: _ctrl.text.trim().isNotEmpty && !_thinking,
            thinking: _thinking,
            onTap: _send,
          ),
        ],
      ),
    );
  }

  void _openModelManager() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx2, a, ctx3) => ModelManagerScreen(
          activeModelPath: _activeModelPath,
          onModelSelected: _setActiveModel,
        ),
        transitionsBuilder: (ctx2, anim, ctx3, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    ).then((_) => _refreshModels());
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _LogoBadge extends StatelessWidget {
  final double size;
  const _LogoBadge({this.size = 38});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [RamaColors.accent, RamaColors.accentAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: RamaColors.accent.withValues(alpha: 0.35),
            blurRadius: size * 0.45,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: size * 0.47,
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String   tooltip;
  final Color    color;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData    icon;
  final String      title;
  final String      subtitle;
  final Color       color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white70, size: 22),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: RamaColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: RamaColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded,
                color: RamaColors.textSub, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: RamaColors.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(Icons.north_east_rounded,
                color: RamaColors.textDim, size: 15),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool         enabled;
  final bool         thinking;
  final VoidCallback onTap;
  const _SendButton({
    required this.enabled,
    required this.thinking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [RamaColors.accent, RamaColors.accentAlt],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : RamaColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: enabled
                  ? Colors.transparent
                  : RamaColors.border),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: RamaColors.accent.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Icon(
          thinking ? Icons.hourglass_top_rounded : Icons.arrow_upward_rounded,
          color: enabled ? Colors.white : RamaColors.textDim,
          size: 22,
        ),
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────
class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool        isLast;
  const _MessageBubble({required this.message, required this.isLast});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.message.text));
    if (mounted) setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final msg     = widget.message;
    final isUser  = msg.role == MessageRole.user;
    final isError = msg.role == MessageRole.error;
    final width   = MediaQuery.of(context).size.width;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // AI avatar
              if (!isUser) ...[
                _LogoBadge(size: 28),
                const SizedBox(width: 8),
              ],
              // Bubble
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Sender label
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                      child: Text(
                        isUser
                            ? 'You'
                            : isError
                                ? 'Error'
                                : 'Rama AI',
                        style: TextStyle(
                          color: isError
                              ? RamaColors.error
                              : isUser
                                  ? RamaColors.accentAlt
                                  : RamaColors.textSub,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    // Content
                    Container(
                      constraints:
                          BoxConstraints(maxWidth: width * 0.82),
                      decoration: BoxDecoration(
                        gradient: isUser
                            ? const LinearGradient(
                                colors: [
                                  RamaColors.userBg,
                                  Color(0xFF3A2A80),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isUser
                            ? null
                            : isError
                                ? const Color(0xFF2A1010)
                                : RamaColors.card,
                        borderRadius: BorderRadius.only(
                          topLeft:
                              const Radius.circular(18),
                          topRight:
                              const Radius.circular(18),
                          bottomLeft:
                              Radius.circular(isUser ? 18 : 4),
                          bottomRight:
                              Radius.circular(isUser ? 4 : 18),
                        ),
                        border: isUser
                            ? null
                            : Border.all(
                                color: isError
                                    ? RamaColors.error
                                        .withValues(alpha: 0.4)
                                    : RamaColors.border,
                                width: 1,
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: isUser
                                ? RamaColors.accent
                                    .withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 11),
                      child: SelectableText(
                        msg.text,
                        style: TextStyle(
                          color: isError
                              ? RamaColors.error
                              : RamaColors.text,
                          fontSize: 14,
                          height: 1.55,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    // Timestamp + copy
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 4, left: 4, right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _fmtTime(msg.time),
                            style: const TextStyle(
                              color: RamaColors.textDim,
                              fontSize: 10,
                            ),
                          ),
                          if (!isUser) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _copy,
                              child: Row(
                                children: [
                                  Icon(
                                    _copied
                                        ? Icons.check_rounded
                                        : Icons.copy_rounded,
                                    color: _copied
                                        ? const Color(
                                            0xFF4CAF50)
                                        : RamaColors.textDim,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _copied ? 'Copied' : 'Copy',
                                    style: TextStyle(
                                      color: _copied
                                          ? const Color(
                                              0xFF4CAF50)
                                          : RamaColors.textDim,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // User avatar
              if (isUser) ...[
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: RamaColors.userBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            RamaColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: RamaColors.accentAlt,
                    size: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtTime(DateTime t) {
    final h  = t.hour.toString().padLeft(2, '0');
    final m  = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
