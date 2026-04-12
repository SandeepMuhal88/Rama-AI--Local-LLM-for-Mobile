import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'llm_service.dart';

// ─── Available models catalogue ──────────────────────────────────────────────
class ModelInfo {
  final String name;
  final String description;
  final String size;
  final String url;
  final String filename;
  final Color accent;

  const ModelInfo({
    required this.name,
    required this.description,
    required this.size,
    required this.url,
    required this.filename,
    required this.accent,
  });
}

const List<ModelInfo> kAvailableModels = [
  ModelInfo(
    name: 'Phi-3 Mini (Instruct)',
    description: 'Microsoft\'s powerful 3.8B model, great for chat & coding.',
    size: '2.2 GB',
    url:
        'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf',
    filename: 'phi3-mini-q4.gguf',
    accent: Color(0xFF6C63FF),
  ),
  ModelInfo(
    name: 'Gemma 2B (IT)',
    description: 'Google\'s lightweight 2B instruct model. Fast & efficient.',
    size: '1.5 GB',
    url:
        'https://huggingface.co/google/gemma-2b-it-GGUF/resolve/main/gemma-2b-it.Q4_K_M.gguf',
    filename: 'gemma-2b-it-q4.gguf',
    accent: Color(0xFF4DB6AC),
  ),
  ModelInfo(
    name: 'Qwen 1.5B (Chat)',
    description: 'Alibaba\'s tiny 1.5B model. Fastest option, runs everywhere.',
    size: '0.9 GB',
    url:
        'https://huggingface.co/Qwen/Qwen2-1.5B-Instruct-GGUF/resolve/main/qwen2-1_5b-instruct-q4_k_m.gguf',
    filename: 'qwen2-1.5b-q4.gguf',
    accent: Color(0xFFF57C00),
  ),
  ModelInfo(
    name: 'TinyLlama 1.1B',
    description: 'Ultra-lightweight model for very low-end devices.',
    size: '0.7 GB',
    url:
        'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    filename: 'tinyllama-1.1b-q4.gguf',
    accent: Color(0xFF81C784),
  ),
];

// ─── Model Manager Screen ─────────────────────────────────────────────────────
class ModelManagerScreen extends StatefulWidget {
  final String? activeModelPath;
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
  final Map<String, double> _progress = {};
  final Map<String, CancelToken> _cancelTokens = {};
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadLocalModels();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocalModels() async {
    final files = await LLMService.listModels();
    if (mounted) setState(() => _localModels = files);
  }

  bool _isDownloaded(ModelInfo info) =>
      _localModels.any((f) => f.path.endsWith(info.filename));

  File? _localFile(ModelInfo info) {
    try {
      return _localModels.firstWhere((f) => f.path.endsWith(info.filename));
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadModel(ModelInfo info) async {
    // Permission check
    final perm = await Permission.storage.request();
    if (!perm.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission required')),
      );
      return;
    }

    final savePath = await LLMService.modelSavePath(info.filename);
    final token = CancelToken();
    _cancelTokens[info.filename] = token;
    setState(() => _progress[info.filename] = 0.0);

    try {
      await Dio().download(
        info.url,
        savePath,
        cancelToken: token,
        onReceiveProgress: (rcv, total) {
          if (total > 0 && mounted) {
            setState(() => _progress[info.filename] = rcv / total);
          }
        },
      );
      await _loadLocalModels();
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _progress.remove(info.filename);
          _cancelTokens.remove(info.filename);
        });
      }
    }
  }

  void _cancelDownload(ModelInfo info) {
    _cancelTokens[info.filename]?.cancel();
  }

  Future<void> _deleteModel(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Delete model?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          file.path.split('/').last,
          style: const TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      file.deleteSync();
      await _loadLocalModels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
        title: const Text(
          'Model Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white12),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Local models ──────────────────────────────────────────────────
          if (_localModels.isNotEmpty) ...[
            _sectionHeader('Downloaded Models'),
            ..._localModels.map((f) => _localModelCard(f)),
            const SizedBox(height: 20),
          ],

          // ── Download catalogue ────────────────────────────────────────────
          _sectionHeader('Available to Download'),
          ...kAvailableModels.map((info) => _downloadCard(info)),
          const SizedBox(height: 40),
          _customUrlHint(),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      );

  Widget _localModelCard(File f) {
    final name = f.path.split('/').last;
    final sizeKB = f.lengthSync() / 1024;
    final sizeMB = sizeKB / 1024;
    final sizeStr =
        sizeMB > 1024 ? '${(sizeMB / 1024).toStringAsFixed(1)} GB' : '${sizeMB.toStringAsFixed(0)} MB';
    final isActive = widget.activeModelPath == f.path;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? const Color(0xFF6C63FF)
              : Colors.white12,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF6C63FF).withOpacity(0.18)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isActive ? Icons.check_circle_rounded : Icons.storage_rounded,
            color: isActive ? const Color(0xFF6C63FF) : Colors.white38,
            size: 22,
          ),
        ),
        title: Text(name,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(sizeStr,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isActive)
              TextButton(
                onPressed: () {
                  widget.onModelSelected(f.path);
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF).withOpacity(0.15),
                  foregroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Use', style: TextStyle(fontSize: 12)),
              ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Active',
                    style: TextStyle(
                        color: Color(0xFF6C63FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: () => _deleteModel(f),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _downloadCard(ModelInfo info) {
    final downloaded = _isDownloaded(info);
    final downloading = _progress.containsKey(info.filename);
    final progress = _progress[info.filename] ?? 0.0;
    final localFile = _localFile(info);
    final isActive = widget.activeModelPath == localFile?.path;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: info.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.smart_toy_rounded,
                      color: info.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(info.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Text(info.size,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                if (downloaded && !downloading)
                  _pillButton(
                    label: isActive ? 'Active' : 'Use',
                    color: isActive ? Colors.white12 : info.accent,
                    textColor:
                        isActive ? Colors.white38 : Colors.white,
                    onTap: isActive
                        ? null
                        : () {
                            widget.onModelSelected(localFile!.path);
                            Navigator.pop(context);
                          },
                  )
                else if (downloading)
                  GestureDetector(
                    onTap: () => _cancelDownload(info),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Cancel',
                          style:
                              TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  )
                else
                  _pillButton(
                    label: 'Download',
                    color: info.accent,
                    textColor: Colors.white,
                    icon: Icons.download_rounded,
                    onTap: () => _downloadModel(info),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(info.description,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12, height: 1.4)),
            if (downloading) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(info.accent),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text('${(progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: info.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required Color color,
    required Color textColor,
    IconData? icon,
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(onTap == null ? 0.1 : 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: color.withOpacity(onTap == null ? 0.2 : 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: textColor, size: 14),
                const SizedBox(width: 4),
              ],
              Text(label,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

  Widget _customUrlHint() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Colors.white38, size: 16),
                SizedBox(width: 8),
                Text('Custom model',
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'You can also manually copy any .gguf file into:\n'
              'Android › sdcard › RAMA_AI › models\n\n'
              'It will appear automatically in the "Downloaded Models" section above.',
              style: TextStyle(
                  color: Colors.white38, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      );
}
