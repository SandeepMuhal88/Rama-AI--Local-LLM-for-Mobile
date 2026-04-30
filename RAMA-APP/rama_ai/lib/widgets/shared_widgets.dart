import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
          colors: [
            const Color(0xFF1A1400),
            const Color(0xFF0D0D0D),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: accent.withValues(alpha: 0.55),
          width: size > 40 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color:      accent.withValues(alpha: 0.35),
            blurRadius: size * 0.7,
            offset:     Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.hub_rounded,
          color: accent,
          size:  size * 0.50,
        ),
      ),
    );
  }
}

// ─── Pill chip ────────────────────────────────────────────────────────────────
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
        color:        color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border:       Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color:         textColor ?? color,
          fontSize:      10,
          fontWeight:    FontWeight.w600,
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
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color:        _pressed
                ? widget.color.withValues(alpha: 0.10)
                : widget.bg,
            borderRadius: BorderRadius.circular(10),
            border:       Border.all(color: widget.border),
          ),
          child: Icon(widget.icon, color: widget.color, size: 18),
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
      child: AnimatedScale(
        scale:    _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve:    Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c, c.withValues(alpha: 0.75)],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color:      c.withValues(alpha: _pressed ? 0.12 : 0.28),
                blurRadius: _pressed ? 10 : 24,
                offset:     Offset(0, _pressed ? 3 : 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: GoogleFonts.inter(
                          color:      Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize:   15,
                        )),
                    const SizedBox(height: 3),
                    Text(widget.subtitle,
                        style: GoogleFonts.inter(
                          color:    Colors.white.withValues(alpha: 0.70),
                          fontSize: 12,
                        )),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white60, size: 20),
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
        duration: const Duration(milliseconds: 110),
        width:    double.infinity,
        margin:   const EdgeInsets.only(bottom: 8),
        padding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color:        _pressed
              ? widget.border.withValues(alpha: 0.4)
              : widget.card,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: widget.border),
        ),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, color: widget.sub, size: 14),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.label,
                style: GoogleFonts.inter(
                  color:      widget.text,
                  fontSize:   13.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(Icons.north_east_rounded, color: widget.dim, size: 13),
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
      onTapDown:   (_) { if (widget.enabled) setState(() => _pressed = true); },
      onTapUp:     (_) {
        setState(() => _pressed = false);
        if (widget.enabled) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale:    _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width:    46,
          height:   46,
          decoration: BoxDecoration(
            gradient: widget.enabled
                ? LinearGradient(
                    colors: [
                      widget.accent,
                      widget.accent.withValues(alpha: 0.78),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  )
                : null,
            color:        widget.enabled ? null : widget.card,
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(
              color: widget.enabled ? Colors.transparent : widget.border,
            ),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color:      widget.accent
                          .withValues(alpha: _pressed ? 0.18 : 0.35),
                      blurRadius: _pressed ? 8 : 18,
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
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  )
                : Icon(
                    Icons.arrow_upward_rounded,
                    color: widget.enabled
                        ? Colors.white
                        : widget.accent.withValues(alpha: 0.30),
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────
// Staggered entrance: fade-in + slide-up on first render.
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
  late AnimationController _entryCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
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
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFFFFFFF);

    final textStyle = GoogleFonts.inter(
      color: isUser
          ? Colors.white
          : isError
              ? RamaColors.error
              : widget.textColor,
      fontSize:      15,
      height:        1.68,
      letterSpacing: 0.05,
    );

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: 18,
            left:   isUser ? 48 : 0,
            right:  isUser ? 0  : 48,
          ),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // AI avatar (left)
              if (!isUser) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 10, bottom: 2),
                  child:   LogoBadge(size: 28, accent: accent),
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
                      constraints: BoxConstraints(maxWidth: screenW * 0.78),
                      decoration: BoxDecoration(
                        gradient: isUser
                            ? LinearGradient(
                                colors: [
                                  accent,
                                  accent.withValues(alpha: 0.80),
                                ],
                                begin: Alignment.topLeft,
                                end:   Alignment.bottomRight,
                              )
                            : null,
                        color: isUser
                            ? null
                            : isError
                                ? (isDark
                                    ? const Color(0xFF1E0A0A)
                                    : const Color(0xFFFFEEEE))
                                : aiBubbleBg,
                        borderRadius: BorderRadius.only(
                          topLeft:     const Radius.circular(20),
                          topRight:    const Radius.circular(20),
                          bottomLeft:  Radius.circular(isUser ? 20 : 5),
                          bottomRight: Radius.circular(isUser ? 5 : 20),
                        ),
                        border: isUser
                            ? null
                            : Border.all(
                                color: isError
                                    ? RamaColors.error.withValues(alpha: 0.30)
                                    : widget.border,
                                width: 1,
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: isUser
                                ? accent.withValues(alpha: 0.22)
                                : Colors.black.withValues(
                                    alpha: isDark ? 0.18 : 0.05),
                            blurRadius: 16,
                            offset:     const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: SelectableText(text, style: textStyle),
                    ),

                    // Footer: time + copy
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _fmtTime(time),
                          style: GoogleFonts.inter(
                            color:    widget.dimColor,
                            fontSize: 10,
                          ),
                        ),
                        if (!isUser && !isError) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _copy,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Row(
                                key:          ValueKey(_copied),
                                mainAxisSize: MainAxisSize.min,
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
                                    style: GoogleFonts.inter(
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
                  width:  28,
                  height: 28,
                  decoration: BoxDecoration(
                    color:        accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                    border:       Border.all(
                        color: accent.withValues(alpha: 0.30)),
                  ),
                  child: Center(
                    child: Text(
                      widget.userAvatarEmoji,
                      style: const TextStyle(fontSize: 14),
                    ),
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
      builder: (context, _) => Container(
        width:  widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color:        widget.baseColor
              .withValues(alpha: 0.35 + _anim.value * 0.40),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ─── Custom thin scrollbar ────────────────────────────────────────────────────
// Auto-hiding thin scrollbar wrapper — keeps the UI clean.
class ThinScrollbar extends StatelessWidget {
  final ScrollController controller;
  final Widget           child;
  const ThinScrollbar({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          appTheme.sub.withValues(alpha: 0.35),
        ),
        thickness:       WidgetStateProperty.all(3),
        radius:          const Radius.circular(3),
        interactive:     false,
        thumbVisibility: WidgetStateProperty.all(false),
      ),
      child: Scrollbar(
        controller: controller,
        child:      child,
      ),
    );
  }
}
