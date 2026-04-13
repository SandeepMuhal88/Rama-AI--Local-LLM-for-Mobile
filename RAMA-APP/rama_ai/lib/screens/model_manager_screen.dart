import 'dart:io';
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
  final String huggingFaceUrl;
  final String filename;
  final Color  accentColor;
  final String params;
  final String badge;

  const ModelInfo({
    required this.name,
    required this.description,
    required this.size,
    required this.huggingFaceUrl,
    required this.filename,
    required this.accentColor,
    required this.params,
    this.badge = '',
  });
}

// ─── Model catalogue (with verified HuggingFace file names) ──────────────────
const List<ModelInfo> kAvailableModels = [
  ModelInfo(
    name: 'Phi-3 Mini 4K (Instruct)',
    description: "Microsoft's 3.8B instruct model. Excellent for chat & coding tasks.",
    size: '2.39 GB',
    params: '3.8B',
    huggingFaceUrl:
        'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf',
    filename: 'Phi-3-mini-4k-instruct-q4.gguf',
    accentColor: Color(0xFF7C6EF5),
    badge: 'Popular',
  ),
  ModelInfo(
    name: 'Gemma 4 E2B (Instruct)',
    description: "Google's Gemma 4 2B – multimodal, efficient & fast on-device.",
    size: '3.11 GB',
    params: '2B',
    huggingFaceUrl:
        'https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf',
    filename: 'gemma-4-E2B-it-Q4_K_M.gguf',
    accentColor: Color(0xFF4DB6AC),
    badge: 'New',
  ),
  ModelInfo(
    name: 'Phi-2 (2.7B)',
    description: "Microsoft Phi-2 — punches above its weight for reasoning & code.",
    size: '1.79 GB',
    params: '2.7B',
    huggingFaceUrl:
        'https://huggingface.co/TheBloke/phi-2-GGUF/resolve/main/phi-2.Q4_K_M.gguf',
    filename: 'phi-2.Q4_K_M.gguf',
    accentColor: Color(0xFF26C6DA),
    badge: 'Balanced',
  ),
  ModelInfo(
    name: 'Gemma 1.1 7B (Instruct)',
    description: "Google Gemma 7B — high-quality answers. Requires HF account login.",
    size: '34.2 GB',
    params: '7B',
    huggingFaceUrl:
        'https://huggingface.co/google/gemma-1.1-7b-it-GGUF/tree/main',
    filename: '7b_it_v1p1.gguf',
    accentColor: Color(0xFFAB47BC),
    badge: 'High Quality',
  ),
  ModelInfo(
    name: 'Gemma 4 E2B (Compact Q3)',
    description: "Even smaller Gemma 4 2B at Q3 — for low-RAM devices.",
    size: '2.54 GB',
    params: '2B',
    huggingFaceUrl:
        'https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q3_K_M.gguf',
    filename: 'gemma-4-E2B-it-Q3_K_M.gguf',
    accentColor: Color(0xFF66BB6A),
    badge: 'Smallest',
  ),
];

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

  late final AnimationController _shimmerCtrl;

  // Colour helpers from appTheme
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
    _loadAll();
  }

  @override
  void dispose() {
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

  // ── Browse & import ───────────────────────────────────────────────────────────
  Future<void> _browseAndImport() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: 'Select a .gguf model file',
        withData: false, withReadStream: false,
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
        _snack('✅  "$filename" imported!', _accent);
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
                  style: TextStyle(
                      color: _dim, fontSize: 12, height: 1.4)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _OutlineBtn(
                      label: 'Cancel',
                      color: _sub,
                      border: _border,
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FilledBtn(
                      label: 'Delete',
                      color: Colors.red,
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
                      color: _accent,
                      backgroundColor: _card,
                      onRefresh: _loadAll,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        children: [
                          _buildImportSection(),
                          const SizedBox(height: 24),
                          _SectionTitle(
                            label: 'LOADED MODELS',
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
                            label: 'STORAGE LOCATION',
                            textColor: _sub, dimColor: _dim,
                          ),
                          const SizedBox(height: 10),
                          _buildStorageCard(),
                          const SizedBox(height: 24),
                          _SectionTitle(
                            label: 'HOW TO GET MODELS',
                            textColor: _sub, dimColor: _dim,
                          ),
                          const SizedBox(height: 10),
                          _buildHowToCard(),
                          const SizedBox(height: 24),
                          _SectionTitle(
                            label: 'RECOMMENDED MODELS',
                            trailing: 'via HuggingFace',
                            textColor: _sub, dimColor: _dim,
                          ),
                          const SizedBox(height: 10),
                          ...kAvailableModels.map(_catalogueCard),
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
          color: _surface,
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
                  color: _card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
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
                        color: _text,
                        fontWeight: FontWeight.w800,
                        fontSize: 17)),
                Text('Manage your on-device AI models',
                    style: TextStyle(color: _sub, fontSize: 11)),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: _loadAll,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withValues(alpha: 0.3)),
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
          _SectionTitle(label: 'IMPORT FROM DEVICE', textColor: _sub, dimColor: _dim),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _importing ? null : _browseAndImport,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
              decoration: BoxDecoration(
                gradient: _importing
                    ? null
                    : LinearGradient(
                        colors: [_accent, _accent.withValues(alpha: 0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: _importing ? _card : null,
                borderRadius: BorderRadius.circular(18),
                border: _importing ? Border.all(color: _border) : null,
                boxShadow: _importing
                    ? []
                    : [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
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
                      color: _importing ? _sub : Colors.white,
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
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_rounded, color: _accent, size: 32),
            ),
            const SizedBox(height: 14),
            Text('No models yet',
                style: TextStyle(
                    color: _text, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 6),
            Text('Tap "Browse & Load" above to select a\n.gguf file from your device.',
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
    final isActive = widget.activeModelPath == f.path;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
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
                          ? _accent.withValues(alpha: 0.4)
                          : _border,
                    ),
                  ),
                  child: Icon(
                    isActive ? Icons.check_circle_rounded : Icons.storage_rounded,
                    color: isActive ? _accent : _sub,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
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
                                color: _accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('ACTIVE',
                                  style: TextStyle(
                                    color: _accent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
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
                          color: _accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _accent.withValues(alpha: 0.35)),
                        ),
                        child: Text('Use',
                            style: TextStyle(
                              color: _accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
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

  // ── Storage info card ─────────────────────────────────────────────────────────
  Widget _buildStorageCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
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
                color: _sub, fontSize: 11,
                fontFamily: 'monospace', height: 1.5,
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

  // ── How to card ───────────────────────────────────────────────────────────────
  Widget _buildHowToCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            _howStep(
              number: '01',
              icon: Icons.folder_open_rounded,
              title: 'Browse from device (Easiest)',
              detail:
                  'Tap "Browse & Load" above, select any .gguf file from your Downloads or any folder on your phone.',
              color: _accent,
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
              title: 'Download on-device (Chrome)',
              detail:
                  'Open HuggingFace.co in Chrome, download a GGUF, then use "Browse & Load" to select it.',
              color: const Color(0xFFF57C00),
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
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(detail,
                    style: TextStyle(color: _sub, fontSize: 11.5, height: 1.5)),
              ],
            ),
          ),
        ],
      );

  // ── Catalogue card ────────────────────────────────────────────────────────────
  Widget _catalogueCard(ModelInfo m) {
    final local    = _matchLocal(m);
    final isActive = local != null && widget.activeModelPath == local.path;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? m.accentColor.withValues(alpha: 0.55) : _border,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: m.accentColor.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: m.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
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
                          Flexible(
                            child: Text(m.name,
                                style: TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                )),
                          ),
                          if (m.badge.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: m.accentColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(m.badge,
                                  style: TextStyle(
                                    color: m.accentColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.7,
                                  )),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(m.params,
                              style: TextStyle(
                                  color: m.accentColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11)),
                          Text(' · ${m.size}',
                              style:
                                  TextStyle(color: _sub, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(m.description,
                style: TextStyle(color: _sub, fontSize: 12.5, height: 1.45)),
            const SizedBox(height: 12),
            // Status + action row
            Row(
              children: [
                if (local != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF4CAF50), size: 12),
                        const SizedBox(width: 4),
                        const Text('Downloaded',
                            style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  Expanded(
                    child: Text(
                      'Download from HuggingFace, then import:',
                      style: TextStyle(color: _dim, fontSize: 11),
                    ),
                  ),
                ],
                const Spacer(),
                if (local != null && !isActive)
                  GestureDetector(
                    onTap: () {
                      widget.onModelSelected(local.path);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _accent.withValues(alpha: 0.35)),
                      ),
                      child: Text('Use',
                          style: TextStyle(
                            color: _accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  )
                else if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Active',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
              ],
            ),
            // Filename hint for downloading
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Icon(Icons.file_copy_outlined, color: _dim, size: 13),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.filename,
                      style: TextStyle(
                        color: _sub,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable internal widgets ────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String  label;
  final String  trailing;
  final Color   textColor;
  final Color   dimColor;

  const _SectionTitle({
    required this.label,
    this.trailing = '',
    required this.textColor,
    required this.dimColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            )),
        if (trailing.isNotEmpty) ...[
          const Spacer(),
          Text(trailing,
              style: TextStyle(color: dimColor, fontSize: 10)),
        ],
      ],
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
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }
}

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
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }
}
