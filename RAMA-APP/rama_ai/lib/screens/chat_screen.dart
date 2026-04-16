import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import '../core/chat_controller.dart';
import '../services/llm_service.dart';
import '../widgets/shared_widgets.dart';
import 'model_manager_screen.dart';
import 'settings_screen.dart';

// ─── Phase 2: Main Workspace — Claude-like Layout ─────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _inputCtrl = TextEditingController();
  final _scroll    = ScrollController();
  final _focus     = FocusNode();

  // ── Local UI state ─────────────────────────────────────────────────────────
  bool   _focused      = false;
  bool   _hasText      = false;
  String _userName     = '';
  int    _userAvatar   = 0;

  static const _kAvatarEmojis = [
    '🧑', '👩', '👨', '🧙', '🦸', '🤖', '🦊', '🐼',
  ];
  static const _kSuggestions = [
    'Explain quantum computing simply',
    'Write a Python function to sort a list',
    'What are benefits of meditation?',
    'Summarize the history of AI',
  ];

  // ── Sidebar (Collapsible — left, 260px) ───────────────────────────────────
  bool _sidebarOpen = false;
  late final AnimationController _sidebarCtrl;
  late final Animation<double>   _sidebarAnim;

  // ── Thinking dots animation ────────────────────────────────────────────────
  late AnimationController _dotCtrl;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
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
    _inputCtrl.addListener(() => setState(() => _hasText = _inputCtrl.text.trim().isNotEmpty));
    appTheme.addListener(_onThemeChange);
    _init();
  }

  void _onThemeChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _sidebarCtrl.dispose();
    _inputCtrl.dispose();
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
      LLMService.ensureIsolate().catchError((_) {}),
    ]);
    await _refreshModels();
    if (mounted) {
      await context.read<ChatController>().loadConversations();
    }
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
      if (mounted) {
        context.read<ChatController>().setActiveModelPath(saved);
      }
    }
  }

  Future<void> _refreshModels() async {
    final models = await LLMService.listModels();
    if (!mounted) return;
    final ctrl = context.read<ChatController>();
    if (ctrl.activeModelPath == null && models.isNotEmpty) {
      await _setActiveModel(models.first.path);
    }
  }

  Future<void> _setActiveModel(String path) async {
    await LLMService.releaseModelCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_model_path', path);
    if (mounted) {
      context.read<ChatController>().setActiveModelPath(path);
    }
  }

  // ── Send message ───────────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    final ctrl = context.read<ChatController>();
    if (ctrl.isThinking) return;
    if (ctrl.activeModelPath == null) {
      _showNoModelSnack();
      return;
    }

    _inputCtrl.clear();
    _scrollToBottom();

    // Delegate to controller — it handles LLM, storage, sliding-window context
    await ctrl.sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 320),
          curve:    Curves.easeOutCubic,
        );
      }
    });
  }

  void _showNoModelSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('No model loaded — tap Models to download one',
                style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 13)),
          ],
        ),
        backgroundColor: RamaColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(14),
        action: SnackBarAction(
          label:     'MODELS',
          textColor: Colors.white,
          onPressed: _openModelManager,
        ),
      ),
    );
  }

  // ── Sidebar control ────────────────────────────────────────────────────────
  void _openSidebar()  { setState(() => _sidebarOpen = true); _sidebarCtrl.forward(); }
  void _closeSidebar() { _sidebarCtrl.reverse().then((_) { if (mounted) setState(() => _sidebarOpen = false); }); }
  void _toggleSidebar() { _sidebarOpen ? _closeSidebar() : _openSidebar(); }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _openModelManager() {
    final ctrl = context.read<ChatController>();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a1, a2) => ModelManagerScreen(
          activeModelPath: ctrl.activeModelPath,
          onModelSelected: _setActiveModel,
        ),
        transitionsBuilder: (context, anim, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1), end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    ).then((_) => _refreshModels());
  }

  void _openSettings() {
    if (_sidebarOpen) _closeSidebar();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a1, a2) => const SettingsScreen(),
        transitionsBuilder: (context, anim, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1), end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    ).then((_) {
      _loadProfile();
      if (mounted) setState(() {});
    });
  }

  // ── Convenience theme tokens ───────────────────────────────────────────────
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

  String _modelLabel(String? path) {
    if (path == null) return 'No model loaded';
    final fn   = path.split('/').last;
    final name = fn.replaceAll('.gguf', '');
    return name.length > 28 ? '${name.substring(0, 26)}…' : name;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, ctrl, _) {
        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Stack(
              children: [
                // ── Main column ─────────────────────────────────────────────
                Column(
                  children: [
                    _buildAppBar(ctrl),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _focus.unfocus();
                          if (_sidebarOpen) _closeSidebar();
                        },
                        child: ctrl.messages.isEmpty && !ctrl.isThinking
                            ? _buildEmptyState(ctrl)
                            : _buildMessageList(ctrl),
                      ),
                    ),
                    if (ctrl.isThinking) _buildThinkingBar(),
                    _buildInputArea(ctrl),
                  ],
                ),

                // ── Sidebar overlay ─────────────────────────────────────────
                if (_sidebarOpen) ...[
                  FadeTransition(
                    opacity: _sidebarAnim,
                    child: GestureDetector(
                      onTap: _closeSidebar,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.50),
                      ),
                    ),
                  ),
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(-1, 0),
                      end:   Offset.zero,
                    ).animate(_sidebarAnim),
                    child: _buildSidebar(ctrl),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar(ChatController ctrl) {
    final modelLoaded = ctrl.activeModelPath != null;
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:  _surface,
        border: Border(bottom: BorderSide(color: _border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Hamburger menu
          _AppBarBtn(
            icon:    Icons.menu_rounded,
            color:   _sub,
            onTap:   _toggleSidebar,
            surface: _surface,
            border:  _border,
          ),
          const SizedBox(width: 10),

          // Logo + title
          LogoBadge(size: 30, accent: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment:  MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RAMA AI',
                    style: GoogleFonts.inter(
                      color:         _text,
                      fontWeight:    FontWeight.w800,
                      fontSize:      14,
                      letterSpacing: 0.6,
                    )),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _modelLabel(ctrl.activeModelPath),
                    key:      ValueKey(ctrl.activeModelPath),
                    overflow: TextOverflow.ellipsis,
                    style:    GoogleFonts.inter(
                      color:    _sub,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Model status dot
          Container(
            width: 7, height: 7,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: modelLoaded ? RamaColors.success : RamaColors.warning,
              boxShadow: [
                BoxShadow(
                  color:      (modelLoaded
                      ? RamaColors.success
                      : RamaColors.warning)
                      .withValues(alpha: 0.55),
                  blurRadius: 6,
                ),
              ],
            ),
          ),

          // New chat button
          _AppBarBtn(
            icon:    Icons.edit_note_rounded,
            color:   _accent,
            onTap:   () => context.read<ChatController>().startNewChat(),
            surface: _surface,
            border:  _border,
          ),
          const SizedBox(width: 4),

          // Models button
          _AppBarBtn(
            icon:    Icons.grid_view_rounded,
            color:   _sub,
            onTap:   _openModelManager,
            surface: _surface,
            border:  _border,
          ),
        ],
      ),
    );
  }

  // ── Sidebar — 260px collapsible left panel ────────────────────────────────
  Widget _buildSidebar(ChatController ctrl) {
    final w = (MediaQuery.of(context).size.width * 0.82).clamp(240.0, 280.0);
    return Container(
      width:  w,
      height: double.infinity,
      // Phase 2 exact spec: slightly darker than canvas with 1px right border
      decoration: BoxDecoration(
        color: appTheme.isDark
            ? const Color(0xFF1A1A1A)
            : RamaColors.lightSurface,
        border: const Border(
          right: BorderSide(color: Colors.white10),
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.30),
            blurRadius: 24,
            offset:     const Offset(8, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sidebar header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _border, width: 0.5)),
            ),
            child: Row(
              children: [
                LogoBadge(size: 28, accent: _accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Conversations',
                      style: GoogleFonts.inter(
                        color:      _text,
                        fontWeight: FontWeight.w700,
                        fontSize:   14.5,
                      )),
                ),
                _AppBarBtn(
                  icon:    Icons.close_rounded,
                  color:   _sub,
                  onTap:   _closeSidebar,
                  surface: Colors.transparent,
                  border:  Colors.transparent,
                ),
              ],
            ),
          ),

          // New Chat button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _SidebarNewChatBtn(
              accent: _accent,
              onTap:  () {
                ctrl.startNewChat();
                _closeSidebar();
              },
            ),
          ),
          RamaDivider(color: _border),

          // Chat history list — grouped by date
          Expanded(
            child: ctrl.historyLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color:       _accent,
                      strokeWidth: 2,
                    ),
                  )
                : ctrl.conversations.isEmpty
                    ? _buildSidebarEmpty()
                    : _buildGroupedHistory(ctrl),
          ),

          // Bottom: user profile + settings gear
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
                    border:       Border.all(
                        color: _accent.withValues(alpha: 0.28)),
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
                          style: GoogleFonts.inter(
                            color:      _text,
                            fontWeight: FontWeight.w600,
                            fontSize:   13,
                          )),
                      Text('${ctrl.conversations.length} chats',
                          style: GoogleFonts.inter(
                              color: _dim, fontSize: 10.5)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _openSettings,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.settings_rounded, color: _sub, size: 18),
                  ),
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
          Icon(Icons.chat_bubble_outline_rounded, color: _dim, size: 32),
          const SizedBox(height: 10),
          Text('No chats yet',
              style: GoogleFonts.inter(color: _sub, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Start your first conversation!',
              style: GoogleFonts.inter(color: _dim, fontSize: 11)),
        ],
      ),
    );
  }

  // Grouped history: Today / Previous 7 Days / Older
  Widget _buildGroupedHistory(ChatController ctrl) {
    final grouped = ctrl.groupedConversations();
    return ThinScrollbar(
      controller: ScrollController(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(entry.key,
                  style: GoogleFonts.inter(
                    color:         _dim,
                    fontSize:      10,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 0.8,
                  )),
            ),
            for (final conv in entry.value)
              _ConversationTile(
                conv:       conv,
                isActive:   conv.id == ctrl.currentConvId,
                accent:     _accent,
                text:        _text,
                dim:        _dim,
                border:     _border,
                onTap:      () {
                  ctrl.loadConversation(conv);
                  _closeSidebar();
                  _scrollToBottom();
                },
                onDelete:   () => _confirmDelete(ctrl, conv),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(ChatController ctrl, dynamic conv) async {
    final ok = await showModalBottomSheet<bool>(
      context:         context,
      backgroundColor: _card,
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
              const Icon(Icons.delete_forever_rounded,
                  color: RamaColors.error, size: 36),
              const SizedBox(height: 12),
              Text('Delete this chat?',
                  style: GoogleFonts.inter(
                    color:      _text,
                    fontWeight: FontWeight.w700,
                    fontSize:   16,
                  )),
              const SizedBox(height: 6),
              Text(
                '"${conv.title.isEmpty ? 'New Chat' : conv.title}"\nThis cannot be undone.',
                textAlign: TextAlign.center,
                style:     GoogleFonts.inter(
                    color: _sub, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _OutlineBtn(
                    label:  'Cancel',
                    onTap:  () => Navigator.pop(ctx, false),
                    color:  _sub,
                    border: _border,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _FilledBtn(
                    label: 'Delete',
                    onTap: () => Navigator.pop(ctx, true),
                    color: RamaColors.error,
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) await ctrl.deleteConversation(conv);
  }

  // ── Empty state / welcome screen ───────────────────────────────────────────
  Widget _buildEmptyState(ChatController ctrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          // Animated logo glow
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _accent.withValues(alpha: 0.14),
                    Colors.transparent,
                  ]),
                ),
              ),
              LogoBadge(size: 70, accent: _accent),
            ],
          ),
          const SizedBox(height: 24),

          // Greeting
          Text(
            '$_greeting, $_userName ${_kAvatarEmojis[_userAvatar.clamp(0, 7)]}',
            style: GoogleFonts.inter(
              color:      _text,
              fontSize:   22,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            ctrl.activeModelPath != null
                ? "I'm ready to help — what's on your mind?"
                : 'Load a model to start chatting',
            style:     GoogleFonts.inter(color: _sub, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          if (ctrl.activeModelPath == null) ...[
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
            // Model status pill
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:        _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(100),
                border:       Border.all(
                    color: _accent.withValues(alpha: 0.22)),
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
                          color:      RamaColors.success
                              .withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_modelLabel(ctrl.activeModelPath),
                      style: GoogleFonts.inter(
                        color:      _accent,
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Try asking section
            Row(
              children: [
                Expanded(child: RamaDivider(color: _border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('TRY ASKING',
                      style: GoogleFonts.inter(
                        color:         _dim,
                        fontSize:      10,
                        fontWeight:    FontWeight.w700,
                        letterSpacing: 1.2,
                      )),
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
              onTap:  () { _inputCtrl.text = s; _send(); },
            )),
          ],
        ],
      ),
    );
  }

  // ── Message list with staggered entrance ───────────────────────────────────
  Widget _buildMessageList(ChatController ctrl) {
    return ThinScrollbar(
      controller: _scroll,
      child: ListView.builder(
        controller: _scroll,
        padding:    const EdgeInsets.fromLTRB(14, 18, 14, 12),
        itemCount:  ctrl.messages.length,
        itemBuilder: (ctx, i) {
          final msg    = ctrl.messages[i];
          final isLast = i == ctrl.messages.length - 1;
          return MessageBubble(
            key:             ValueKey('${msg.time.millisecondsSinceEpoch}_$i'),
            message:         msg,
            isLast:          isLast,
            isStreaming:     isLast && msg.role.name == 'ai' && !ctrl.isThinking,
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
      ),
    );
  }

  // ── Thinking / generating bar ──────────────────────────────────────────────
  Widget _buildThinkingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          LogoBadge(size: 24, accent: _accent),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: _dotCtrl,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final phase   = ((_dotCtrl.value * 3) - i) % 3;
                final opacity = phase < 1
                    ? phase
                    : (phase < 2 ? 1.0 : 3.0 - phase);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent.withValues(
                        alpha: 0.20 + opacity.clamp(0.0, 1.0) * 0.75),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 10),
          Text('Generating…',
              style: GoogleFonts.inter(color: _sub, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Input area — rounded rect with drop shadow ────────────────────────────
  Widget _buildInputArea(ChatController ctrl) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color:  _surface,
        border: Border(
          top: BorderSide(
            color: _focused
                ? _accent.withValues(alpha: 0.30)
                : _border,
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 130),
              decoration: BoxDecoration(
                color:        _card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _focused
                      ? _accent.withValues(alpha: 0.40)
                      : _border,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:      Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset:     const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attachment icon (placeholder — no backend hooked)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 11),
                    child: Icon(
                      Icons.attach_file_rounded,
                      color: _dim,
                      size:  18,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller:      _inputCtrl,
                      focusNode:       _focus,
                      style:           GoogleFonts.inter(
                          color: _text, fontSize: 14.5, height: 1.45),
                      maxLines:        null,
                      keyboardType:    TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText:       'Message RAMA AI…',
                        hintStyle:      GoogleFonts.inter(
                            color: _dim, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          SendButton(
            enabled:  _hasText && !ctrl.isThinking,
            thinking: ctrl.isThinking,
            accent:   _accent,
            card:     _card,
            border:   _border,
            onTap:    _send,
          ),
        ],
      ),
    );
  }
}

// ─── AppBar icon button ───────────────────────────────────────────────────────
class _AppBarBtn extends StatefulWidget {
  final IconData     icon;
  final Color        color;
  final Color        surface;
  final Color        border;
  final VoidCallback onTap;
  const _AppBarBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.surface,
    required this.border,
  });

  @override
  State<_AppBarBtn> createState() => _AppBarBtnState();
}

class _AppBarBtnState extends State<_AppBarBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:        _pressed
              ? widget.color.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(widget.icon, color: widget.color, size: 20),
      ),
    );
  }
}

