import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../domain/entities/intercom_role.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRole = ref.watch(roleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // ── Logo ───────────────────────────────────────────────
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(28, 28),
                    painter: _SignalIconPainter(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'CrewComm',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Film Production Intercom',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SELECT YOUR ROLE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.12,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 24),
              // ── Role cards ────────────────────────────────────────
              _RoleCard(
                role: IntercomRole.director,
                selectedRole: selectedRole,
                onTap: () {
                  ref.read(roleProvider.notifier).state = IntercomRole.director;
                  Navigator.of(context).pushNamed('/room');
                },
              ),
              const SizedBox(height: 12),
              _RoleCard(
                role: IntercomRole.crew,
                selectedRole: selectedRole,
                onTap: () {
                  ref.read(roleProvider.notifier).state = IntercomRole.crew;
                  Navigator.of(context).pushNamed('/room');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role card with animated press scale
// ─────────────────────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.role,
    required this.selectedRole,
    required this.onTap,
  });

  final IntercomRole role;
  final IntercomRole? selectedRole;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  Color get _accentColor =>
      widget.role == IntercomRole.director ? AppColors.orange : AppColors.blue;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _accentColor.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _accentColor.withValues(alpha: 0.18),
                ),
                child: Center(
                  child: widget.role == IntercomRole.director
                      ? _DirectorIcon(color: _accentColor)
                      : _CrewIcon(color: _accentColor),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.role.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _accentColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.role == IntercomRole.director
                        ? 'Speak to all crew'
                        : 'Listen & respond',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                color: _accentColor.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom icon painters
// ─────────────────────────────────────────────────────────────────────────────

/// Signal / broadcast icon for the app logo
class _SignalIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.22;

    // Center dot
    canvas.drawCircle(Offset(cx, cy), r, paint..style = PaintingStyle.fill);

    paint.style = PaintingStyle.stroke;

    // Cross arms
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height * 0.3), paint);
    canvas.drawLine(Offset(cx, size.height * 0.7), Offset(cx, size.height), paint);
    canvas.drawLine(Offset(0, cy), Offset(size.width * 0.3, cy), paint);
    canvas.drawLine(Offset(size.width * 0.7, cy), Offset(size.width, cy), paint);
  }

  @override
  bool shouldRepaint(_SignalIconPainter _) => false;
}

/// Video-camera icon for Director role
class _DirectorIcon extends StatelessWidget {
  const _DirectorIcon({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.videocam_outlined, color: color, size: 22);
  }
}

/// Group / people icon for Crew role  
class _CrewIcon extends StatelessWidget {
  const _CrewIcon({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.people_outline, color: color, size: 22);
  }
}
