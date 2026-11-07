import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../config/theme.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/intercom_providers.dart';
import '../../domain/entities/communication_mode.dart';
import '../../domain/entities/intercom_connection_status.dart';
import '../../domain/entities/intercom_role.dart';
import '../widgets/ptt_button.dart';
import '../widgets/tts_widgets.dart';

class IntercomScreen extends ConsumerStatefulWidget {
  const IntercomScreen({super.key});

  @override
  ConsumerState<IntercomScreen> createState() => _IntercomScreenState();
}

class _IntercomScreenState extends ConsumerState<IntercomScreen>
    with TickerProviderStateMixin {
  bool _tryingAcquire = false;

  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _syncWaveAnimation(bool isSpeaking) {
    if (isSpeaking) {
      _waveController.repeat(reverse: true);
    } else {
      _waveController.stop();
      _waveController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final role       = ref.watch(roleProvider);
    final state      = ref.watch(intercomControllerProvider);
    final controller = ref.read(intercomControllerProvider.notifier);

    final canSpeak =
        (role == IntercomRole.director || state.communicationMode == CommunicationMode.openMic) &&
        state.connectionStatus == IntercomConnectionStatus.connected &&
        !_tryingAcquire;

    final isSpeaking = state.activeSpeakerIds.isNotEmpty;
    final amIDirector = role == IntercomRole.director;

    _syncWaveAnimation(isSpeaking);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Top bar ─────────────────────────────────────────────
                  _TopBar(
                    mode: state.communicationMode,
                    role: role,
                    onModeSelected: (mode) => controller.setCommunicationMode(mode),
                    onLeave: () async {
                      await controller.leaveRoom();
                      if (!context.mounted) return;
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                  ),
                  const SizedBox(height: 8),

                  // ── Room chip ────────────────────────────────────────────
                  _RoomChip(memberCount: state.memberIds.length + 1),
                  const SizedBox(height: 12),

                  // ── Member avatars ───────────────────────────────────────
                  _MembersRow(
                    memberCount: state.memberIds.length + 1,
                    activeSpeakerIds: state.activeSpeakerIds,
                    role: role,
                    myUserId: null,
                  ),
                  const SizedBox(height: 8),

                  // ── Connection status ────────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: switch (state.connectionStatus) {
                      IntercomConnectionStatus.connecting =>
                        const Padding(
                          key: ValueKey('connecting'),
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.orange,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Connecting…',
                                style: TextStyle(fontSize: 12, color: AppColors.orange),
                              ),
                            ],
                          ),
                        ),
                      IntercomConnectionStatus.error =>
                        Padding(
                          key: const ValueKey('error'),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            state.errorMessage ?? 'Connection error',
                            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                          ),
                        ),
                      _ => const SizedBox.shrink(key: ValueKey('ok')),
                    },
                  ),

                  // ── Scrollable body: wave centre + bottom controls ───────
                  // Pattern: Expanded > LayoutBuilder > SingleChildScrollView >
                  // ConstrainedBox(minHeight) > Column(spaceBetween).
                  // This lets bottom controls grow (e.g. TTS panel expand) by
                  // scrolling, without causing overflow in the outer Column.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // ── Wave + status centre ───────────────────
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: isSpeaking
                                        ? AppColors.orange.withValues(alpha: 0.04)
                                        : Colors.transparent,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 250),
                                        child: !isSpeaking
                                            ? const SizedBox(
                                                key: ValueKey('no-waves'), height: 20)
                                            : state.communicationMode ==
                                                    CommunicationMode.intercom
                                                ? _WaveBars(
                                                    key: const ValueKey('waves_intercom'),
                                                    controller: _waveController,
                                                  )
                                                : _MultiSpeakerChips(
                                                    key: const ValueKey('waves_openmic'),
                                                    activeSpeakerIds: state.activeSpeakerIds,
                                                    controller: _waveController,
                                                  ),
                                      ),
                                      const SizedBox(height: 10),
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 200),
                                        child: Text(
                                          isSpeaking
                                              ? 'Director speaking…'
                                              : 'Listening…',
                                          key: ValueKey(isSpeaking),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: isSpeaking
                                                ? AppColors.orange.withValues(alpha: 0.85)
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 200),
                                        child: _StatusPill(
                                          key: ValueKey(isSpeaking),
                                          isLive: isSpeaking,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // ── Bottom controls ────────────────────────
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!amIDirector &&
                                        state.communicationMode ==
                                            CommunicationMode.intercom)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: Text(
                                          'Hold your phone near your earphones.\n'
                                          'You will hear the director.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textMuted,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),

                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: PttButton(
                                        enabled: canSpeak,
                                        isTalking: state.amTalking,
                                        role: role ?? IntercomRole.crew,
                                        mode: state.communicationMode,
                                        onPressedStart: () async {
                                          if (!canSpeak) return;
                                          setState(() => _tryingAcquire = true);
                                          final ok = await controller.startTalk();
                                          setState(() => _tryingAcquire = false);
                                          if (!ok && context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Speaker lock is busy'),
                                              ),
                                            );
                                          }
                                        },
                                        onPressedEnd: () async {
                                          if (!mounted) return;
                                          await controller.stopTalk();
                                        },
                                      ),
                                    ),

                                    if (!amIDirector &&
                                        state.queuedTtsMessages.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: TtsQueueIndicator(
                                          count: state.queuedTtsMessages.length,
                                        ),
                                      ),

                                    if (amIDirector)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: TtsInputPanel(
                                          pendingText: state.pendingTtsText,
                                          onTextChanged: controller.updateTtsText,
                                          onBroadcast: controller.broadcastTtsMessage,
                                          isSpeaking: state.isTtsSpeaking,
                                        ),
                                      ),

                                    if (state.ttsMessageHistory.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: TtsMessageLog(
                                          messages: state.ttsMessageHistory,
                                        ),
                                      ),

                                    const SizedBox(height: 4),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── TTS crew banner overlay ───────────────────────────────────
            TtsCrewBanner(
              isVisible: !amIDirector &&
                  state.isTtsSpeaking &&
                  state.ttsMessageHistory.isNotEmpty,
              text: state.ttsMessageHistory.isNotEmpty
                  ? state.ttsMessageHistory.first.text
                  : '',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar widget
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatefulWidget {
  const _TopBar({
    required this.onLeave,
    required this.mode,
    required this.role,
    required this.onModeSelected,
  });
  final VoidCallback onLeave;
  final CommunicationMode mode;
  final IntercomRole? role;
  final ValueChanged<CommunicationMode> onModeSelected;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  bool _isSpeakerOn = true;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (widget.role == IntercomRole.director)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceInput,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeSegment(CommunicationMode.intercom, 'Intercom'),
                _buildModeSegment(CommunicationMode.openMic, 'Open Mic'),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: widget.mode == CommunicationMode.intercom
                  ? AppColors.orange.withValues(alpha: 0.15)
                  : AppColors.blue.withValues(alpha: 0.15),
              border: Border.all(
                color: widget.mode == CommunicationMode.intercom
                    ? AppColors.orange.withValues(alpha: 0.3)
                    : AppColors.blue.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              widget.mode == CommunicationMode.intercom ? 'Intercom' : 'Open Mic',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.mode == CommunicationMode.intercom
                    ? AppColors.orange
                    : AppColors.blue,
              ),
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                setState(() => _isSpeakerOn = !_isSpeakerOn);
                Helper.setSpeakerphoneOn(_isSpeakerOn).catchError((_) {});
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSpeakerOn
                      ? AppColors.orange.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
                ),
                child: Icon(
                  _isSpeakerOn ? Icons.volume_up : Icons.phone_in_talk,
                  size: 18,
                  color: _isSpeakerOn ? AppColors.orange : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: widget.onLeave,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Leave',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeSegment(CommunicationMode mode, String label) {
    final isSelected = widget.mode == mode;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          widget.onModeSelected(mode);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Switched to $label mode'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? AppColors.orange : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Room chip
// ─────────────────────────────────────────────────────────────────────────────

class _RoomChip extends StatelessWidget {
  const _RoomChip({required this.memberCount});
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.surfaceInput,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.meeting_room_outlined, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Text('Active room', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.orange.withValues(alpha: 0.15),
            ),
            child: Text(
              '$memberCount',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Members avatar row
// ─────────────────────────────────────────────────────────────────────────────

class _MembersRow extends StatelessWidget {
  const _MembersRow({
    required this.memberCount,
    required this.activeSpeakerIds,
    required this.role,
    this.myUserId,
  });

  final int memberCount;
  final Set<String> activeSpeakerIds;
  final IntercomRole? role;
  final String? myUserId;

  @override
  Widget build(BuildContext context) {
    const maxVisible = 4;
    final shown = memberCount.clamp(0, maxVisible);
    final overflow = (memberCount - maxVisible).clamp(0, 99);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < shown; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _Avatar(
              index: i,
              isDirector: i == 0,
              isSpeaking: activeSpeakerIds.isNotEmpty && i == 0,
            ),
          ),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '+$overflow',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.index,
    required this.isDirector,
    required this.isSpeaking,
  });

  final int index;
  final bool isDirector;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isDirector
        ? (isSpeaking ? AppColors.orange : AppColors.orange.withValues(alpha: 0.4))
        : Colors.white.withValues(alpha: 0.15);

    final Color bgColor = isDirector
        ? AppColors.orange.withValues(alpha: isSpeaking ? 0.2 : 0.1)
        : Colors.white.withValues(alpha: 0.06);

    final Color textColor = isDirector
        ? AppColors.orange.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.5);

    final label = isDirector ? 'D' : 'C$index';

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated sound wave bars
// ─────────────────────────────────────────────────────────────────────────────

class _WaveBars extends StatelessWidget {
  const _WaveBars({super.key, required this.controller});

  final AnimationController controller;

  static const _barHeights = [0.35, 0.8, 0.55, 1.0, 0.45, 0.7];
  static const _phaseOffsets = [0.0, 0.2, 0.4, 0.1, 0.5, 0.3];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(_barHeights.length, (i) {
            final progress = (controller.value + _phaseOffsets[i]) % 1.0;
            final height = 6 + (_barHeights[i] * 18 * math.sin(progress * math.pi));
            return Container(
              width: 3,
              height: height.clamp(4.0, 24.0),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated multi-speaker chips
// ─────────────────────────────────────────────────────────────────────────────

class _MultiSpeakerChips extends StatelessWidget {
  const _MultiSpeakerChips({
    super.key,
    required this.activeSpeakerIds,
    required this.controller,
  });

  final Set<String> activeSpeakerIds;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    if (activeSpeakerIds.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: activeSpeakerIds.map((id) {
          final isDirector = id.hashCode % 2 == 0;
          final color = isDirector ? AppColors.orange : AppColors.blue;
          final label = isDirector ? 'D' : 'C';

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 16,
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      return Row(
                        children: List.generate(3, (i) {
                          final progress = (controller.value + (i * 0.2)) % 1.0;
                          final height = 4 + (8 * math.sin(progress * math.pi));
                          return Container(
                            width: 2,
                            height: height.clamp(2.0, 12.0),
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live / Listening status pill
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({super.key, required this.isLive});
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final color = isLive ? AppColors.orange : AppColors.blue;
    final label = isLive ? 'Live' : 'Listening';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

