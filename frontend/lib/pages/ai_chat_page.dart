import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/chat_config.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_loading_indicator.dart';
import '../utils/sound_service.dart';

/// AI聊天对话页面 (重构后)
///
/// 采用 Provider 进行状态管理，组件化拆分 UI
class AIChatPage extends StatefulWidget {
  final String chatType;
  final String title;
  final String systemPrompt;
  final String? provider;

  const AIChatPage({
    super.key,
    required this.chatType,
    required this.title,
    required this.systemPrompt,
    this.provider,
  });

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  late ChatProvider _chatProvider;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chatProvider = ChatProvider(
      chatType: ChatConfig.fromString(widget.chatType),
      systemPrompt: widget.systemPrompt,
      provider: widget.provider,
    );

    // 监听消息列表变化，自动滚动到底部
    _chatProvider.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    _chatProvider.removeListener(_scrollToBottom);
    _chatProvider.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _chatProvider,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: _buildAppBar(context),
        body: Column(
          children: [
            // 消息列表区
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, _) {
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: provider.messages.length + (provider.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < provider.messages.length) {
                        final message = provider.messages[index];
                        return ChatMessageBubble(
                          message: message,
                          onRetry: message.isError 
                              ? () => provider.sendMessage(provider.messages[index-1].text) 
                              : null,
                        );
                      } else {
                        return const ChatLoadingIndicator();
                      }
                    },
                  );
                },
              ),
            ),

            // 输入栏区
            Consumer<ChatProvider>(
              builder: (context, provider, _) {
                return ChatInputBar(
                  controller: _messageController,
                  isLoading: provider.isLoading,
                  voiceState: provider.voiceState,
                  onTextChanged: provider.updateInputText,
                  onSend: () {
                    final text = _messageController.text;
                    if (text.trim().isNotEmpty) {
                      SoundService.playTapSound();
                      provider.sendMessage(text);
                      _messageController.clear();
                    }
                  },
                  onStartRecording: () async {
                    SoundService.playTapSound();
                    await provider.startRecording();
                  },
                  onStopRecording: () async {
                    final recognizedText = await provider.stopRecordingAndRecognize();
                    if (recognizedText != null && recognizedText.isNotEmpty) {
                      _messageController.text = recognizedText;
                      provider.updateInputText(recognizedText);
                      // 自动发送识别出的消息
                      provider.sendMessage(recognizedText);
                      _messageController.clear();
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Consumer<ChatProvider>(
            builder: (context, provider, _) {
              if (provider.voiceState == VoiceState.recording) {
                return const Text('正在录音...', style: TextStyle(fontSize: 12, color: Colors.white70));
              }
              if (provider.voiceState == VoiceState.recognizing) {
                return const Text('正在识别...', style: TextStyle(fontSize: 12, color: Colors.white70));
              }
              return Text(provider.isLoading ? '对方正在输入...' : '在线', 
                  style: const TextStyle(fontSize: 12, color: Colors.white70));
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFF00C897),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          onPressed: () => _showClearDialog(context),
          icon: const Icon(Icons.delete_outline),
          tooltip: '清空对话',
        ),
      ],
    );
  }

  void _showClearDialog(BuildContext context) {
    SoundService.playTapSound();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空对话'),
        content: const Text('确定要清空所有对话记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _chatProvider.clearChat();
              Navigator.pop(context);
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
