import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_theme.dart';
import '../models/chat_message.dart';

// ─── Rama Logo Badge ──────────────────────────────────────────────────────────
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
          colors: [accent, accent.withValues(alpha: 0.65)],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.30),
        boxShadow: [
          BoxShadow(
            color:      accent.withValues(alpha: 0.35),
            blurRadius: size * 0.55,
            offset:     Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size:  size * 0.48,
      ),
    );
  }
}

// ─── Pill chip label ──────────────────────────────────────────────────────────
class PillChip extends StatelessWidget {
  final String label;
  final Color  color;
  final Color? textColor;
  const PillChip({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border:       Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:         textColor ?? color,
          fontSize:      10,
          fontWeight:    FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Tappable icon button ─────────────────────────────────────────────────────
class RamaIconBtn extends StatefulWidget {
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
  State<RamaIconBtn> createState() => _RamaIconBtnState();
}

class _RamaIconBtnState extends State<RamaIconBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown:   (_) => setState(() => _pressed = true),
        onTapUp:     (_) => setState(() => _pressed = false),
        onTapCancel: ()  => setState(() => _pressed = false),
        onTap:       widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color:        _pressed
                ? widget.color.withValues(alpha: 0.12)
                : widget.bg,
            borderRadius: BorderRadius.circular(10),
            border:       Border.all(color: widget.border),
          ),
          child: Icon(widget.icon, color: widget.color, size: 19),
        ),
      ),
    );
  }
}

// ─── Large gradient action card ───────────────────────────────────────────────
class ActionCard extends StatefulWidget {
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
  State<ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Transform.scale(
        scale: _pressed ? 0.97 : 1.0,
        child: AnimatedContainer(
          duration:    const Duration(milliseconds: 150),
          curve:       Curves.easeOut,
          padding:     const EdgeInsets.all(18),
          decoration:  BoxDecoration(
            gradient: LinearGradient(
              colors: [c, c.withValues(alpha: 0.72)],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:      c.withValues(alpha: _pressed ? 0.15 : 0.30),
                blurRadius: _pressed ? 12 : 22,
                offset:     Offset(0, _pressed ? 4 : 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color:      Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize:   15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color:   Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white60,
                size:  22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Suggestion Chip ──────────────────────────────────────────────────────────
class SuggestionChip extends StatefulWidget {
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
  State<SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<SuggestionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width:    double.infinity,
        margin:   const EdgeInsets.only(bottom: 8),
        padding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color:        _pressed
              ? widget.border.withValues(alpha: 0.5)
              : widget.card,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: widget.border),
        ),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, color: widget.sub, size: 15),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  color:      widget.text,
                  fontSize:   13.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(Icons.north_east_rounded, color: widget.dim, size: 14),
          ],
        ),
      ),
    );
  }
}

