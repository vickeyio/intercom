import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../config/theme.dart';
import '../../domain/entities/communication_mode.dart';
import '../../domain/entities/intercom_role.dart';

/// Animated PTT (push-to-talk) button with pulsing glow ring when active.
///
/// Publically keeps the same API as before — only visual implementation changed.
class PttButton extends StatefulWidget {
  const PttButton({
    super.key,
    required this.enabled,
    required this.isTalking,
    required this.role,
    required this.mode,
    required this.onPressedStart,
    required this.onPressedEnd,
  });

  final bool enabled;
  final bool isTalking;
  final IntercomRole role;
  final CommunicationMode mode;
  final Future<void> Function() onPressedStart;
  final Future<void> Function() onPressedEnd;

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(PttButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTalking && !oldWidget.isTalking) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isTalking && oldWidget.isTalking) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails _) {
    if (!widget.enabled) return;
    HapticFeedback.mediumImpact();
    setState(() => _pressed = true);
    unawaited(widget.onPressedStart());
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    setState(() => _pressed = false);
    unawaited(widget.onPressedEnd());
  }

  void _onLongPressCancel() {
    setState(() => _pressed = false);
    unawaited(widget.onPressedEnd());
  }

  @override
  Widget build(BuildContext context) {
    final isDirector = widget.role == IntercomRole.director;
    final isCrewOpenMic = !isDirector && widget.enabled && widget.mode == CommunicationMode.openMic;

    final primaryColor = isCrewOpenMic ? AppColors.blue : AppColors.orange;
    final secondaryColor = isCrewOpenMic ? const Color(0xFF1E88E5) : AppColors.orangeDark;

    return GestureDetector(
      onLongPressStart: widget.enabled ? _onLongPressStart : null,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return AnimatedScale(
                scale: _pressed ? 0.93 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow halo (only visible during talking)
                    if (widget.isTalking)
                      Transform.scale(
                        scale: _pulseAnim.value,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                    // Outer ring
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.enabled
                              ? primaryColor.withValues(alpha: 0.35)
                              : Colors.white.withValues(alpha: 0.1),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Main button circle
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: widget.enabled
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [primaryColor, secondaryColor],
                              )
                            : null,
                        color: widget.enabled ? null : Colors.white.withValues(alpha: 0.08),
                        boxShadow: widget.isTalking
                            ? [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.45),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: widget.enabled
                            ? _MicIcon(color: Colors.white.withValues(alpha: 0.95))
                            : Icon(
                                Icons.lock_outline,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 28,
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              !widget.enabled
                  ? 'Director only'
                  : widget.isTalking
                      ? 'Transmitting…'
                      : 'Hold to speak',
              key: ValueKey('${widget.enabled}_${widget.isTalking}'),
              style: TextStyle(
                fontSize: 12,
                color: !widget.enabled
                    ? AppColors.textMuted
                    : widget.isTalking
                        ? primaryColor.withValues(alpha: 0.8)
                        : AppColors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mic SVG icon drawn with Canvas — avoids needing an icon font for this shape.
class _MicIcon extends StatelessWidget {
  const _MicIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: CustomPaint(painter: _MicPainter(color: color)),
    );
  }
}

class _MicPainter extends CustomPainter {
  _MicPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // Mic capsule body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.38),
        width: size.width * 0.38,
        height: size.height * 0.46,
      ),
      const Radius.circular(20),
    );
    canvas.drawRRect(bodyRect, paint);

    // Arc beneath capsule
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.58),
        width: size.width * 0.56,
        height: size.height * 0.36,
      ),
      3.14,
      3.14,
      false,
      paint,
    );

    // Vertical stem
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.76),
      Offset(size.width / 2, size.height * 0.92),
      paint,
    );

    // Horizontal base
    canvas.drawLine(
      Offset(size.width * 0.33, size.height * 0.92),
      Offset(size.width * 0.67, size.height * 0.92),
      paint,
    );
  }

  @override
  bool shouldRepaint(_MicPainter oldDelegate) => oldDelegate.color != color;
}
