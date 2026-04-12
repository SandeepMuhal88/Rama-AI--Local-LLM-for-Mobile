import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'llm_service.dart';

// ─── Palette (same as main.dart) ──────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF080814);
  static const surface   = Color(0xFF10101F);
  static const card      = Color(0xFF161628);
  static const border    = Color(0xFF252540);
  static const accent    = Color(0xFF7C6EF5);
  static const accentAlt = Color(0xFF9B7EFF);
  static const text      = Color(0xFFEAEAF8);
  static const textSub   = Color(0xFF8888AA);
  static const textDim   = Color(0xFF44445A);
}

// ─── Model catalogue ─────────────────────────────────────────────────────────
class ModelInfo {
  final String name;
  final String description;
  final String size;
  final String huggingFaceUrl;
  final String filename;
  final Color  accent;
  final String params;
  final String badge; // e.g. 'Fastest', 'Popular', 'Balanced'

  const ModelInfo({
    required this.name,
    required this.description,
    required this.size,
    required this.huggingFaceUrl,
    required this.filename,
    required this.accent,
    required this.params,
    this.badge = '',
  });
}

const List<ModelInfo> kAvailableModels = [
  ModelInfo(
    name: 'Phi-3 Mini (Instruct)',
    description: 'Microsoft\'s powerful 3.8B model. Excellent for chat & coding.',
    size: '2.2 GB',
    params: '3.8B',
    huggingFaceUrl:
        'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf',
    filename: 'Phi-3-mini-4k-instruct-q4.gguf',
    accent: Color(0xFF7C6EF5),
    badge: 'Popular',
  ),
  ModelInfo(
    name: 'Gemma 2B (IT)',
    description: 'Google\'s lightweight 2B instruct model — fast & efficient.',
    size: '1.5 GB',
    params: '2B',
    huggingFaceUrl: 'https://huggingface.co/google/gemma-2b-it-GGUF',
    filename: 'gemma-2b-it.Q4_K_M.gguf',
    accent: Color(0xFF4DB6AC),
    badge: 'Balanced',
  ),
  ModelInfo(
    name: 'Qwen 2 (1.5B)',
    description: 'Alibaba\'s tiny 1.5B model — runs on very low-end devices.',
    size: '0.9 GB',
    params: '1.5B',
    huggingFaceUrl:
        'https://huggingface.co/Qwen/Qwen2-1.5B-Instruct-GGUF',
    filename: 'qwen2-1_5b-instruct-q4_k_m.gguf',
    accent: Color(0xFFF57C00),
    badge: 'Fastest',
  ),
  ModelInfo(
    name: 'TinyLlama 1.1B',
    description: 'Ultra-lightweight model — best for very limited hardware.',
    size: '0.7 GB',
    params: '1.1B',
    huggingFaceUrl:
        'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
    filename: 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    accent: Color(0xFF66BB6A),
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class ModelManagerScreen extends StatefulWidget {
  final String?               activeModelPath;
  final ValueChanged<String>  onModelSelected;

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
  bool       _loading      = false;
  bool       _importing    = false;
  String     _storageInfo  = '';

  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _loadAll();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final dir    = await LLMService.modelsDir;
    final files  = await LLMService.listModels();
    if (mounted) {
      setState(() {
        _localModels = files;
        _storageInfo = dir.path;
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

  // ── Browse & import ──────────────────────────────────────────────────────────
  Future<void> _browseAndImport() async {
    if (Platform.isAndroid) {
      final perm = await Permission.storage.request();
      if (!perm.isGranted && !perm.isLimited) {}
    }

    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: 'Select a .gguf model file',
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _importing = false);
        return;
      }

      final pickedPath = result.files.single.path;
      if (pickedPath == null) {
        setState(() => _importing = false);
        return;
      }

      if (!pickedPath.toLowerCase().endsWith('.gguf')) {
        _snack('Please select a valid .gguf model file', Colors.orange);
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
        _snack('✅  "$filename" imported successfully!', _C.accent);
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
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _C.accent),
              const SizedBox(height: 20),
              Text(
                'Importing "$filename"…',
                style: const TextStyle(
                    color: _C.text, fontWeight: FontWeight.w600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Copying to app storage, please wait.',
                style: TextStyle(color: _C.textSub, fontSize: 12),
                textAlign: TextAlign.center,
              ),
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
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Delete model?',
                  style: TextStyle(
                      color: _C.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              const SizedBox(height: 10),
              Text(name,
                  style: const TextStyle(color: _C.textSub, fontSize: 13)),
              const SizedBox(height: 6),
              const Text(
                'This will permanently remove the file from app storage.',
                style: TextStyle(color: _C.textDim, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _OutlineBtn(
                        label: 'Cancel',
                        onTap: () => Navigator.pop(ctx, false)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FilledBtn(
                        label: 'Delete',
                        color: Colors.red,
                        onTap: () => Navigator.pop(ctx, true)),
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
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _C.accent))
                  : RefreshIndicator(
                      color: _C.accent,
                      backgroundColor: _C.card,
                      onRefresh: _loadAll,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          // ── IMPORT ─────────────────────────────────────────
                          _buildImportSection(),
                          const SizedBox(height: 24),

                          // ── LOCAL MODELS ───────────────────────────────────
                          _SectionTitle(
                            label: 'LOADED MODELS',
                            trailing: '${_localModels.length} file(s)',
                          ),
                          const SizedBox(height: 10),
                          if (_localModels.isEmpty)
                            _buildNoModels()
                          else
                            ..._localModels.map((f) => _localModelCard(f)),

                          const SizedBox(height: 24),

                          // ── STORAGE ────────────────────────────────────────
                          _SectionTitle(label: 'STORAGE LOCATION'),
                          const SizedBox(height: 10),
                          _buildStorageCard(),
                          const SizedBox(height: 24),

                          // ── HOW TO ─────────────────────────────────────────
                          _SectionTitle(label: 'HOW TO GET MODELS'),
                          const SizedBox(height: 10),
                          _buildHowToCard(),
                          const SizedBox(height: 24),

                          // ── CATALOGUE ──────────────────────────────────────
                          _SectionTitle(
                            label: 'RECOMMENDED MODELS',
                            trailing: 'via HuggingFace',
                          ),
                          const SizedBox(height: 10),
                          ...kAvailableModels.map((m) => _catalogueCard(m)),
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
        decoration: const BoxDecoration(
          color: _C.surface,
          border: Border(bottom: BorderSide(color: _C.border)),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _C.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.border),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _C.textSub, size: 16),
              ),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Model Manager',
                  style: TextStyle(
                      color: _C.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 17),
                ),
                Text(
                  'Manage your on-device AI models',
                  style: TextStyle(color: _C.textSub, fontSize: 11),
                ),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: _loadAll,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _C.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: _C.accent.withValues(alpha: 0.3)),
                ),
                child:
                    const Icon(Icons.refresh_rounded, color: _C.accent, size: 18),
              ),
            ),
          ],
        ),
      );

  // ── Import section ────────────────────────────────────────────────────────────
  Widget _buildImportSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(label: 'IMPORT FROM DEVICE'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _importing ? null : _browseAndImport,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
              decoration: BoxDecoration(
                gradient: _importing
                    ? null
                    : const LinearGradient(
                        colors: [_C.accent, _C.accentAlt],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: _importing ? _C.card : null,
                borderRadius: BorderRadius.circular(18),
                border:
                    _importing ? Border.all(color: _C.border) : null,
                boxShadow: _importing
                    ? []
                    : [
                        BoxShadow(
                          color: _C.accent.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _importing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _C.accent),
                        )
                      : const Icon(Icons.folder_open_rounded,
                          color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    _importing
                        ? 'Importing model…'
                        : 'Browse & Load Model (.gguf)',
                    style: TextStyle(
                      color: _importing ? _C.textSub : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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
          color: _C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _C.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_rounded,
                  color: _C.accent, size: 32),
            ),
            const SizedBox(height: 14),
            const Text('No models yet',
                style: TextStyle(
                    color: _C.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            const SizedBox(height: 6),
            const Text(
              'Tap "Browse & Load" above to select a\n.gguf file from your device.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: _C.textSub, fontSize: 12.5, height: 1.5),
            ),
          ],
        ),
      );

  // ── Local model card ──────────────────────────────────────────────────────────
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
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? _C.accent.withValues(alpha: 0.6) : _C.border,
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
                // Icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isActive
                        ? _C.accent.withValues(alpha: 0.18)
                        : _C.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isActive
                            ? _C.accent.withValues(alpha: 0.4)
                            : _C.border),
                  ),
                  child: Icon(
                    isActive
                        ? Icons.check_circle_rounded
                        : Icons.storage_rounded,
                    color: isActive ? _C.accent : _C.textSub,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: _C.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.sd_storage_rounded,
                              color: _C.textDim, size: 12),
                          const SizedBox(width: 4),
                          Text(sizeStr,
                              style: const TextStyle(
                                  color: _C.textSub, fontSize: 11)),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _C.accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: _C.accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _C.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _C.accent.withValues(alpha: 0.35)),
                        ),
                        child: const Text(
                          'Use',
                          style: TextStyle(
                            color: _C.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _deleteModel(f),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.25)),
                        ),
                        child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                            size: 18),
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

  // ── Storage info card ─────────────────────────────────────────────────────────
  Widget _buildStorageCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.folder_rounded, color: _C.accent, size: 16),
                SizedBox(width: 8),
                Text('Models directory',
                    style: TextStyle(
                        color: _C.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              _storageInfo.isEmpty ? '…' : _storageInfo,
              style: const TextStyle(
                color: _C.textSub,
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(color: _C.border, height: 1),
            const SizedBox(height: 10),
            const Text(
              'Copy GGUF files directly into this folder via USB / PC '
              'and tap Refresh to detect them.',
              style: TextStyle(
                  color: _C.textDim, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      );

  // ── How to card ───────────────────────────────────────────────────────────────
  Widget _buildHowToCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            _howStep(
              number: '01',
              icon: Icons.folder_open_rounded,
              title: 'Browse from device (Easiest)',
              detail:
                  'Tap "Browse & Load" above, then select any .gguf file from your Downloads or any folder on your phone.',
              color: _C.accent,
            ),
            _divider(),
            _howStep(
              number: '02',
              icon: Icons.computer_rounded,
              title: 'Copy via USB / PC',
              detail:
                  'Connect phone → paste .gguf into:\nAndroid › data › com.example.rama_ai › files › RAMA_AI › models',
              color: const Color(0xFF4DB6AC),
            ),
            _divider(),
            _howStep(
              number: '03',
              icon: Icons.open_in_browser_rounded,
              title: 'Download on-device',
              detail:
                  'Open HuggingFace.co in Chrome, download a GGUF, then use "Browse & Load" to select it.',
              color: const Color(0xFFF57C00),
            ),
          ],
        ),
      );

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(color: _C.border, height: 1),
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
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              number,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
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
                    Text(title,
                        style: const TextStyle(
                            color: _C.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(detail,
                    style: const TextStyle(
                        color: _C.textSub, fontSize: 11.5, height: 1.5)),
              ],
            ),
          ),
        ],
      );

  // ── Catalogue card ────────────────────────────────────────────────────────────
  Widget _catalogueCard(ModelInfo info) {
    final local    = _matchLocal(info);
    final isLoaded = local != null;
    final isActive = widget.activeModelPath == local?.path;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLoaded
              ? info.accent.withValues(alpha: 0.4)
              : _C.border,
          width: isLoaded ? 1.2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: (isLoaded && !isActive)
              ? () {
                  widget.onModelSelected(local.path);
                  Navigator.pop(context);
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: info.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: info.accent.withValues(alpha: 0.25)),
                  ),
                  child: Icon(
                    isLoaded
                        ? Icons.check_circle_rounded
                        : Icons.smart_toy_rounded,
                    color: isLoaded
                        ? info.accent
                        : info.accent.withValues(alpha: 0.6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              info.name,
                              style: const TextStyle(
                                color: _C.text,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          if (info.badge.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: info.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                info.badge.toUpperCase(),
                                style: TextStyle(
                                  color: info.accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${info.params} params · ${info.size}',
                        style:
                            const TextStyle(color: _C.textSub, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.description,
                        style: const TextStyle(
                            color: _C.textSub,
                            fontSize: 11.5,
                            height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Status pill
                _StatusPill(
                  isLoaded: isLoaded,
                  isActive: isActive,
                  color: info.accent,
                  onUse: (isLoaded && !isActive)
                      ? () {
                          widget.onModelSelected(local.path);
                          Navigator.pop(context);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String  label;
  final String? trailing;
  const _SectionTitle({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _C.textDim,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Text(
            trailing!,
            style: const TextStyle(color: _C.textDim, fontSize: 10.5),
          ),
        ],
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool         isLoaded;
  final bool         isActive;
  final Color        color;
  final VoidCallback? onUse;
  const _StatusPill({
    required this.isLoaded,
    required this.isActive,
    required this.color,
    this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final label     = isActive ? 'Active' : isLoaded ? 'Use' : 'Not loaded';
    final textColor = isLoaded ? color : _C.textDim;

    return GestureDetector(
      onTap: onUse,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: onUse != null ? 0.14 : 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: textColor.withValues(alpha: onUse != null ? 0.35 : 0.15)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor.withValues(alpha: isLoaded ? 1 : 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: Text(label,
            style: const TextStyle(color: _C.textSub, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _FilledBtn extends StatelessWidget {
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _FilledBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
