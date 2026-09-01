import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';

/// 消息气泡组件
/// 
/// 纯展示组件，无业务逻辑
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            _buildAvatar(
              icon: Icons.smart_toy,
              backgroundColor: const Color(0xFF00C897).withOpacity(0.1),
              iconColor: const Color(0xFF00C897),
            ),
            const SizedBox(width: 8),
          ],
          _buildBubbleContent(context),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(
              icon: Icons.person,
              backgroundColor: Colors.blue.shade100,
              iconColor: Colors.blue.shade700,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar({
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  Widget _buildBubbleContent(BuildContext context) {
    return Flexible(
      child: GestureDetector(
        onLongPress: () => _copyToClipboard(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _getBubbleColor(),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(message.isUser ? 16 : 4),
              bottomRight: Radius.circular(message.isUser ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 消息正文
              SelectableText(
                message.text,
                style: TextStyle(
                  color: _getTextColor(),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              // 错误详情 + 重试
              if (message.isError && message.errorDetail != null) ...[
                const SizedBox(height: 4),
                Text(
                  '错误：${message.errorDetail}',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
              if (message.isError && onRetry != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onRetry,
                  child: Text(
                    '点击重试',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
              // 时间戳
              const SizedBox(height: 4),
              Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  color: message.isUser
                      ? Colors.white.withOpacity(0.7)
                      : Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBubbleColor() {
    if (message.isUser) return const Color(0xFF00C897);
    if (message.isError) return Colors.red.shade50;
    return Colors.white;
  }

  Color _getTextColor() {
    if (message.isUser) return Colors.white;
    if (message.isError) return Colors.red.shade700;
    return Colors.black87;
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