// ─── Send Button ──────────────────────────────────────────────────────────────
class SendButton extends StatefulWidget {
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
  State<SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<SendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) {
        if (widget.enabled) setState(() => _pressed = true);
      },
      onTapUp:     (_) {
        setState(() => _pressed = false);
        if (widget.enabled) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Transform.scale(
        scale: _pressed ? 0.92 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width:    46,
          height:   46,
          decoration: BoxDecoration(
            gradient: widget.enabled
                ? LinearGradient(
                    colors: [
                      widget.accent,
                      widget.accent.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  )
                : null,
            color:        widget.enabled ? null : widget.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.enabled ? Colors.transparent : widget.border,
            ),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color:      widget.accent.withValues(
                          alpha: _pressed ? 0.20 : 0.38),
                      blurRadius: _pressed ? 8 : 16,
                      offset:     Offset(0, _pressed ? 2 : 6),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: widget.thinking
                ? SizedBox(
                    width:  18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  )
                : Icon(
                    Icons.arrow_upward_rounded,
                    color: widget.enabled
                        ? Colors.white
                        : widget.accent.withValues(alpha: 0.35),
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────
class MessageBubble extends StatefulWidget {
  final ChatMessage  message;
  final bool         isLast;
  final bool         isStreaming;
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
    this.isStreaming = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  bool _copied = false;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
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
    final role    = widget.message.role;
    final text    = widget.message.text;
    final time    = widget.message.time;
    final isUser  = role == MessageRole.user;
    final isError = role == MessageRole.error;
    final screenW = MediaQuery.of(context).size.width;
    final accent  = widget.accent;
    final isDark  = widget.isDark;

    final aiBubbleBg = isDark
        ? const Color(0xFF111111)
        : const Color(0xFFFFFFFF);

    final textStyle = TextStyle(
      color: isUser
          ? Colors.white
          : isError
              ? RamaColors.error
              : widget.textColor,
      fontSize:      15,
      height:        1.65,
      letterSpacing: 0.1,
    );

    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 16,
          left:   isUser ? 40 : 0,
          right:  isUser ? 0  : 40,
        ),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // AI avatar (left)
            if (!isUser) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: LogoBadge(size: 30, accent: accent),
              ),
            ],

            // Bubble column
            Flexible(
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Bubble body
                  Container(
                    constraints: BoxConstraints(maxWidth: screenW * 0.80),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? LinearGradient(
                              colors: [
                                accent,
                                accent.withValues(alpha: 0.78),
                              ],
                              begin: Alignment.topLeft,
                              end:   Alignment.bottomRight,
                            )
                          : null,
                      color: isUser
                          ? null
                          : isError
                              ? (isDark
                                  ? const Color(0xFF1A0808)
                                  : const Color(0xFFFFEEEE))
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
                                  ? RamaColors.error.withValues(alpha: 0.35)
                                  : widget.border,
                              width: 1,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: isUser
                              ? accent.withValues(alpha: 0.20)
                              : Colors.black.withValues(
                                  alpha: isDark ? 0.20 : 0.06),
                          blurRadius: 12,
                          offset:     const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 11),
                    child: SelectableText(text, style: textStyle),
                  ),

                  // Footer: time + copy
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fmtTime(time),
                        style: TextStyle(
                            color: widget.dimColor, fontSize: 10),
                      ),
                      if (!isUser && !isError) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _copy,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Row(
                              key:             ValueKey(_copied),
                              mainAxisSize:    MainAxisSize.min,
                              children: [
                                Icon(
                                  _copied
                                      ? Icons.check_rounded
                                      : Icons.copy_rounded,
                                  color: _copied
                                      ? RamaColors.success
                                      : widget.dimColor,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _copied ? 'Copied' : 'Copy',
                                  style: TextStyle(
                                    color: _copied
                                        ? RamaColors.success
                                        : widget.dimColor,
                                    fontSize:   10,
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
                ],
              ),
            ),

            // User avatar (right)
            if (isUser) ...[
              const SizedBox(width: 8),
              Container(
                width:  30,
                height: 30,
                decoration: BoxDecoration(
                  color:        accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border:       Border.all(
                      color: accent.withValues(alpha: 0.35)),
                ),
                child: Center(
                  child: Text(
                    widget.userAvatarEmoji,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

// ─── Divider ──────────────────────────────────────────────────────────────────
class RamaDivider extends StatelessWidget {
  final Color  color;
  final double indent;
  const RamaDivider({super.key, required this.color, this.indent = 0});

  @override
  Widget build(BuildContext context) {
    return Divider(
      color:      color,
      height:     1,
      indent:     indent,
      endIndent:  indent,
      thickness:  0.5,
    );
  }
}

// ─── Shimmer placeholder ──────────────────────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  final double width, height, radius;
  final Color  baseColor;
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius    = 10,
    required this.baseColor,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width:  widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color:        widget.baseColor.withValues(
              alpha: 0.4 + _anim.value * 0.4),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
