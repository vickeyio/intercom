import 'package:flutter/material.dart';
import '../../../../config/theme.dart';
import '../../domain/entities/tts_message.dart';

class TtsInputPanel extends StatefulWidget {
  final String pendingText;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onBroadcast;
  final bool isSpeaking;

  const TtsInputPanel({
    super.key,
    required this.pendingText,
    required this.onTextChanged,
    required this.onBroadcast,
    required this.isSpeaking,
  });

  @override
  State<TtsInputPanel> createState() => _TtsInputPanelState();
}

class _TtsInputPanelState extends State<TtsInputPanel> {
  bool _expanded = false;
  late TextEditingController _controller;

  final List<String> _quickPhrases = [
    'Face the pastor',
    'Face the congregation',
    'On air!',
    'Stand by'
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.pendingText);
  }

  @override
  void didUpdateWidget(TtsInputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingText != _controller.text && widget.pendingText.isEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceInput,
              borderRadius: _expanded
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.keyboard_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Text(
                  'Type broadcast',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: !_expanded
              ? const SizedBox.shrink()
              : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInput,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _quickPhrases.map((phrase) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(phrase),
                                labelStyle: const TextStyle(fontSize: 11, color: Colors.white70),
                                backgroundColor: AppColors.background,
                                side: BorderSide.none,
                                onPressed: () {
                                  _controller.text = phrase;
                                  widget.onTextChanged(phrase);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Input field
                      TextField(
                        controller: _controller,
                        maxLength: 300,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                        onChanged: widget.onTextChanged,
                        decoration: InputDecoration(
                          hintText: 'Type a message to read aloud...',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          counterStyle: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (widget.isSpeaking)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Playing...',
                                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.orange,
                                disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: widget.pendingText.trim().isEmpty ? null : widget.onBroadcast,
                              child: const Text(
                                'Broadcast',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}


class TtsCrewBanner extends StatelessWidget {
  final bool isVisible;
  final String text;

  const TtsCrewBanner({
    super.key,
    required this.isVisible,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      top: isVisible ? 16 : -100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D24),
          borderRadius: BorderRadius.circular(16),
          border: const Border(left: BorderSide(color: AppColors.orange, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.record_voice_over, color: AppColors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Director:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
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

class TtsQueueIndicator extends StatelessWidget {
  final int count;

  const TtsQueueIndicator({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.orange),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.queue, size: 14, color: AppColors.orange),
            const SizedBox(width: 6),
            Text(
              '$count queued',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TtsMessageLog extends StatelessWidget {
  final List<TtsMessage> messages;

  const TtsMessageLog({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: messages.length,
        separatorBuilder: (context, index) => Divider(
          color: AppColors.borderStrong.withValues(alpha: 0.5),
          height: 16,
        ),
        itemBuilder: (context, index) {
          final msg = messages[index];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  msg.text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
