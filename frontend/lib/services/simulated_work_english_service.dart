import 'dart:convert';

/// 工作英语 Demo 数据源。
/// 只在开发环境使用，保证中文输入、知识卡、反馈和转写无需外部服务即可演示。
class SimulatedWorkEnglishService {
  static bool isKnowledgeRequest(String? chatType, String? systemPrompt) {
    return chatType == 'general' &&
        (systemPrompt?.contains('recommended_expressions') == true ||
            systemPrompt?.contains('中文环境中的英语知识教练') == true);
  }

  static bool isSpeakingRequest(String? chatType, String? systemPrompt) {
    return chatType == 'speaking' && systemPrompt?.contains('Training phase:') == true;
  }

  static String knowledgeResponse(String message) {
    Map<String, dynamic> request = const {};
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map) request = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Demo 仍返回完整结构，页面不会因为输入不是 JSON 而中断。
    }

    final source = _value(request, 'source_zh', '今天的工作沟通');
    final scenario = _value(request, 'scenario_zh', '工作沟通');
    final focusWord = _value(request, 'focus_word', '');
    final targetWord = focusWord.isNotEmpty ? focusWord : _targetFor(scenario);
    final expressions = _expressionsFor(scenario);

    return jsonEncode({
      'source_zh': source,
      'target_word': targetWord,
      'meaning_zh': '在$scenario中自然表达重点、细节和下一步。',
      'part_of_speech': targetWord.contains(' ') ? 'phrase' : 'verb',
      'pronunciation': '/ˈfɑːloʊ ʌp/',
      'recommended_expressions': expressions,
      'intent_structure_zh': const [
        '先说明联系或表达的目的。',
        '补充一个关键事实、细节或限制。',
        '明确希望对方完成的下一步。',
      ],
      'opening_line': expressions.first,
      'fallback_line': 'If you need more time, I’m happy to answer any questions.',
      'collocations': [
        '$targetWord with a client',
        'a clear $targetWord',
        'the next step',
      ],
      'example_sentences': [
        'I’d like to clarify the key details before we move forward.',
        'Please let me know if you need any additional information.',
      ],
      'grammar_notes_zh': const [
        'Could you let me know if... 比直接说 Tell me 更礼貌。',
        '先说目的，再说事实，最后用一个问题推进下一步。',
      ],
      'scenarios': const [
        'Follow up with a client by email',
        'Clarify the next step during a client call',
      ],
      'speaking_prompts_zh': [
        '请先用英文说明你想解决什么问题。',
        '请补充一个具体事实、时间或限制。',
        '请明确询问对方的下一步决定或行动。',
      ],
      'short_article': 'A clear work message helps a conversation move forward. '
          'Start by explaining why you are contacting the other person. '
          'Then add one useful detail, such as a deadline, a price, or a delivery update. '
          'Finish with a simple question or a specific next step. '
          'This structure sounds professional without making the message too formal.',
      'speech': 'Today I’d like to follow up on our recent discussion. '
          'I want to make sure we have the same understanding of the key details. '
          'If anything is unclear, I’m happy to explain it. '
          'Could you let me know what the next step should be and when we can expect a decision?',
    });
  }

  static String feedback({required bool retry}) {
    if (retry) {
      return '这次表达更清楚了。你已经补充了关键信息，当前场景可以通过。'
          '自然表达：I’d like to follow up on this matter and confirm the next step。'
          '现在进入下一个工作场景。';
    }
    return '先肯定一点：你已经表达了核心意图。'
        '主要改进：把目的、一个具体细节和下一步按顺序说清楚。'
        '更自然的说法：I’d like to follow up on this matter。'
        '请重说一次，并补充一个具体细节。';
  }

  static const String transcription =
      'I’d like to follow up on this matter and confirm the next step.';

  static String _value(Map<String, dynamic> map, String key, String fallback) {
    final value = map[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }

  static String _targetFor(String scenario) {
    if (scenario.contains('报价')) return 'follow up';
    if (scenario.contains('需求')) return 'clarify';
    if (scenario.contains('价格')) return 'negotiate';
    if (scenario.contains('交期')) return 'handle a delay';
    if (scenario.contains('会议')) return 'give an update';
    if (scenario.contains('升级') || scenario.contains('问题')) return 'escalate';
    return 'follow up';
  }

  static List<String> _expressionsFor(String scenario) {
    if (scenario.contains('需求')) {
      return const [
        'I’d like to clarify the key requirements.',
        'Could we walk through the specifications together?',
      ];
    }
    if (scenario.contains('价格')) {
      return const [
        'I understand your concern about the price.',
        'Let’s see what options we can discuss.',
      ];
    }
    if (scenario.contains('交期')) {
      return const [
        'I’m sorry to let you know that the delivery will be delayed.',
        'Here is the solution we can offer.',
      ];
    }
    if (scenario.contains('会议')) {
      return const [
        'Let me give you a quick update on the project.',
        'The next step is to align on the timeline.',
      ];
    }
    if (scenario.contains('升级') || scenario.contains('问题')) {
      return const [
        'I’d like to raise an issue that needs attention.',
        'Could you help us decide on the next action?',
      ];
    }
    return const [
      'I’d like to follow up on this matter.',
      'Could you let me know if you have any questions?',
    ];
  }
}
