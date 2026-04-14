import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/app_theme.dart';
import '../services/llm_service.dart';
import '../widgets/shared_widgets.dart';

// ─── Model catalogue entry ─────────────────────────────────────────────────────
class ModelInfo {
  final String name;
  final String description;
  final String size;
  final String downloadUrl;
  final String filename;
  final Color  accentColor;
  final String params;
  final String badge;
  final String family;       // NEW: model family tag

  const ModelInfo({
    required this.name,
    required this.description,
    required this.size,
    required this.downloadUrl,
    required this.filename,
    required this.accentColor,
    required this.params,
    this.badge  = '',
    this.family = '',
  });
}

// ─── Catalogue ────────────────────────────────────────────────────────────────
const List<ModelInfo> kAvailableModels = [
  ModelInfo(
    name:        'TinyLlama 1.1B Chat',
    description: 'Ultra-fast, very low RAM usage. Perfect for entry-level devices.',
    size:        '0.67 GB',
    params:      '1.1B',
    family:      'LLaMA',
    badge:       'Fastest',
    downloadUrl: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF'
                 '/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    filename:    'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    accentColor: Color(0xFF10B981),
  ),
  ModelInfo(
    name:        'Phi-2 (2.7B)',
    description: 'Microsoft Phi-2 — great reasoning & code in a tiny package.',
    size:        '1.79 GB',
    params:      '2.7B',
    family:      'Phi',
    badge:       'Balanced',
    downloadUrl: 'https://huggingface.co/TheBloke/phi-2-GGUF'
                 '/resolve/main/phi-2.Q4_K_M.gguf',
    filename:    'phi-2.Q4_K_M.gguf',
    accentColor: Color(0xFF3B82F6),
  ),
  ModelInfo(
    name:        'Gemma 2B Instruct',
    description: "Google's efficient 2B chat model with quality responses.",
    size:        '1.35 GB',
    params:      '2B',
    family:      'Gemma',
    badge:       'Google',
    downloadUrl: 'https://huggingface.co/google/gemma-2b-it-GGUF'
                 '/resolve/main/2b_it_v1p1.gguf',
    filename:    'gemma-2b-it-q4.gguf',
    accentColor: Color(0xFF06B6D4),
  ),
  ModelInfo(
    name:        'Phi-3 Mini 4K Instruct',
    description: "Microsoft's 3.8B chat & coding powerhouse with 4K context.",
    size:        '2.39 GB',
    params:      '3.8B',
    family:      'Phi',
    badge:       'Popular',
    downloadUrl: 'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf'
                 '/resolve/main/Phi-3-mini-4k-instruct-q4.gguf',
    filename:    'Phi-3-mini-4k-instruct-q4.gguf',
    accentColor: Color(0xFF7C6EF5),
  ),
  ModelInfo(
    name:        'Llama 3.2 1B Instruct',
    description: 'Meta\'s latest compact 1B model — fast and capable.',
    size:        '1.32 GB',
    params:      '1B',
    family:      'LLaMA',
    badge:       'Latest',
    downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF'
                 '/resolve/main/Llama-3.2-1B-Instruct-Q8_0.gguf',
    filename:    'Llama-3.2-1B-Instruct-Q8_0.gguf',
    accentColor: Color(0xFFF59E0B),
  ),
];

// ─── Download state per model ─────────────────────────────────────────────────
class _DownloadState {
  bool   active   = false;
  double progress = 0.0;
  String status   = '';
  CancelToken? token;
}

// ─── Model Manager Screen ─────────────────────────────────────────────────────
class ModelManagerScreen extends StatefulWidget {
  final String?              activeModelPath;
  final ValueChanged<String> onModelSelected;

  const ModelManagerScreen({
    super.key,
    required this.activeModelPath,
    required this.onModelSelected,
  });

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen>
    with SingleTickerProviderStateMixin {
  List<File> _localModels  = [];
  bool       _loading      = true;
  bool       _importing    = false;
  String     _storagePath  = '';

  final Map<String, _DownloadState> _downloads = {};

  late TabController _tabCtrl;

  // ── Theme helpers ─────────────────────────────────────────────────────────
  Color get _bg      => appTheme.bg;
  Color get _surface => appTheme.surface;
  Color get _card    => appTheme.card;
  Color get _border  => appTheme.border;
  Color get _text    => appTheme.text;
  Color get _sub     => appTheme.sub;
  Color get _dim     => appTheme.dim;
  Color get _accent  => appTheme.accent;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    appTheme.addListener(_onTheme);
    for (final m in kAvailableModels) {
      _downloads[m.filename] = _DownloadState();
    }
    _loadAll();
  }

