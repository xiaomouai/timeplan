/// 聊天类型枚举
enum ChatType {
  general,
  speaking,
  grammar,
  writing,
  translate,
  qa,
  planning,
  vocabulary,
}

/// 聊天配置 — 集中管理各类型的欢迎语和默认参数
class ChatConfig {
  static const Map<ChatType, String> welcomeMessages = {
    ChatType.general: '你好！我是Luna老师，有什么可以帮你的吗？可以用中文或英文和我交流哦~',
    ChatType.speaking:
        'Hi! Let\'s practice English speaking! You can talk to me in English, and I\'ll help you improve. 😊',
    ChatType.grammar: '你好！我会帮你解答任何语法问题，也可以帮你检查句子的语法是否正确。',
    ChatType.writing: '你好！我可以帮你写英语作文，或者修改你的作文。告诉我作文题目或发送你的作文吧~',
    ChatType.translate: '你好！我可以帮你翻译中英文。直接发送需要翻译的内容即可！',
    ChatType.qa: '你好！我是你的百科小助手，有任何问题都可以问我~',
    ChatType.planning: '你好！我可以帮你制定学习计划，提供学习建议。告诉我你的学习目标吧！',
    ChatType.vocabulary: '你好！我可以帮你拓展词汇，学习同义词、反义词、词组搭配等。',
  };

  /// 从字符串解析聊天类型
  static ChatType fromString(String type) {
    return ChatType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => ChatType.general,
    );
  }

  /// 获取欢迎消息
  static String getWelcomeMessage(ChatType type) {
    return welcomeMessages[type] ?? '你好！有什么可以帮你的吗？';
  }

  /// AI参数配置
  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 2000;
}
