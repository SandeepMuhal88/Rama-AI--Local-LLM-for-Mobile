import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/app_theme.dart';
import '../services/llm_service.dart';

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

  const ModelInfo({
    required this.name,
    required this.description,
    required this.size,
    required this.downloadUrl,
    required this.filename,
    required this.accentColor,
    required this.params,
    this.badge = '',
  });
}

// ─── Catalogue ────────────────────────────────────────────────────────────────
const List<ModelInfo> kAvailableModels = [
  ModelInfo(
    name:        'TinyLlama 1.1B Chat',
    description: 'Tiny but capable! Great for low-RAM devices. Very fast.',
    size:        '0.67 GB',
    params:      '1.1B',
    downloadUrl: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF'
                 '/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    filename:    'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    accentColor: Color(0xFF66BB6A),
    badge:       'Smallest',
  ),
  ModelInfo(
    name:        'Phi-2 (2.7B)',
    description: 'Microsoft Phi-2 — great reasoning & code in a small package.',
    size:        '1.79 GB',
    params:      '2.7B',
    downloadUrl: 'https://huggingface.co/TheBloke/phi-2-GGUF'
                 '/resolve/main/phi-2.Q4_K_M.gguf',
    filename:    'phi-2.Q4_K_M.gguf',
    accentColor: Color(0xFF26C6DA),
    badge:       'Balanced',
  ),
  ModelInfo(
    name:        'Gemma 2B Instruct',
    description: "Google's efficient 2B instruct model. Quality chat responses.",
    size:        '1.35 GB',
    params:      '2B',
    downloadUrl: 'https://huggingface.co/google/gemma-2b-it-GGUF'
                 '/resolve/main/2b_it_v1p1.gguf',
    filename:    'gemma-2b-it-q4.gguf',
    accentColor: Color(0xFF4DB6AC),
    badge:       'Default',
  ),
  ModelInfo(
    name:        'Phi-3 Mini 4K Instruct',
    description: "Microsoft's 3.8B chat & coding powerhouse.",
    size:        '2.39 GB',
    params:      '3.8B',
    downloadUrl: 'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf'
                 '/resolve/main/Phi-3-mini-4k-instruct-q4.gguf',
    filename:    'Phi-3-mini-4k-instruct-q4.gguf',
    accentColor: Color(0xFF7C6EF5),
    badge:       'Popular',
  ),
];

// ─── Download state per model ─────────────────────────────────────────────────
class _DownloadState {
  bool   active   = false;
  double progress = 0.0;  // 0–1
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
  List<File> _localModels = [];
  bool _loading   = false;
  bool _importing = false;
  String _storagePath = '';

  // Download states keyed by filename
  final Map<String, _DownloadState> _downloads = {};

  late final AnimationController _shimmerCtrl;

