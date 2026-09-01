import 'package:flutter/material.dart';
import '../providers/chat_provider.dart';

/// 语音录制按钮
///
/// 长按开始录音，松手停止录音并识别
class VoiceRecordButton extends StatelessWidget {
  final VoiceState voiceState;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  const VoiceRecordButton({
    super.key,
    required this.voiceState,
    required this.onStartRecording,
    required this.onStopRecording,
  });

  bool get _isRecording => voiceState == VoiceState.recording;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => onStartRecording(),
      onLongPressEnd: (_) => onStopRecording(),
      onLongPressCancel: onStopRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _isRecording
              ? const Color(0xFFFF4D4F)
              : Colors.grey.shade100,
          shape: BoxShape.circle,
          boxShadow: _isRecording
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF4D4F).withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Icon(
          _isRecording ? Icons.mic : Icons.mic_none_rounded,
          color: _isRecording ? Colors.white : Colors.grey.shade600,
          size: 24,
        ),
      ),
    );
  }
}