  void _onTheme() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    for (final ds in _downloads.values) {
      ds.token?.cancel('Screen disposed');
    }
    _tabCtrl.dispose();
    appTheme.removeListener(_onTheme);
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final dir   = await LLMService.modelsDir;
    final files = await LLMService.listModels();
    if (mounted) {
      setState(() {
        _localModels  = files;
        _storagePath  = dir.path;
        _loading      = false;
      });
    }
  }

  File? _matchLocal(ModelInfo info) {
    try {
      return _localModels.firstWhere(
          (f) => f.path.split('/').last.toLowerCase() ==
              info.filename.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  // ── Download ──────────────────────────────────────────────────────────────
  Future<void> _downloadModel(ModelInfo info) async {
    final ds = _downloads[info.filename]!;
    if (ds.active) return;

    final destPath = await LLMService.modelSavePath(info.filename);
    final destFile = File(destPath);

    if (destFile.existsSync()) {
      _snack('Already downloaded!', _accent);
      return;
    }

    final token = CancelToken();
    setState(() {
      ds.active   = true;
      ds.progress = 0;
      ds.status   = 'Connecting…';
      ds.token    = token;
    });

    try {
      final dio = Dio();
      await dio.download(
        info.downloadUrl, destPath,
        cancelToken: token,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          final mb  = received / (1024 * 1024);
          final tMb = total > 0 ? total / (1024 * 1024) : 0.0;
          setState(() {
            ds.progress = total > 0 ? received / total : 0;
            ds.status   = total > 0
                ? '${mb.toStringAsFixed(0)} / ${tMb.toStringAsFixed(0)} MB'
                : '${mb.toStringAsFixed(0)} MB';
          });
        },
      );

      await _loadAll();
      if (mounted) {
        _snack('✓ ${info.name} downloaded!', RamaColors.success);
        if (widget.activeModelPath == null) {
          widget.onModelSelected(destPath);
          Navigator.pop(context);
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        if (destFile.existsSync()) destFile.deleteSync();
        if (mounted) _snack('Download cancelled', RamaColors.warning);
      } else {
        if (mounted) _snack('Download failed: ${e.message}', RamaColors.error);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', RamaColors.error);
    } finally {
      if (mounted) {
        setState(() {
          ds.active   = false;
          ds.progress = 0;
          ds.status   = '';
          ds.token    = null;
        });
      }
    }
  }

  void _cancelDownload(ModelInfo info) {
    _downloads[info.filename]?.token?.cancel('User cancelled');
  }

  // ── Browse & Import ───────────────────────────────────────────────────────
  Future<void> _browseAndImport() async {
    if (Platform.isAndroid) await Permission.storage.request();
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type:          FileType.any,
        allowMultiple: false,
        dialogTitle:   'Select a .gguf model file',
        withData:      false,
        withReadStream: false,
      );
      if (result == null || result.files.isEmpty) return;

      final pickedPath = result.files.single.path;
      if (pickedPath == null || !pickedPath.toLowerCase().endsWith('.gguf')) {
        _snack('Please select a valid .gguf file', RamaColors.warning);
        return;
      }

      final srcFile  = File(pickedPath);
      final filename = pickedPath.split('/').last;
      final destPath = await LLMService.modelSavePath(filename);
      final destFile = File(destPath);

      if (!destFile.existsSync()) {
        _showCopyingDialog(filename);
        await srcFile.copy(destPath);
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }

      await _loadAll();
      if (mounted) {
        _snack('✓ "$filename" imported!', RamaColors.success);
        if (widget.activeModelPath == null) {
          widget.onModelSelected(destPath);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) _snack('Import error: $e', RamaColors.error);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showCopyingDialog(String filename) {
    showDialog<void>(
      context:            context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
              const SizedBox(height: 20),
              Text('Copying…',
                  style: TextStyle(
                      color: _text, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 6),
              Text(filename,
                  style: TextStyle(color: _sub, fontSize: 12),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteModel(File file) async {
    final name    = file.path.split('/').last;
    final confirm = await showModalBottomSheet<bool>(
      context:         context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  color:        appTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(Icons.delete_forever_rounded,
                  color: RamaColors.error, size: 36),
              const SizedBox(height: 12),
              Text('Delete model?',
                  style: TextStyle(
                      color: _text, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text(name,
                  style: TextStyle(color: _sub, fontSize: 12),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('This permanently removes the file.',
                  style: TextStyle(color: _dim, fontSize: 12)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _MMOutlineBtn(
                      label: 'Cancel',
                      color: _sub,
                      border: _border,
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MMFilledBtn(
                      label: 'Delete',
                      color: RamaColors.error,
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm == true) {
      file.deleteSync();
      await _loadAll();
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(msg,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: color,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin:          const EdgeInsets.all(14),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(
                      color: _accent, strokeWidth: 2))
                  : TabBarView(
                      controller: _tabCtrl,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildDownloadTab(),
                        _buildLocalTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color:  _surface,
        border: Border(bottom: BorderSide(color: _border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Back
          _MMIconBtn(
            icon:  Icons.arrow_back_ios_new_rounded,
            color: _sub,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Model Manager',
                    style: TextStyle(
                        color:      _text,
                        fontWeight: FontWeight.w800,
                        fontSize:   17)),
                Text('Download & manage on-device models',
                    style: TextStyle(color: _sub, fontSize: 11)),
              ],
            ),
          ),

          // Refresh
          _MMIconBtn(
            icon:  Icons.refresh_rounded,
            color: _accent,
            onTap: _loadAll,
          ),
          const SizedBox(width: 6),

          // Import
          GestureDetector(
            onTap: _importing ? null : _browseAndImport,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_accent, _accent.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _importing
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Colors.white))
                      : const Icon(
                          Icons.folder_open_rounded,
                          color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _importing ? 'Importing…' : 'Import',
                    style: const TextStyle(
                      color:      Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize:   13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color:        _card,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: _border, width: 0.5),
        ),
        child: TabBar(
          controller: _tabCtrl,
          labelColor:        _accent,
          unselectedLabelColor: _sub,
          labelStyle:   const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          indicator: BoxDecoration(
            color:        _accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border:       Border.all(color: _accent.withValues(alpha: 0.25)),
          ),
          indicatorPadding: const EdgeInsets.all(3),
          dividerColor: Colors.transparent,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.download_rounded, size: 15),
                  const SizedBox(width: 6),
                  const Text('Download'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_rounded, size: 15),
                  const SizedBox(width: 6),
                  Text('My Models (${_localModels.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Download Tab ──────────────────────────────────────────────────────────
  Widget _buildDownloadTab() {
    return RefreshIndicator(
      color:           _accent,
      backgroundColor: _card,
      onRefresh:       _loadAll,
      child: ListView.builder(
        padding:   const EdgeInsets.fromLTRB(16, 8, 16, 40),
        itemCount: kAvailableModels.length,
        itemBuilder: (_, i) => _catalogueCard(kAvailableModels[i]),
      ),
    );
  }

  // ── My Models Tab ─────────────────────────────────────────────────────────
  Widget _buildLocalTab() {
    if (_localModels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, color: _dim, size: 44),
            const SizedBox(height: 12),
            Text('No models yet',
                style: TextStyle(
                    color: _text, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Text('Download or import a model\nto start chatting',
                textAlign: TextAlign.center,
                style: TextStyle(color: _sub, fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _tabCtrl.animateTo(0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accent, _accent.withValues(alpha: 0.75)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Browse Models',
                    style: TextStyle(
                      color:      Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize:   14,
                    )),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Storage path banner
        Container(
          margin:  const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:        _card,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: _border, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(Icons.folder_rounded, color: _accent, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _storagePath.isEmpty ? '…' : _storagePath,
                  style: TextStyle(
                    color:      _sub,
                    fontSize:   10.5,
                    fontFamily: 'monospace',
                  ),
                  maxLines:  1,
                  overflow:  TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color:           _accent,
            backgroundColor: _card,
            onRefresh:       _loadAll,
            child: ListView.builder(
              padding:   const EdgeInsets.fromLTRB(16, 10, 16, 40),
              itemCount: _localModels.length,
              itemBuilder: (_, i) => _localModelCard(_localModels[i]),
            ),
          ),
        ),
      ],
    );
  }

  // ── Local model card ──────────────────────────────────────────────────────
  Widget _localModelCard(File f) {
    final name     = f.path.split('/').last;
    final sizeBytes = f.lengthSync();
    final sizeMB   = sizeBytes / (1024 * 1024);
    final sizeStr  = sizeMB >= 1024
        ? '${(sizeMB / 1024).toStringAsFixed(2)} GB'
        : '${sizeMB.toStringAsFixed(0)} MB';
    final isActive = widget.activeModelPath == f.path;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? _accent.withValues(alpha: 0.50) : _border,
          width: isActive ? 1.5 : 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isActive
              ? null
              : () {
                  widget.onModelSelected(f.path);
                  Navigator.pop(context);
                },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color:        isActive
                        ? _accent.withValues(alpha: 0.15)
                        : _surface,
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(
                        color: isActive
                            ? _accent.withValues(alpha: 0.35)
                            : _border),
                  ),
                  child: Icon(
                    isActive
                        ? Icons.check_circle_rounded
                        : Icons.memory_rounded,
                    color: isActive ? _accent : _sub,
                    size:  20,
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Strip .gguf for display
                      Text(
                        name.replaceAll('.gguf', ''),
                        style: TextStyle(
                          color:      _text,
                          fontWeight: FontWeight.w600,
                          fontSize:   13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.sd_storage_rounded,
                              color: _dim, size: 11),
                          const SizedBox(width: 4),
                          Text(sizeStr,
                              style: TextStyle(color: _sub, fontSize: 11)),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            PillChip(
                              label: 'ACTIVE',
                              color: RamaColors.success,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                if (!isActive)
                  _MMPillBtn(
                    label: 'Use',
                    color: _accent,
                    onTap: () {
                      widget.onModelSelected(f.path);
                      Navigator.pop(context);
                    },
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _deleteModel(f),
                  child: Icon(Icons.delete_outline_rounded,
                      color: _dim, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Catalogue card ────────────────────────────────────────────────────────
  Widget _catalogueCard(ModelInfo m) {
    final local    = _matchLocal(m);
    final isActive = local != null && widget.activeModelPath == local.path;
    final ds       = _downloads[m.filename]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:        _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? m.accentColor.withValues(alpha: 0.45)
              : _border,
          width: isActive ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(
                alpha: appTheme.isDark ? 0.18 : 0.05),
            blurRadius: 10,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Model icon
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color:        m.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: m.accentColor.withValues(alpha: 0.30)),
                  ),
                  child: Icon(Icons.memory_rounded,
                      color: m.accentColor, size: 22),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(m.name,
                                style: TextStyle(
                                  color:      _text,
                                  fontWeight: FontWeight.w700,
                                  fontSize:   14,
                                )),
                          ),
                          if (m.badge.isNotEmpty)
                            PillChip(
                              label:     m.badge,
                              color:     m.accentColor,
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.layers_rounded,
                              color: _dim, size: 11),
                          const SizedBox(width: 4),
                          Text('${m.params}  ·  ${m.size}  ·  ${m.family}',
                              style: TextStyle(color: _sub, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Description
            Text(m.description,
                style: TextStyle(color: _sub, fontSize: 12.5, height: 1.5)),

            const SizedBox(height: 12),

            // Download progress
            if (ds.active) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ds.status,
                      style: TextStyle(color: _sub, fontSize: 11)),
                  Text(
                    '${(ds.progress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color:      m.accentColor,
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value:           ds.progress,
                  minHeight:       5,
                  backgroundColor: _border,
                  valueColor:      AlwaysStoppedAnimation(m.accentColor),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Action row
            Row(
              children: [
                Expanded(
                  child: local != null
                      ? (isActive
                          ? _StatusBadge(
                              label: '✓  Active',
                              color: RamaColors.success,
                            )
                          : _MMOutlineBtn(
                              label: 'Use This Model',
                              color: m.accentColor,
                              border: m.accentColor.withValues(alpha: 0.35),
                              onTap: () {
                                widget.onModelSelected(local.path);
                                Navigator.pop(context);
                              },
                            ))
                      : (ds.active
                          ? _MMOutlineBtn(
                              label: 'Cancel',
                              color: RamaColors.error,
                              border:
                                  RamaColors.error.withValues(alpha: 0.35),
                              onTap: () => _cancelDownload(m),
                            )
                          : _MMFilledBtn(
                              label: '⬇  Download  (${m.size})',
                              color: m.accentColor,
                              onTap: () => _downloadModel(m),
                            )),
                ),
                // Delete if local exists
                if (local != null && !isActive) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _deleteModel(local),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: RamaColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                RamaColors.error.withValues(alpha: 0.22)),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: RamaColors.error, size: 16),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper widgets ────────────────────────────────────────────────────────────

class _MMIconBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  const _MMIconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:        appTheme.card,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: appTheme.border, width: 0.5),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

class _MMFilledBtn extends StatelessWidget {
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _MMFilledBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.78)],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color:      color.withValues(alpha: 0.28),
              blurRadius: 10,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.w700,
                fontSize:   13,
              )),
        ),
      ),
    );
  }
}

class _MMOutlineBtn extends StatelessWidget {
  final String       label;
  final Color        color;
  final Color        border;
  final VoidCallback onTap;
  const _MMOutlineBtn({
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: border),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                color:      color,
                fontWeight: FontWeight.w700,
                fontSize:   13,
              )),
        ),
      ),
    );
  }
}

class _MMPillBtn extends StatelessWidget {
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _MMPillBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
          border:       Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Text(label,
            style: TextStyle(
              color:      color,
              fontWeight: FontWeight.w700,
              fontSize:   12,
            )),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
              color:      color,
              fontWeight: FontWeight.w700,
              fontSize:   13,
            )),
      ),
    );
  }
}
