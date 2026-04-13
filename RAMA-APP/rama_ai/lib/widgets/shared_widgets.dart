import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_theme.dart';
import '../models/chat_message.dart';

// ─── Logo Badge ───────────────────────────────────────────────────────────────
class LogoBadge extends StatelessWidget {
  final double size;
  final Color  accent;
  const LogoBadge({super.key, this.size = 38, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.4),
            blurRadius: size * 0.5,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: size * 0.47),
    );
  }
}

// ─── Icon Button ──────────────────────────────────────────────────────────────
class RamaIconBtn extends StatelessWidget {
  final IconData     icon;
  final String       tooltip;
  final Color        color;
  final Color        bg;
  final Color        border;
  final VoidCallback onTap;

  const RamaIconBtn({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.bg,
    required this.border,
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
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
      ),
    );
  }
}

// ─── Action Card ──────────────────────────────────────────────────────────────
class ActionCard extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final Color        color;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
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
                        fontSize: 15,
                      )),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Suggestion Chip ──────────────────────────────────────────────────────────
class SuggestionChip extends StatelessWidget {
  final String       label;
  final Color        card, border, text, sub, dim;
  final VoidCallback onTap;

  const SuggestionChip({
    super.key,
    required this.label,
    required this.card,
    required this.border,
    required this.text,
    required this.sub,
    required this.dim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: sub, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    color: text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  )),
            ),
            Icon(Icons.north_east_rounded, color: dim, size: 15),
          ],
        ),
      ),
    );
  }
}

// ─── Send Button ──────────────────────────────────────────────────────────────
class SendButton extends StatelessWidget {
  final bool         enabled;
  final bool         thinking;
  final Color        accent, card, border;
  final VoidCallback onTap;

  const SendButton({
    super.key,
    required this.enabled,
    required this.thinking,
    required this.accent,
    required this.card,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46, height: 46,
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: enabled ? Colors.transparent : border),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Icon(
          thinking ? Icons.hourglass_top_rounded : Icons.arrow_upward_rounded,
          color: enabled ? Colors.white : accent.withValues(alpha: 0.4),
          size: 22,
        ),
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────
class MessageBubble extends StatefulWidget {
  final ChatMessage  message;
  final bool         isLast;
  final String       userName;
  final String       userAvatarEmoji;
  final Color        accent, card, border, textColor, subColor, dimColor;
  final bool         isDark;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isLast,
    required this.userName,
    required this.userAvatarEmoji,
    required this.accent,
    required this.isDark,
    required this.card,
    required this.border,
    required this.textColor,
    required this.subColor,
    required this.dimColor,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _anim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.message.text));
    if (mounted) setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final MessageRole role    = widget.message.role;
    final String      text    = widget.message.text;
    final DateTime    time    = widget.message.time;

    final isUser  = role == MessageRole.user;
    final isError = role == MessageRole.error;

    final width  = MediaQuery.of(context).size.width;
    final accent = widget.accent;
    final isDark = widget.isDark;

    final userBubbleGrad = LinearGradient(
      colors: [accent, accent.withValues(alpha: 0.72)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final aiBubbleBg = isDark ? widget.card : const Color(0xFFF7F7FF);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                LogoBadge(size: 30, accent: accent),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Sender label
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5, left: 4, right: 4),
                      child: Text(
                        isUser ? widget.userName : isError ? 'Error' : 'Rama AI',
                        style: TextStyle(
                          color: isError ? RamaColors.error : isUser ? accent : widget.subColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    // Bubble
                    Container(
                      constraints: BoxConstraints(maxWidth: width * 0.80),
                      decoration: BoxDecoration(
                        gradient: isUser ? userBubbleGrad : null,
                        color: isUser
                            ? null
                            : isError
                                ? (isDark ? const Color(0xFF2A1010) : const Color(0xFFFFECEC))
                                : aiBubbleBg,
                        borderRadius: BorderRadius.only(
                          topLeft:     const Radius.circular(18),
                          topRight:    const Radius.circular(18),
                          bottomLeft:  Radius.circular(isUser ? 18 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 18),
                        ),
                        border: isUser
                            ? null
                            : Border.all(
                                color: isError
                                    ? RamaColors.error.withValues(alpha: 0.4)
                                    : widget.border,
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: isUser
                                ? accent.withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.07),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                      child: SelectableText(
                        text,
                        style: TextStyle(
                          color: isUser
                              ? Colors.white
                              : isError
                                  ? RamaColors.error
                                  : widget.textColor,
                          fontSize: 14.5,
                          height: 1.6,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    // Timestamp + copy
                    Padding(
                      padding: const EdgeInsets.only(top: 5, left: 4, right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _fmtTime(time),
                            style: TextStyle(color: widget.dimColor, fontSize: 10),
                          ),
                          if (!isUser) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _copy,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Row(
                                  key: ValueKey(_copied),
                                  children: [
                                    Icon(
                                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                                      color: _copied ? const Color(0xFF4CAF50) : widget.dimColor,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      _copied ? 'Copied!' : 'Copy',
                                      style: TextStyle(
                                        color: _copied ? const Color(0xFF4CAF50) : widget.dimColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
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
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: Text(widget.userAvatarEmoji, style: const TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
