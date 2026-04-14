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

// NOTE: FFI (libllama_lib.so) must be called from the root isolate on Android.
// We use Isolate.run() inside LLMService which handles this safely.

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────────────────
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final _focus  = FocusNode();

  // ── State ─────────────────────────────────────────────────────────────────
  final List<ChatMessage> _messages = [];
  bool    _thinking     = false;
  bool    _focused      = false;
  String? _activeModelPath;

  // ── Chat history ──────────────────────────────────────────────────────────
  List<Conversation> _conversations = [];
  int?   _currentConvId;
  bool   _historyLoading = false;

  // ── Sidebar ───────────────────────────────────────────────────────────────
  bool _sidebarOpen = false;
  late final AnimationController _sidebarCtrl;
  late final Animation<double>   _sidebarAnim;

  // ── Thinking dots ─────────────────────────────────────────────────────────
  late AnimationController _dotCtrl;

  // ── User profile ──────────────────────────────────────────────────────────
  String _userName   = '';
  int    _userAvatar = 0;

  static const _kAvatarEmojis = [
    '🧑', '👩', '👨', '🧙', '🦸', '🤖', '🦊', '🐼',
  ];
  static const _kSuggestions = [
    'Explain quantum computing simply',
    'Write a Python function to sort a list',
    'What are benefits of meditation?',
    'Summarize the history of AI',
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _dotCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _sidebarCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 280),
    );
    _sidebarAnim = CurvedAnimation(
      parent: _sidebarCtrl,
      curve:  Curves.easeOutCubic,
    );

    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
    appTheme.addListener(_onThemeChange);
    _init();
  }

  void _onThemeChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _sidebarCtrl.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    appTheme.removeListener(_onThemeChange);
    super.dispose();
  }

  Future<void> _init() async {
    await _requestPermissions();
    await Future.wait([
      _loadProfile(),
      _loadSavedModel(),
    ]);
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

  // ── Chat history ──────────────────────────────────────────────────────────
  Future<void> _loadConversations() async {
    setState(() => _historyLoading = true);
    final convs = await ChatStorage.listConversations();
    if (mounted) setState(() { _conversations = convs; _historyLoading = false; });
  }

  Future<void> _startNewChat() async {
    setState(() { _messages.clear(); _currentConvId = null; });
    if (_sidebarOpen) _closeSidebar();
  }

  Future<void> _loadConversation(Conversation conv) async {
    setState(() { _messages.clear(); _currentConvId = conv.id; });
    if (_sidebarOpen) _closeSidebar();

    final stored = await ChatStorage.loadMessages(conv.id!);
    final msgs = stored.map((s) => ChatMessage(
      _roleFromString(s.role), s.text, time: s.time,
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

  // ── Send ──────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _thinking) return;

    if (_activeModelPath == null) {
      _showNoModelSnack();
      return;
    }

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

    await ChatStorage.insertMessage(StoredMessage(
      conversationId: _currentConvId!,
      role:           'user',
      text:           text,
      time:           userMsg.time,
    ));

    final contextMsgs = await ChatStorage.lastMessages(_currentConvId!, 8);
    final prompt      = _buildContextPrompt(contextMsgs, text);
    final String modelPath = _activeModelPath!;

    try {
      final raw   = await LLMService.runInference(modelPath, prompt);
      final reply = cleanLLMResponse(raw);

      if (!mounted) return;
      final role  = reply.startsWith('Error:') ? MessageRole.error : MessageRole.ai;
      final aiMsg = ChatMessage(role, reply);
      setState(() { _messages.add(aiMsg); _thinking = false; });
      _scrollToBottom();

      await ChatStorage.insertMessage(StoredMessage(
        conversationId: _currentConvId!,
        role:           role == MessageRole.error ? 'error' : 'ai',
        text:           reply,
        time:           aiMsg.time,
      ));

      // Update title after first AI reply
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

    } catch (e) {
      if (!mounted) return;
      final errMsg = ChatMessage(MessageRole.error, 'Error: $e');
      setState(() { _messages.add(errMsg); _thinking = false; });
      await ChatStorage.insertMessage(StoredMessage(
        conversationId: _currentConvId!,
        role:           'error',
        text:           'Error: $e',
        time:           errMsg.time,
      ));
      _scrollToBottom();
    }
  }

  String _buildContextPrompt(List<StoredMessage> history, String input) {
    if (history.isEmpty) return input;
    final buf = StringBuffer();
    for (final msg in history) {
      if (msg.role == 'user') buf.write('User: ${msg.text}\n');
      else if (msg.role == 'ai') buf.write('Assistant: ${msg.text}\n');
    }
    buf.write('User: $input\nAssistant:');
    return buf.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve:    Curves.easeOutCubic,
        );
      }
    });
  }

  void _showNoModelSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('No model loaded — tap Models to download one',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
        backgroundColor: RamaColors.warning,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(14),
        action: SnackBarAction(
          label:     'MODELS',
          textColor: Colors.white,
          onPressed: _openModelManager,
        ),
      ),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────────
  void _openSidebar() {
    setState(() => _sidebarOpen = true);
    _sidebarCtrl.forward();
  }

  void _closeSidebar() {
    _sidebarCtrl.reverse().then((_) {
      if (mounted) setState(() => _sidebarOpen = false);
    });
  }

  void _toggleSidebar() {
    _sidebarOpen ? _closeSidebar() : _openSidebar();
  }

  // ── Theme tokens ──────────────────────────────────────────────────────────
  Color get _bg      => appTheme.bg;
  Color get _surface => appTheme.surface;
  Color get _card    => appTheme.card;
  Color get _border  => appTheme.border;
  Color get _text    => appTheme.text;
  Color get _sub     => appTheme.sub;
  Color get _dim     => appTheme.dim;
  Color get _accent  => appTheme.accent;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5)  return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }

  String _modelLabel() {
    if (_activeModelPath == null) return 'No model loaded';
    final fn = _activeModelPath!.split('/').last;
    // strip .gguf, trim length
    final name = fn.replaceAll('.gguf', '');
    return name.length > 28 ? '${name.substring(0, 26)}…' : name;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Main column ──────────────────────────────────────────────────
            Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _focus.unfocus();
                      if (_sidebarOpen) _closeSidebar();
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

            // ── Sidebar overlay ──────────────────────────────────────────────
            if (_sidebarOpen) ...[
              FadeTransition(
                opacity: _sidebarAnim,
                child: GestureDetector(
                  onTap: _closeSidebar,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ),
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

  // ── App Bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    final modelLoaded = _activeModelPath != null;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:  _surface,
        border: Border(bottom: BorderSide(color: _border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Hamburger
          _NavBtn(
            icon:  Icons.menu_rounded,
            color: _sub,
            onTap: _toggleSidebar,
          ),
          const SizedBox(width: 8),

          // Logo + title
          LogoBadge(size: 32, accent: _accent),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment:  MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RAMA AI',
                  style: TextStyle(
                    color:      _text,
                    fontWeight: FontWeight.w800,
                    fontSize:   14,
                    letterSpacing: 0.8,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _modelLabel(),
                    key:      ValueKey(_activeModelPath),
                    overflow: TextOverflow.ellipsis,
                    style:    TextStyle(
                      color:    _sub,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Status dot
          Container(
            width: 7, height: 7,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: modelLoaded ? RamaColors.success : RamaColors.warning,
              boxShadow: [
                BoxShadow(
                  color: (modelLoaded ? RamaColors.success : RamaColors.warning)
                      .withValues(alpha: 0.55),
                  blurRadius: 5,
                ),
              ],
            ),
          ),

          // New chat
          _NavBtn(
            icon:  Icons.edit_note_rounded,
            color: _accent,
            onTap: _startNewChat,
          ),
          const SizedBox(width: 4),

          // Theme toggle
          _NavBtn(
            icon:  appTheme.isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            color: _sub,
            onTap: () async {
              appTheme.toggle();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('theme_dark', appTheme.isDark);
              SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                statusBarColor:
                    Colors.transparent,
                statusBarIconBrightness:
                    appTheme.isDark ? Brightness.light : Brightness.dark,
              ));
            },
          ),
          const SizedBox(width: 4),

          // Models
          _NavBtn(
            icon:  Icons.grid_view_rounded,
            color: _sub,
            onTap: _openModelManager,
          ),
        ],
      ),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    final w = (MediaQuery.of(context).size.width * 0.82).clamp(260.0, 320.0);
    return Container(
      width:  w,
      height: double.infinity,
      color:  _surface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _border, width: 0.5)),
            ),
            child: Row(
              children: [
                LogoBadge(size: 30, accent: _accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Conversations',
                    style: TextStyle(
                      color:      _text,
                      fontWeight: FontWeight.w700,
                      fontSize:   15,
                    ),
                  ),
                ),
                _NavBtn(
                  icon:  Icons.close_rounded,
                  color: _sub,
                  onTap: _closeSidebar,
                ),
              ],
            ),
          ),

          // New chat button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _GradientButton(
              label: '+ New Chat',
              accent: _accent,
              onTap:  _startNewChat,
            ),
          ),

          RamaDivider(color: _border),

          // Conversation list
          Expanded(
            child: _historyLoading
                ? Center(child: CircularProgressIndicator(
                    color: _accent, strokeWidth: 2))
                : _conversations.isEmpty
                    ? _buildSidebarEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        itemCount: _conversations.length,
                        itemBuilder: (_, i) =>
                            _conversationTile(_conversations[i]),
                      ),
          ),

          // User row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _border, width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color:        _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(color: _accent.withValues(alpha: 0.30)),
                  ),
                  child: Center(
                    child: Text(
                      _kAvatarEmojis[_userAvatar.clamp(0, 7)],
                      style: const TextStyle(fontSize: 16),
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
                      Text('${_conversations.length} chats',
                          style: TextStyle(color: _dim, fontSize: 10.5)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () { _closeSidebar(); _openProfile(); },
                  child: Icon(Icons.settings_rounded, color: _sub, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, color: _dim, size: 34),
          const SizedBox(height: 10),
          Text('No chats yet',
              style: TextStyle(color: _sub, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Start your first conversation!',
              style: TextStyle(color: _dim, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _conversationTile(Conversation conv) {
    final isActive  = conv.id == _currentConvId;
    final now       = DateTime.now();
    final upd       = conv.updatedAt;
    final dateLabel = now.difference(upd).inDays == 0
        ? '${upd.hour.toString().padLeft(2, '0')}:${upd.minute.toString().padLeft(2, '0')}'
        : '${upd.day}/${upd.month}';
    final title = conv.title.isEmpty ? 'New Chat' : conv.title;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color:        isActive ? _accent.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(color: _accent.withValues(alpha: 0.25))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _loadConversation(conv),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isActive
                      ? Icons.chat_bubble_rounded
                      : Icons.chat_bubble_outline_rounded,
                  color: isActive ? _accent : _dim,
                  size:  14,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color:      isActive ? _accent : _text,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          fontSize:   13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(dateLabel,
                          style: TextStyle(color: _dim, fontSize: 9.5)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _confirmDelete(conv),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.delete_outline_rounded,
                        color: _dim, size: 15),
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
    final ok = await showModalBottomSheet<bool>(
      context:           context,
      backgroundColor:   _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color:        _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(Icons.delete_forever_rounded,
                  color: RamaColors.error, size: 36),
              const SizedBox(height: 12),
              Text(
                'Delete this chat?',
                style: TextStyle(
                  color:      _text,
                  fontWeight: FontWeight.w700,
                  fontSize:   16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '"${conv.title.isEmpty ? 'New Chat' : conv.title}"\nThis cannot be undone.',
                textAlign: TextAlign.center,
                style:     TextStyle(color: _sub, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _OutlineBtn(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(ctx, false),
                      color: _sub,
                      border: _border,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FilledBtn(
                      label: 'Delete',
                      onTap: () => Navigator.pop(ctx, true),
                      color: RamaColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) await _deleteConversation(conv);
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          // Logo + glow
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accent.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              LogoBadge(size: 68, accent: _accent),
            ],
          ),
          const SizedBox(height: 20),

          // Greeting
          Text(
            '$_greeting, $_userName $_kAvatarEmojis[${_userAvatar.clamp(0, 7)}]',
            style: TextStyle(
              color:      _text,
              fontSize:   22,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _activeModelPath != null
                ? "I'm ready to help — what's on your mind?"
                : 'Load a model to start chatting',
            style: TextStyle(color: _sub, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          if (_activeModelPath == null) ...[
            ActionCard(
              icon:     Icons.download_for_offline_rounded,
              title:    'Download a Model',
              subtitle: 'Browse & download GGUF models to get started',
              color:    _accent,
              onTap:    _openModelManager,
            ),
            const SizedBox(height: 12),
            ActionCard(
              icon:     Icons.folder_open_rounded,
              title:    'Import from Device',
              subtitle: 'Load a .gguf file you already have',
              color:    const Color(0xFF06B6D4),
              onTap:    _openModelManager,
            ),
          ] else ...[
            // Active model chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:        _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(100),
                border:       Border.all(color: _accent.withValues(alpha: 0.22)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: RamaColors.success,
                      boxShadow: [
                        BoxShadow(
                          color:      RamaColors.success.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _modelLabel(),
                    style: TextStyle(
                      color:      _accent,
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Suggestion label
            Row(
              children: [
                Expanded(child: RamaDivider(color: _border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'TRY ASKING',
                    style: TextStyle(
                      color:         _dim,
                      fontSize:      10,
                      fontWeight:    FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(child: RamaDivider(color: _border)),
              ],
            ),
            const SizedBox(height: 14),

            ..._kSuggestions.map((s) => SuggestionChip(
              label:  s,
              card:   _card,
              border: _border,
              text:   _text,
              sub:    _sub,
              dim:    _dim,
              onTap:  () { _ctrl.text = s; _send(); },
            )),
          ],
        ],
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scroll,
      padding:    const EdgeInsets.fromLTRB(14, 18, 14, 12),
      itemCount:  _messages.length,
      itemBuilder: (ctx, i) {
        final msg    = _messages[i];
        final isLast = i == _messages.length - 1;
        return MessageBubble(
          key:             ValueKey('${msg.time.millisecondsSinceEpoch}_$i'),
          message:         msg,
          isLast:          isLast,
          isStreaming:     isLast && msg.role == MessageRole.ai && !_thinking,
          userName:        _userName,
          userAvatarEmoji: _kAvatarEmojis[_userAvatar.clamp(0, 7)],
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

  // ── Thinking bar ──────────────────────────────────────────────────────────
  Widget _buildThinkingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          LogoBadge(size: 26, accent: _accent),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: _dotCtrl,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final phase   = ((_dotCtrl.value * 3) - i) % 3;
                final opacity = phase < 1
                    ? phase
                    : (phase < 2 ? 1.0 : 3.0 - phase);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 5, height: 5,
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
          Text('Generating…',
              style: TextStyle(color: _sub, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Input area ────────────────────────────────────────────────────────────
  Widget _buildInputArea() {
    final hasText = _ctrl.text.trim().isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color:  _surface,
        border: Border(
          top: BorderSide(
            color: _focused ? _accent.withValues(alpha: 0.35) : _border,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 130),
              decoration: BoxDecoration(
                color:        _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _focused
                      ? _accent.withValues(alpha: 0.45)
                      : _border,
                  width: 1,
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
            enabled:  hasText && !_thinking,
            thinking: _thinking,
            accent:   _accent,
            card:     _card,
            border:   _border,
            onTap:    _send,
          ),
        ],
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void _openModelManager() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a1, a2) => ModelManagerScreen(
          activeModelPath: _activeModelPath,
          onModelSelected: _setActiveModel,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1), end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    ).then((_) => _refreshModels());
  }

  void _openProfile() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a1, a2) => const ProfileSetupScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1), end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    ).then((_) => _loadProfile());
  }
}

// ─── Local helper widgets ──────────────────────────────────────────────────────

class _NavBtn extends StatefulWidget {
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.color, required this.onTap});

  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = appTheme.card;
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:        _pressed ? c.withValues(alpha: 0.8) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(widget.icon, color: widget.color, size: 20),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String       label;
  final Color        accent;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, accent.withValues(alpha: 0.75)],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color:      accent.withValues(alpha: 0.28),
              blurRadius: 12,
              offset:     const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color:      Colors.white,
            fontWeight: FontWeight.w700,
            fontSize:   14,
          ),
        ),
      ),
    );
  }
}

class _FilledBtn extends StatelessWidget {
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _FilledBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color:        color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.w700,
                fontSize:   14,
              )),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String       label;
  final Color        color;
  final Color        border;
  final VoidCallback onTap;
  const _OutlineBtn({
    required this.label,
    required this.color,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: border),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                color:      color,
                fontWeight: FontWeight.w700,
                fontSize:   14,
              )),
        ),
      ),
    );
  }
}
