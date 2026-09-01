import 'package:flutter/material.dart';
import '../providers/chat_provider.dart';
import 'voice_record_button.dart';

/// 聊天输入栏
///
/// 包含：录音按钮 + 文本输入框 + 发送按钮
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoiceState voiceState;
  final VoidCallback onSend;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final ValueChanged<String> onTextChanged;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.voiceState,
    required this.onSend,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 录音按钮
            VoiceRecordButton(
              voiceState: voiceState,
              onStartRecording: onStartRecording,
              onStopRecording: onStopRecording,
            ),
            const SizedBox(width: 8),

            // 文本输入框
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: voiceState == VoiceState.recognizing
                        ? '正在识别语音...'
                        : '输入消息...',
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onChanged: onTextChanged,
                  onSubmitted: (_) => onSend(),
                  enabled: voiceState == VoiceState.idle,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 发送按钮
            GestureDetector(
              onTap: isLoading ? null : onSend,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isLoading
                      ? Colors.grey.shade300
                      : const Color(0xFF00C897),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: isLoading ? Colors.grey.shade500 : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