// ─── Sidebar New Chat button ──────────────────────────────────────────────────
class _SidebarNewChatBtn extends StatefulWidget {
  final Color        accent;
  final VoidCallback onTap;
  const _SidebarNewChatBtn({required this.accent, required this.onTap});

  @override
  State<_SidebarNewChatBtn> createState() => _SidebarNewChatBtnState();
}

class _SidebarNewChatBtnState extends State<_SidebarNewChatBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width:    double.infinity,
        padding:  const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              widget.accent,
              widget.accent.withValues(alpha: _pressed ? 0.60 : 0.78),
            ],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color:      widget.accent
                  .withValues(alpha: _pressed ? 0.12 : 0.25),
              blurRadius: _pressed ? 8 : 16,
              offset:     Offset(0, _pressed ? 2 : 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text('New Chat',
                style: GoogleFonts.inter(
                  color:      Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize:   14,
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Conversation tile with slide-out delete ──────────────────────────────────
class _ConversationTile extends StatefulWidget {
  final dynamic      conv;
  final bool         isActive;
  final Color        accent, text, dim, border;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _ConversationTile({
    required this.conv,
    required this.isActive,
    required this.accent,
    required this.text,
    required this.dim,
    required this.border,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  String get _title =>
      widget.conv.title.isEmpty ? 'New Chat' : widget.conv.title;

  String get _dateLabel {
    final now  = DateTime.now();
    final upd  = widget.conv.updatedAt as DateTime;
    if (now.difference(upd).inDays == 0) {
      return '${upd.hour.toString().padLeft(2, '0')}:'
             '${upd.minute.toString().padLeft(2, '0')}';
    }
    return '${upd.day}/${upd.month}';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.accent.withValues(alpha: 0.08)
              : isActive
                  ? widget.accent.withValues(alpha: 0.10)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border.all(color: widget.accent.withValues(alpha: 0.22))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isActive
                  ? Icons.chat_bubble_rounded
                  : Icons.chat_bubble_outline_rounded,
              color: isActive ? widget.accent : widget.dim,
              size:  13,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: GoogleFonts.inter(
                      color:      isActive ? widget.accent : widget.text,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
                      fontSize:   13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(_dateLabel,
                      style: GoogleFonts.inter(
                          color: widget.dim, fontSize: 9.5)),
                ],
              ),
            ),
            GestureDetector(
              onTap: widget.onDelete,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.delete_outline_rounded,
                    color: widget.dim, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filled button ────────────────────────────────────────────────────────────
class _FilledBtn extends StatelessWidget {
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _FilledBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

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
              style: GoogleFonts.inter(
                color:      Colors.white,
                fontWeight: FontWeight.w700,
                fontSize:   14,
              )),
        ),
      ),
    );
  }
}

// ─── Outline button ───────────────────────────────────────────────────────────
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
              style: GoogleFonts.inter(
                color:      color,
                fontWeight: FontWeight.w700,
                fontSize:   14,
              )),
        ),
      ),
    );
  }
}