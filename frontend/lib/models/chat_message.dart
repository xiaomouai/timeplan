import 'package:flutter/foundation.dart';

/// 消息角色枚举
enum MessageRole { user, assistant, system }

/// 消息状态枚举
enum MessageStatus { sending, sent, error }

/// 聊天消息模型（不可变）
@immutable
class ChatMessage {
  final String id;
  final String text;
  final MessageRole role;
  final DateTime timestamp;
  final MessageStatus status;
  final String? provider;
  final String? errorDetail;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.provider,
    this.errorDetail,
  });

  bool get isUser => role == MessageRole.user;
  bool get isError => status == MessageStatus.error;

  /// 创建用户消息
  factory ChatMessage.user(String text) => ChatMessage(
        id: _generateId(),
        text: text,
        role: MessageRole.user,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );

  /// 创建AI回复消息
  factory ChatMessage.assistant(String text, {String? provider}) => ChatMessage(
        id: _generateId(),
        text: text,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
        provider: provider,
      );

  /// 创建错误消息
  factory ChatMessage.error(String text, {String? detail}) => ChatMessage(
        id: _generateId(),
        text: text,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.error,
        errorDetail: detail,
      );

  /// 复制并修改
  ChatMessage copyWith({
    String? text,
    MessageStatus? status,
    String? errorDetail,
  }) {
    return ChatMessage(
      id: id,
      text: text ?? this.text,
      role: role,
      timestamp: timestamp,
      status: status ?? this.status,
      provider: provider,
      errorDetail: errorDetail ?? this.errorDetail,
    );
  }

  /// 转换为API格式
  Map<String, String> toApiFormat() => {
        'role': role == MessageRole.user ? 'user' : 'assistant',
        'content': text,
      };

  static String _generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${identityHashCode(Object())}';
}
