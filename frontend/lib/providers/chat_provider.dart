import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../config/chat_config.dart';
import '../services/ai_service.dart';
import '../services/recorder_service.dart';

/// 录音状态枚举
enum VoiceState { idle, recording, recognizing }

/// 聊天状态管理（ChangeNotifier）
///
/// 职责：
/// - 管理消息列表
/// - 管理加载/录音状态
/// - 协调AI服务与录音服务
class ChatProvider extends ChangeNotifier {
  final ChatType chatType;
  final String systemPrompt;
  final String? provider;

  ChatProvider({
    required this.chatType,
    required this.systemPrompt,
    this.provider,
  }) {
    _initScene();
  }

  // ==================== 状态字段 ====================
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  VoiceState _voiceState = VoiceState.idle;
  String _inputText = '';
  
  // 场景动态配置
  String? _dynamicWelcome;
  double? _dynamicTemperature;
  int? _dynamicMaxTokens;
  String? _dynamicSystemPrompt;

  // ==================== Getters ====================
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  VoiceState get voiceState => _voiceState;
  String get inputText => _inputText;
  bool get canSend => _inputText.trim().isNotEmpty && !_isLoading;

  // ==================== 初始化 ====================
  Future<void> _initScene() async {
    // 1. 先添加本地默认欢迎语（快速响应）
    _messages.add(ChatMessage.assistant(ChatConfig.getWelcomeMessage(chatType)));
    notifyListeners();

    try {
      // 2. 尝试从后端获取动态配置
      final config = await AIService.getSceneConfig(chatType.name);
      if (config != null) {
        _dynamicWelcome = config['welcome'];
        _dynamicTemperature = (config['temperature'] as num?)?.toDouble();
        _dynamicMaxTokens = config['max_tokens'] as int?;
        _dynamicSystemPrompt = config['prompt'];

        // 如果后端欢迎语不同，则更新第一条消息
        if (_dynamicWelcome != null && _dynamicWelcome != _messages.first.text) {
          _messages[0] = ChatMessage.assistant(_dynamicWelcome!);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('初始化场景配置失败: $e');
    }
  }

  /// 添加欢迎消息
  void _addWelcomeMessage() {
    final welcome = _dynamicWelcome ?? ChatConfig.getWelcomeMessage(chatType);
    _messages.add(ChatMessage.assistant(welcome));
  }

  // ==================== 输入管理 ====================
  void updateInputText(String text) {
    _inputText = text;
    notifyListeners();
  }

  // ==================== 消息管理 ====================
  /// 发送消息
  Future<void> sendMessage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty || _isLoading) return;

    // 添加用户消息
    _messages.add(ChatMessage.user(trimmedText));
    _inputText = '';
    _isLoading = true;
    notifyListeners();

    try {
      // 构建对话历史（跳过欢迎消息）
      final conversationHistory = _messages
          .skip(1)
          .map((msg) => msg.toApiFormat())
          .toList();

      // 调用AI服务
      final response = await AIService.chat(
        message: trimmedText,
        chatType: chatType.name,
        provider: provider,
        systemPrompt: _dynamicSystemPrompt ?? systemPrompt,
        conversationHistory: conversationHistory,
        temperature: _dynamicTemperature,
        maxTokens: _dynamicMaxTokens,
      );

      if (response.success && response.content != null) {
        _messages.add(ChatMessage.assistant(
          response.content!,
          provider: response.provider,
        ));
      } else {
        _messages.add(ChatMessage.error(
          '抱歉，出现了一些问题。请稍后再试。',
          detail: response.error ?? '未知错误',
        ));
      }
    } catch (e) {
      _messages.add(ChatMessage.error(
        '抱歉，出现了一些问题。请稍后再试。',
        detail: e.toString(),
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清空对话
  void clearChat() {
    _messages.clear();
    _addWelcomeMessage();
    notifyListeners();
  }

  // ==================== 语音录制 ====================

  /// 开始录音
  Future<bool> startRecording() async {
    final success = await RecorderService.start();
    if (success) {
      _voiceState = VoiceState.recording;
      notifyListeners();
    }
    return success;
  }

  /// 停止录音并识别
  Future<String?> stopRecordingAndRecognize() async {
    if (_voiceState != VoiceState.recording) return null;

    _voiceState = VoiceState.recognizing;
    notifyListeners();

    try {
      final audioPath = await RecorderService.stop();
      if (audioPath == null) return null;

      final recognizedText = await AIService.speechToText(audioPath);
      return recognizedText;
    } finally {
      _voiceState = VoiceState.idle;
      notifyListeners();
    }
  }

  /// 取消录音
  Future<void> cancelRecording() async {
    if (_voiceState == VoiceState.recording) {
      await RecorderService.stop();
      _voiceState = VoiceState.idle;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    RecorderService.dispose();
    super.dispose();
  }
}