  // Colour helpers
  Color get _bg      => appTheme.isDark ? RamaColors.darkBg      : RamaColors.lightBg;
  Color get _surface => appTheme.isDark ? RamaColors.darkSurface  : RamaColors.lightSurface;
  Color get _card    => appTheme.isDark ? RamaColors.darkCard     : RamaColors.lightCard;
  Color get _border  => appTheme.isDark ? RamaColors.darkBorder   : RamaColors.lightBorder;
  Color get _text    => appTheme.isDark ? RamaColors.darkText     : RamaColors.lightText;
  Color get _sub     => appTheme.isDark ? RamaColors.darkTextSub  : RamaColors.lightTextSub;
  Color get _dim     => appTheme.isDark ? RamaColors.darkTextDim  : RamaColors.lightTextDim;
  Color get _accent  => appTheme.accent;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    appTheme.addListener(() { if (mounted) setState(() {}); });
    // Initialise download state map
    for (final m in kAvailableModels) {
      _downloads[m.filename] = _DownloadState();
    }
    _loadAll();
  }

  @override
  void dispose() {
    // Cancel any active downloads on dispose
    for (final ds in _downloads.values) {
      ds.token?.cancel('Screen disposed');
    }
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final dir   = await LLMService.modelsDir;
    final files = await LLMService.listModels();
    if (mounted) {
      setState(() {
        _localModels = files;
        _storagePath = dir.path;
        _loading     = false;
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

  // ── Download via Dio ──────────────────────────────────────────────────────────
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
      ds.progress = 0.0;
      ds.status   = 'Connecting…';
      ds.token    = token;
    });

    try {
      final dio = Dio();
      await dio.download(
        info.downloadUrl,
        destPath,
        cancelToken: token,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          if (total > 0) {
            setState(() {
              ds.progress = received / total;
              final mb    = received / (1024 * 1024);
              final tMb   = total   / (1024 * 1024);
              ds.status   = '${mb.toStringAsFixed(0)} / ${tMb.toStringAsFixed(0)} MB';
            });
          }
        },
      );

      await _loadAll();
      if (mounted) {
        _snack('✅ ${info.name} downloaded!', _accent);
        // Auto-select if no model loaded
        if (widget.activeModelPath == null) {
          widget.onModelSelected(destPath);
          Navigator.pop(context);
          return;
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // delete partial file
        if (destFile.existsSync()) destFile.deleteSync();
        if (mounted) _snack('Download cancelled', Colors.orange);
      } else {
        if (mounted) _snack('Download failed: ${e.message}', Colors.red);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          ds.active   = false;
          ds.progress = 0.0;
          ds.status   = '';
          ds.token    = null;
        });
      }
    }
  }

  void _cancelDownload(ModelInfo info) {
    _downloads[info.filename]?.token?.cancel('User cancelled');
  }

  // ── Browse & import ───────────────────────────────────────────────────────────
  Future<void> _browseAndImport() async {
    if (Platform.isAndroid) await Permission.storage.request();
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type:        FileType.any,
        allowMultiple: false,
        dialogTitle: 'Select a .gguf model file',
        withData:    false, withReadStream: false,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _importing = false);
        return;
      }
      final pickedPath = result.files.single.path;
      if (pickedPath == null || !pickedPath.toLowerCase().endsWith('.gguf')) {
        _snack('Please select a valid .gguf file', Colors.orange);
        setState(() => _importing = false);
        return;
      }

      final srcFile  = File(pickedPath);
      final filename = pickedPath.split('/').last;
      final destPath = await LLMService.modelSavePath(filename);
      final destFile = File(destPath);

      if (!destFile.existsSync()) {
        if (mounted) _showCopyingDialog(filename);
        await srcFile.copy(destPath);
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }

      await _loadAll();
      if (mounted) {
        _snack('✅ "$filename" imported!', _accent);
        if (widget.activeModelPath == null) {
          widget.onModelSelected(destPath);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) _snack('Error importing: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showCopyingDialog(String filename) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _accent),
              const SizedBox(height: 20),
              Text('Importing "$filename"…',
                  style: TextStyle(
                      color: _text, fontWeight: FontWeight.w600, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Copying to app storage, please wait.',
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete model?',
                  style: TextStyle(
                      color: _text, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 10),
              Text(name, style: TextStyle(color: _sub, fontSize: 13)),
              const SizedBox(height: 6),
              Text('This will permanently remove the file from app storage.',
                  style: TextStyle(color: _dim, fontSize: 12, height: 1.4)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _OutlineBtn(
                      label: 'Cancel', color: _sub, border: _border,
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FilledBtn(
                      label: 'Delete', color: Colors.red,
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

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:          Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor:  bg,
        behavior:         SnackBarBehavior.floating,
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin:           const EdgeInsets.all(12),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: _accent))
                  : RefreshIndicator(
                      color:           _accent,
                      backgroundColor: _card,
                      onRefresh:       _loadAll,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        children: [
                          _buildImportSection(),
                          const SizedBox(height: 24),

                          _SectionTitle(
                            label:    'DOWNLOADED MODELS',
                            trailing: '${_localModels.length} file(s)',
                            textColor: _sub, dimColor: _dim,
                          ),
                          const SizedBox(height: 10),
                          if (_localModels.isEmpty)
                            _buildNoModels()
                          else
                            ..._localModels.map(_localModelCard),

                          const SizedBox(height: 24),
                          _SectionTitle(
                            label:    'STORAGE LOCATION',
                            textColor: _sub, dimColor: _dim,
                          ),
                          const SizedBox(height: 10),
                          _buildStorageCard(),

                          const SizedBox(height: 24),
                          _SectionTitle(
                            label:    'DOWNLOAD MODELS',
                            trailing: 'via HuggingFace',
                            textColor: _sub, dimColor: _dim,
                          ),
                          const SizedBox(height: 10),
                          ...kAvailableModels.map(_catalogueCard),

                          const SizedBox(height: 24),
                          _SectionTitle(
                            label:    'HOW TO GET MODELS',
                            textColor: _sub, dimColor: _dim,
                          ),
                          const SizedBox(height: 10),
                          _buildHowToCard(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Container(
        decoration: BoxDecoration(
          color:  _surface,
          border: Border(bottom: BorderSide(color: _border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:         _card,
                  borderRadius:  BorderRadius.circular(10),
                  border:        Border.all(color: _border),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: _sub, size: 16),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Model Manager',
                    style: TextStyle(
                        color: _text, fontWeight: FontWeight.w800, fontSize: 17)),
                Text('Download & manage on-device models',
                    style: TextStyle(color: _sub, fontSize: 11)),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: _loadAll,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:        _accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border:       Border.all(color: _accent.withValues(alpha: 0.30)),
                ),
                child: Icon(Icons.refresh_rounded, color: _accent, size: 18),
              ),
            ),
          ],
        ),
      );

  // ── Import section ────────────────────────────────────────────────────────────
  Widget _buildImportSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
              label: 'IMPORT FROM DEVICE', textColor: _sub, dimColor: _dim),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _importing ? null : _browseAndImport,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
              decoration: BoxDecoration(
                gradient: _importing
                    ? null
                    : LinearGradient(
                        colors: [_accent, _accent.withValues(alpha: 0.75)],
                        begin: Alignment.topLeft,
                        end:   Alignment.bottomRight,
                      ),
                color:        _importing ? _card : null,
                borderRadius: BorderRadius.circular(18),
                border:       _importing ? Border.all(color: _border) : null,
                boxShadow: _importing
                    ? []
                    : [
                        BoxShadow(
                          color:      _accent.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset:     const Offset(0, 8),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _importing
                      ? SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _accent),
                        )
                      : const Icon(Icons.folder_open_rounded,
                          color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    _importing
                        ? 'Importing model…'
                        : 'Browse & Load Model (.gguf)',
                    style: TextStyle(
                      color:      _importing ? _sub : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize:   15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  // ── No models card ────────────────────────────────────────────────────────────
  Widget _buildNoModels() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color:         _card,
          borderRadius:  BorderRadius.circular(16),
          border:        Border.all(color: _border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_rounded, color: _accent, size: 32),
            ),
            const SizedBox(height: 14),
            Text('No models yet',
                style: TextStyle(
                    color: _text, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 6),
            Text(
                'Download a model below or\ntap "Browse & Load" to import one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _sub, fontSize: 12.5, height: 1.5)),
          ],
        ),
      );

  // ── Local model card ──────────────────────────────────────────────────────────
  Widget _localModelCard(File f) {
    final name      = f.path.split('/').last;
    final sizeBytes = f.lengthSync();
    final sizeMB    = sizeBytes / (1024 * 1024);
    final sizeStr   = sizeMB >= 1024
        ? '${(sizeMB / 1024).toStringAsFixed(2)} GB'
        : '${sizeMB.toStringAsFixed(0)} MB';
    final isActive  = widget.activeModelPath == f.path;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:  _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? _accent.withValues(alpha: 0.6) : _border,
          width: isActive ? 1.5 : 1,
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
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: isActive
                        ? _accent.withValues(alpha: 0.18)
                        : _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? _accent.withValues(alpha: 0.40)
                          : _border,
                    ),
                  ),
                  child: Icon(
                    isActive ? Icons.check_circle_rounded : Icons.storage_rounded,
                    color: isActive ? _accent : _sub,
                    size:  22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                            color:      _text,
                            fontWeight: FontWeight.w600,
                            fontSize:   13,
                          ),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.sd_storage_rounded, color: _dim, size: 12),
                          const SizedBox(width: 4),
                          Text(sizeStr,
                              style: TextStyle(color: _sub, fontSize: 11)),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:         _accent.withValues(alpha: 0.16),
                                borderRadius:  BorderRadius.circular(6),
                              ),
                              child: Text('ACTIVE',
                                  style: TextStyle(
                                    color:         _accent,
                                    fontSize:      9,
                                    fontWeight:    FontWeight.w800,
                                    letterSpacing: 0.8,
                                  )),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color:        _accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border:       Border.all(
                              color: _accent.withValues(alpha: 0.35)),
                        ),
                        child: Text('Use',
                            style: TextStyle(
                              color:      _accent,
                              fontSize:   12,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _deleteModel(f),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color:        Colors.red.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border:       Border.all(
                              color: Colors.red.withValues(alpha: 0.25)),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Colors.red, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Catalogue card (with download progress) ───────────────────────────────────
  Widget _catalogueCard(ModelInfo m) {
    final local    = _matchLocal(m);
    final isActive = local != null && widget.activeModelPath == local.path;
    final ds       = _downloads[m.filename]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color:         _card,
        borderRadius:  BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? m.accentColor.withValues(alpha: 0.55)
              : _border,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: appTheme.isDark ? 0.22 : 0.06),
            blurRadius: 12,
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
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color:        m.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border:       Border.all(
                        color: m.accentColor.withValues(alpha: 0.35)),
                  ),
                  child: Icon(Icons.memory_rounded,
                      color: m.accentColor, size: 24),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: m.accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(m.badge,
                                  style: TextStyle(
                                    color:      m.accentColor,
                                    fontSize:   10,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.data_usage_rounded,
                              color: _dim, size: 12),
                          const SizedBox(width: 4),
                          Text('${m.params}  •  ${m.size}',
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

            const SizedBox(height: 14),

            // Download progress bar (only when downloading)
            if (ds.active) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Downloading…  ${ds.status}',
                          style: TextStyle(color: _sub, fontSize: 11)),
                      Text('${(ds.progress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color:      m.accentColor,
                            fontSize:   11,
                            fontWeight: FontWeight.w700,
                          )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value:            ds.progress,
                      minHeight:        6,
                      backgroundColor:  _border,
                      valueColor:       AlwaysStoppedAnimation(m.accentColor),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ],

            // Action buttons row
            Row(
              children: [
                // Status / use button
                Expanded(
                  child: local != null
                      ? (isActive
                          ? _badgeChip('✓ Active', m.accentColor)
                          : _OutlineBtn(
                              label: 'Use This Model',
                              color: m.accentColor,
                              border: m.accentColor.withValues(alpha: 0.4),
                              onTap: () {
                                widget.onModelSelected(local.path);
                                Navigator.pop(context);
                              },
                            ))
                      : (ds.active
                          ? _OutlineBtn(
                              label: 'Cancel',
                              color: Colors.red,
                              border: Colors.red.withValues(alpha: 0.4),
                              onTap: () => _cancelDownload(m),
                            )
                          : _FilledBtn(
                              label: '⬇  Download  (${m.size})',
                              color: m.accentColor,
                              onTap: () => _downloadModel(m),
                            )),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: color.withValues(alpha: 0.35)),
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

  // ── Storage info card ─────────────────────────────────────────────────────────
  Widget _buildStorageCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        _card,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_rounded, color: _accent, size: 16),
                const SizedBox(width: 8),
                Text('Models directory',
                    style: TextStyle(
                        color: _text, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              _storagePath.isEmpty ? '…' : _storagePath,
              style: TextStyle(
                color:      _sub,
                fontSize:   11,
                fontFamily: 'monospace',
                height:     1.5,
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: _border, height: 1),
            const SizedBox(height: 10),
            Text(
              'Copy GGUF files directly into this folder via USB / PC '
              'and tap Refresh to detect them.',
              style: TextStyle(color: _dim, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      );

  // ── How-to card ───────────────────────────────────────────────────────────────
  Widget _buildHowToCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        _card,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: _accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            _howStep(
              number: '01',
              icon:   Icons.download_rounded,
              title:  'Download in-app (Easiest)',
              detail: 'Tap the ⬇ Download button on any model card above. '
                      'Progress is shown in real-time.',
              color:  _accent,
            ),
            _divider(),
            _howStep(
              number: '02',
              icon:   Icons.folder_open_rounded,
              title:  'Browse from device',
              detail: 'Tap "Browse & Load" to select any .gguf file '
                      'already on your phone.',
              color:  const Color(0xFF4DB6AC),
            ),
            _divider(),
            _howStep(
              number: '03',
              icon:   Icons.computer_rounded,
              title:  'Copy via USB / PC',
              detail: 'Paste .gguf into:\n'
                      'Android › data › com.example.rama_ai › files › RAMA_AI › models',
              color:  const Color(0xFFF57C00),
            ),
          ],
        ),
      );

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Divider(color: _border, height: 1),
      );

  Widget _howStep({
    required String   number,
    required IconData icon,
    required String   title,
    required String   detail,
    required Color    color,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(number,
                style: TextStyle(
                  color:      color,
                  fontSize:   11,
                  fontWeight: FontWeight.w800,
                )),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                            color:      _text,
                            fontWeight: FontWeight.w600,
                            fontSize:   13,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(detail,
                    style: TextStyle(
                        color: _sub, fontSize: 11.5, height: 1.5)),
              ],
            ),
          ),
        ],
      );
}

// ─── Helper button widgets ─────────────────────────────────────────────────────
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.75)],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color:      color.withValues(alpha: 0.35),
              blurRadius: 12,
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.08),
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

class _SectionTitle extends StatelessWidget {
  final String  label;
  final String? trailing;
  final Color   textColor;
  final Color   dimColor;

  const _SectionTitle({
    required this.label,
    this.trailing,
    required this.textColor,
    required this.dimColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
              color:         textColor,
              fontSize:      10.5,
              fontWeight:    FontWeight.w800,
              letterSpacing: 1.2,
            )),
        const Spacer(),
        if (trailing != null)
          Text(trailing!,
              style: TextStyle(color: dimColor, fontSize: 10.5)),
      ],
    );
  }
}
