import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import '../models/chat_message.dart';
import '../services/llm_service.dart';
import '../storage/chat_storage.dart';
import '../utils/response_cleaner.dart';
import '../widgets/shared_widgets.dart';
import 'profile_setup_screen.dart';
import 'model_manager_screen.dart';

// NOTE: compute() / background isolates are intentionally NOT used here.
// FFI (libllama_lib.so) must be called from the root isolate on Android;
// using compute() causes a native crash on the second call.  Instead we
// schedule the blocking FFI call on the platform thread pool via Future.

// ─── Chat Screen ──────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  // Controllers
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final _focus  = FocusNode();

  // Current session
  final List<ChatMessage> _messages = [];
  bool    _thinking      = false;
  bool    _inputFocused  = false;
  String? _activeModelPath;

  // Chat history (SQLite)
  List<Conversation> _conversations = [];
  int?   _currentConvId;
  bool   _historyLoading = false;

  // Sidebar state
  bool _sidebarOpen = false;
  late final AnimationController _sidebarCtrl;
  late final Animation<double>    _sidebarAnim;

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

    _sidebarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _sidebarAnim = CurvedAnimation(
      parent: _sidebarCtrl,
      curve:  Curves.easeOutCubic,
    );

    _focus.addListener(() => setState(() => _inputFocused = _focus.hasFocus));
    appTheme.addListener(() { if (mounted) setState(() {}); });

    _init();
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _sidebarCtrl.dispose();
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
    await _loadConversations();
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

  // ── Chat history ──────────────────────────────────────────────────────────────

  Future<void> _loadConversations() async {
    setState(() => _historyLoading = true);
    final convs = await ChatStorage.listConversations();
    if (mounted) setState(() { _conversations = convs; _historyLoading = false; });
  }

  Future<void> _startNewChat() async {
    setState(() {
      _messages.clear();
      _currentConvId = null;
    });
    if (_sidebarOpen) _toggleSidebar();
  }

  Future<void> _loadConversation(Conversation conv) async {
    setState(() { _messages.clear(); _currentConvId = conv.id; });
    if (_sidebarOpen) _toggleSidebar();

    final stored = await ChatStorage.loadMessages(conv.id!);
    final msgs   = stored.map((s) => ChatMessage(
      _roleFromString(s.role),
      s.text,
      time: s.time,
    )).toList();

    if (mounted) {
      setState(() => _messages.addAll(msgs));
      _scrollToBottom();
    }
  }

  Future<void> _deleteConversation(Conversation conv) async {
    await ChatStorage.deleteConversation(conv.id!);
    if (_currentConvId == conv.id) {
      setState(() { _messages.clear(); _currentConvId = null; });
    }
    await _loadConversations();
  }

  MessageRole _roleFromString(String r) {
    switch (r) {
      case 'user':  return MessageRole.user;
      case 'error': return MessageRole.error;
      default:      return MessageRole.ai;
    }
  }

  // ── Send ─────────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _thinking) return;

    if (_activeModelPath == null) {
      setState(() => _messages.add(ChatMessage(
        MessageRole.error,
        '⚠️ No model loaded. Tap ⚙️ to download or import one.',
      )));
      _scrollToBottom();
      return;
    }

    // Ensure conversation exists
    if (_currentConvId == null) {
      final id = await ChatStorage.createConversation(
        title: text.length > 40 ? '${text.substring(0, 38)}…' : text,
      );
      if (mounted) setState(() => _currentConvId = id);
    }

    _ctrl.clear();
    final userMsg = ChatMessage(MessageRole.user, text);
    setState(() { _messages.add(userMsg); _thinking = true; });
    _scrollToBottom();

    // Persist user message
    await ChatStorage.insertMessage(StoredMessage(
      conversationId: _currentConvId!,
      role:           'user',
      text:           text,
      time:           userMsg.time,
    ));

    // Build context-aware prompt (last 8 messages)
    final contextMsgs = await ChatStorage.lastMessages(_currentConvId!, 8);
    final prompt      = _buildContextPrompt(contextMsgs, text);

    final String modelPath = _activeModelPath!;
    final String reply;

    try {
      // Run the blocking FFI call safely in a dedicated Isolate.
      // LLMService.runInference() handles isolate lifecycle and the
      // re-entrant guard (_busy flag) to prevent the second-message crash.
      final raw = await LLMService.runInference(modelPath, prompt);
      reply = cleanLLMResponse(raw);
    } catch (e) {
      final errMsg = ChatMessage(MessageRole.error, 'Error: $e');
      if (mounted) {
        setState(() { _messages.add(errMsg); _thinking = false; });
        await ChatStorage.insertMessage(StoredMessage(
          conversationId: _currentConvId!,
          role:           'error',
          text:           'Error: $e',
          time:           errMsg.time,
        ));
        _scrollToBottom();
      }
      return;
    }

    if (!mounted) return;
    final aiRole = reply.startsWith('Error:') ? MessageRole.error : MessageRole.ai;
    final aiMsg  = ChatMessage(aiRole, reply);
    setState(() { _messages.add(aiMsg); _thinking = false; });
    _scrollToBottom();

    // Persist AI response
    await ChatStorage.insertMessage(StoredMessage(
      conversationId: _currentConvId!,
      role:           aiRole == MessageRole.error ? 'error' : 'ai',
      text:           reply,
      time:           aiMsg.time,
    ));

    // Update conversation title from first exchange if still "New Chat"
    final conv = _conversations.firstWhere(
      (c) => c.id == _currentConvId,
      orElse: () => Conversation(
        id: _currentConvId, title: '', createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ),
    );
    if (conv.title.isEmpty || conv.title == 'New Chat') {
      await ChatStorage.updateTitle(
        _currentConvId!,
        text.length > 40 ? '${text.substring(0, 38)}…' : text,
      );
    }

    await _loadConversations();
  }

  /// Builds a context-injected prompt from recent conversation history.
  String _buildContextPrompt(List<StoredMessage> history, String currentInput) {
    if (history.isEmpty) return currentInput;
    final buf = StringBuffer();
    for (final msg in history) {
      if (msg.role == 'user') {
        buf.write('User: ${msg.text}\n');
      } else if (msg.role == 'ai') {
        buf.write('Assistant: ${msg.text}\n');
      }
    }
    buf.write('User: $currentInput\nAssistant:');
    return buf.toString();
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

  // ── Sidebar ───────────────────────────────────────────────────────────────────
  void _toggleSidebar() {
    if (_sidebarOpen) {
      _sidebarCtrl.reverse().then((_) {
        if (mounted) setState(() => _sidebarOpen = false);
      });
    } else {
      setState(() => _sidebarOpen = true);
      _sidebarCtrl.forward();
    }
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
        child: Stack(
          children: [
            // ── Main chat area ─────────────────────────────────────────────
            Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _focus.unfocus();
                      if (_sidebarOpen) _toggleSidebar();
                    },
                    child: _messages.isEmpty && !_thinking
                        ? _buildEmptyState()
                        : _buildMessageList(),
                  ),
                ),
                if (_thinking) _buildThinkingBar(),
                _buildInputArea(),
              ],
            ),

            // ── Sidebar overlay ────────────────────────────────────────────
            if (_sidebarOpen) ...[
              // Dim scrim
              FadeTransition(
                opacity: _sidebarAnim,
                child: GestureDetector(
                  onTap: _toggleSidebar,
                  child: Container(color: Colors.black.withValues(alpha: 0.50)),
                ),
              ),
              // Drawer panel
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-1, 0),
                  end:   Offset.zero,
                ).animate(_sidebarAnim),
                child: _buildSidebar(),
              ),
            ],
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
        color:  _surface,
        border: Border(bottom: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: appTheme.isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sidebar toggle (hamburger)
          RamaIconBtn(
            icon:    Icons.menu_rounded,
            tooltip: 'Chat history',
            color:   _sub, bg: _card, border: _border,
            onTap:   _toggleSidebar,
          ),
          const SizedBox(width: 10),
          Hero(tag: 'rama_logo', child: LogoBadge(size: 36, accent: _accent)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment:  MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RAMA AI',
                    style: TextStyle(
                      color:       _text,
                      fontWeight:  FontWeight.w800,
                      fontSize:    15,
                      letterSpacing: 0.8,
                    )),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _modelName(),
                    key:      ValueKey(_activeModelPath),
                    style:    TextStyle(color: _sub, fontSize: 10.5),
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

          // New chat
          RamaIconBtn(
            icon:    Icons.add_comment_rounded,
            tooltip: 'New chat',
            color:   _accent, bg: _card, border: _border,
            onTap:   _startNewChat,
          ),
          const SizedBox(width: 6),

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
                statusBarColor:          Colors.transparent,
                statusBarIconBrightness: appTheme.isDark ? Brightness.light : Brightness.dark,
              ));
            },
          ),
          const SizedBox(width: 6),

          // Model manager
          RamaIconBtn(
            icon:    Icons.tune_rounded,
            tooltip: 'Model Manager',
            color:   _accent, bg: _card, border: _border,
            onTap:   _openModelManager,
          ),
          const SizedBox(width: 6),

          // Profile
          RamaIconBtn(
            icon:    Icons.manage_accounts_rounded,
            tooltip: 'Edit Profile',
            color:   _accent, bg: _card, border: _border,
            onTap:   _openProfile,
          ),
        ],
      ),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    final sideW = MediaQuery.of(context).size.width * 0.80;
    return Container(
      width:   sideW.clamp(240.0, 320.0),
      height:  double.infinity,
      color:   _surface,
      child: Column(
        children: [
          // Sidebar header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                LogoBadge(size: 34, accent: _accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chat History',
                    style: TextStyle(
                      color:      _text,
                      fontWeight: FontWeight.w800,
                      fontSize:   16,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _toggleSidebar,
                  child: Icon(Icons.close_rounded, color: _sub, size: 22),
                ),
              ],
            ),
          ),

          // New chat button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: GestureDetector(
              onTap: _startNewChat,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accent, _accent.withValues(alpha: 0.75)],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color:      _accent.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset:     const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'New Chat',
                      style: TextStyle(
                        color:      Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize:   14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Conversation list
          Expanded(
            child: _historyLoading
                ? Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2))
                : _conversations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                color: _dim, size: 36),
                            const SizedBox(height: 10),
                            Text('No chats yet',
                                style: TextStyle(color: _sub, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Start a conversation!',
                                style: TextStyle(color: _dim, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        itemCount: _conversations.length,
                        itemBuilder: (ctx, i) =>
                            _conversationTile(_conversations[i]),
                      ),
          ),

          // User profile row at bottom
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color:         _accent.withValues(alpha: 0.15),
                    borderRadius:  BorderRadius.circular(10),
                    border:        Border.all(color: _accent.withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: Text(
                      _kAvatarEmojis[_userAvatar.clamp(0, _kAvatarEmojis.length - 1)],
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName,
                          style: TextStyle(
                            color:      _text,
                            fontWeight: FontWeight.w600,
                            fontSize:   13,
                          )),
                      Text('${_conversations.length} conversation(s)',
                          style: TextStyle(color: _dim, fontSize: 10.5)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () { _toggleSidebar(); _openProfile(); },
                  child: Icon(Icons.settings_rounded, color: _sub, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _conversationTile(Conversation conv) {
    final isActive  = conv.id == _currentConvId;
    final updatedAt = conv.updatedAt;
    final now       = DateTime.now();
    final dateLabel = now.difference(updatedAt).inDays == 0
        ? '${updatedAt.hour.toString().padLeft(2, '0')}:'
          '${updatedAt.minute.toString().padLeft(2, '0')}'
        : '${updatedAt.day}/${updatedAt.month}';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color:         isActive ? _accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius:  BorderRadius.circular(12),
        border:        isActive
            ? Border.all(color: _accent.withValues(alpha: 0.3))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _loadConversation(conv),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: isActive ? _accent : _dim,
                  size:  16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conv.title.isEmpty ? 'New Chat' : conv.title,
                        style: TextStyle(
                          color:      isActive ? _accent : _text,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          fontSize:   13,
                        ),
                        maxLines:  1,
                        overflow:  TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(dateLabel,
                          style: TextStyle(color: _dim, fontSize: 10)),
                    ],
                  ),
                ),
                // Delete button
                GestureDetector(
                  onTap: () => _confirmDelete(conv),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(Icons.delete_outline_rounded,
                        color: _dim, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Conversation conv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete chat?',
            style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
        content: Text(
          '"${conv.title.isEmpty ? 'New Chat' : conv.title}"\nThis action cannot be undone.',
          style: TextStyle(color: _sub, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: _sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) await _deleteConversation(conv);
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

          // Greeting card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accent.withValues(alpha: 0.15),
                  _accent.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
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
                        color:      _text,
                        fontSize:   18,
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
                  color:      _sub,
                  fontSize:   14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          if (_activeModelPath == null) ...[
            ActionCard(
              icon:     Icons.download_rounded,
              title:    'Load a Model',
              subtitle: 'Download or import a .gguf model file',
              color:    _accent,
              onTap:    _openModelManager,
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                'TRY ASKING',
                style: TextStyle(
                  color:         _dim,
                  fontSize:      10,
                  fontWeight:    FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            ..._kSuggestions.map(
              (s) => SuggestionChip(
                label: s,
                card: _card, border: _border,
                text: _text, sub: _sub, dim: _dim,
                onTap: () { _ctrl.text = s; _send(); },
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
      padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      itemCount:  _messages.length,
      itemBuilder: (ctx, i) {
        final msg    = _messages[i];
        final isLast = i == _messages.length - 1;
        // Play typewriter animation only on the latest AI reply while
        // the model is NOT still thinking (i.e. the reply just arrived).
        final isStreaming = isLast &&
            msg.role == MessageRole.ai &&
            !_thinking;
        return MessageBubble(
          key:             ValueKey('${msg.time.millisecondsSinceEpoch}_$i'),
          message:         msg,
          isLast:          isLast,
          isStreaming:     isStreaming,
          userName:        _userName,
          userAvatarEmoji: _kAvatarEmojis[_userAvatar.clamp(0, _kAvatarEmojis.length - 1)],
          accent:          _accent,
          isDark:          appTheme.isDark,
          card:            _card,
          border:          _border,
          textColor:       _text,
          subColor:        _sub,
          dimColor:        _dim,
        );
      },
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
            builder:  (ctx, _) => Row(
              children: List.generate(3, (i) {
                final phase   = ((_dotAnim.value * 3) - i) % 3;
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
        color:  _surface,
        border: Border(
          top: BorderSide(
            color: _inputFocused ? _accent.withValues(alpha: 0.4) : _border,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: appTheme.isDark ? 0.25 : 0.06),
            blurRadius: 16,
            offset:     const Offset(0, -4),
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
                color:         _card,
                borderRadius:  BorderRadius.circular(20),
                border: Border.all(
                  color: _inputFocused
                      ? _accent.withValues(alpha: 0.5)
                      : _border,
                  width: 1.2,
                ),
              ),
              child: TextField(
                controller:      _ctrl,
                focusNode:       _focus,
                style:           TextStyle(color: _text, fontSize: 14.5, height: 1.45),
                maxLines:        null,
                keyboardType:    TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText:       'Message Rama AI…',
                  hintStyle:      TextStyle(color: _dim, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  border:         InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SendButton(
            enabled:  _ctrl.text.trim().isNotEmpty && !_thinking,
            thinking: _thinking,
            accent:   _accent, card: _card, border: _border,
            onTap:    _send,
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
