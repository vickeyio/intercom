import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../config/theme.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/intercom_providers.dart';
import '../../domain/entities/intercom_role.dart';
import '../../../../config/routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Hard-coded recent rooms for MVP UX (not persisted — purely cosmetic).
// ─────────────────────────────────────────────────────────────────────────────
const _kRecentRooms = ['Shoot_Day_1', 'BTS_Cam', 'VFX_Call'];

class RoomJoinScreen extends ConsumerStatefulWidget {
  const RoomJoinScreen({super.key});

  @override
  ConsumerState<RoomJoinScreen> createState() => _RoomJoinScreenState();
}

class _RoomJoinScreenState extends ConsumerState<RoomJoinScreen> {
  final _roomIdController = TextEditingController(text: 'Shoot_Day_1');
  bool _joining = false;

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  Future<void> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw Exception('Microphone permission denied');
    }
  }

  Future<void> _onJoinPressed(String roomId, IntercomRole role, String myUserId) async {
    setState(() => _joining = true);
    try {
      await _requestMicPermission();
      await ref.read(intercomControllerProvider.notifier).joinRoom(
            roomId: roomId,
            myUserId: myUserId,
            myRole: role,
          );
      if (!mounted) return;
      Navigator.of(context).pushNamed(AppRoutes.intercom);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Join failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRole = ref.watch(roleProvider);
    final userIdState  = ref.watch(userIdProvider);

    final isDirector = selectedRole == IntercomRole.director;
    final accentColor = isDirector ? AppColors.orange : AppColors.blue;
    final badgeLabel  = isDirector ? 'Director Mode' : 'Crew Mode';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // ── Back row ────────────────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left, color: AppColors.orange, size: 22),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.orange.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── Role badge pill ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: accentColor.withValues(alpha: 0.12),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: accentColor.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // ── Room ID field ────────────────────────────────────────
              Text(
                'Room ID',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _roomIdController,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                cursorColor: AppColors.orange,
                decoration: InputDecoration(
                  hintText: 'e.g. Shoot_Day_1',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.surfaceInput,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderStrong),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.orange, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // ── Recent rooms ─────────────────────────────────────────
              Text(
                'Recent rooms',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.25),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _kRecentRooms.map((room) {
                  return GestureDetector(
                    onTap: () => _roomIdController.text = room,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: AppColors.surfaceInput,
                        border: Border.all(
                          color: AppColors.borderStrong,
                        ),
                      ),
                      child: Text(
                        room,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Spacer(),

              // ── Join button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: _joining || selectedRole == null
                    ? _buildJoinButton(context, null, selectedRole, userIdState)
                    : _buildJoinButton(
                        context,
                        () async {
                          final roomId = _roomIdController.text.trim();
                          if (roomId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter a room id')),
                            );
                            return;
                          }
                          final role = selectedRole;
                          await userIdState.when(
                            data: (myUserId) =>
                                _onJoinPressed(roomId, role, myUserId),
                            loading: () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Loading user id...')),
                              );
                            },
                            error: (e, _) =>
                                _onJoinPressed(roomId, role, 'unknown'),
                          );
                        },
                        selectedRole,
                        userIdState,
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoinButton(
    BuildContext context,
    VoidCallback? onPressed,
    IntercomRole? role,
    dynamic userIdState,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: onPressed != null
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.orange, AppColors.orangeDark],
                )
              : null,
          color: onPressed == null
              ? Colors.white.withValues(alpha: 0.06)
              : null,
        ),
        child: Center(
          child: _joining
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Join Room →',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}
