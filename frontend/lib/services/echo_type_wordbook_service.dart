import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/word_book.dart';

class EchoTypeWordBookEntry {
  const EchoTypeWordBookEntry({required this.word, required this.sentence});

  final String word;
  final String sentence;

  factory EchoTypeWordBookEntry.fromJson(Map<String, dynamic> json) {
    final word = (json['word'] as String?)?.trim() ?? '';
    final sentence = (json['sentence'] as String?)?.trim() ?? '';
    if (word.isEmpty || sentence.isEmpty) {
      throw const FormatException('EchoType 词条缺少 word 或 sentence。');
    }
    return EchoTypeWordBookEntry(word: word, sentence: sentence);
  }
}

class EchoTypeWordBookDefinition {
  const EchoTypeWordBookDefinition({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.description,
    required this.assetPath,
    required this.itemCount,
  });

  final String id;
  final String name;
  final String nameEn;
  final String description;
  final String assetPath;
  final int itemCount;
}

/// Local EchoType wordbooks imported into the Flutter product.
class EchoTypeWordBookService {
  EchoTypeWordBookService._();

  static const definitions = <EchoTypeWordBookDefinition>[
    EchoTypeWordBookDefinition(
      id: 'business-english',
      name: '工作英语例句',
      nameEn: 'Business English',
      description: '会议、客户、项目和职场沟通中的高频表达。',
      assetPath: 'assets/wordbooks/echo_type/business-english.json',
      itemCount: 100,
    ),
    EchoTypeWordBookDefinition(
      id: 'daily-vocab',
      name: '日常英语例句',
      nameEn: 'Daily Essentials',
      description: '日常生活、出行和社交场景中的高频表达。',
      assetPath: 'assets/wordbooks/echo_type/daily-vocab.json',
      itemCount: 100,
    ),
  ];

  static final _cache = <String, Future<List<EchoTypeWordBookEntry>>>{};

  static EchoTypeWordBookDefinition definition(String id) => definitions.firstWhere(
        (book) => book.id == id,
        orElse: () => definitions.first,
      );

  static Future<List<EchoTypeWordBookEntry>> load(String id) {
    return _cache.putIfAbsent(id, () async {
      final raw = await rootBundle.loadString(definition(id).assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('EchoType 词库必须是 JSON 数组。');
      }
      return decoded
          .whereType<Map>()
          .map((item) => EchoTypeWordBookEntry.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    });
  }

  static List<WordData> toWordData(String id, List<EchoTypeWordBookEntry> entries) {
    return [
      for (var index = 0; index < entries.length; index++)
        WordData(
          word: entries[index].word,
          translation: _chineseText(entries[index].sentence) ? entries[index].sentence : '',
          bookId: 'echo-type:$id',
          wordRank: index + 1,
          detailData: {
            'source': 'EchoType',
            'wordbookId': id,
            'sentence': entries[index].sentence,
          },
        ),
    ];
  }

  static EchoTypeWordBookEntry? find(
    List<EchoTypeWordBookEntry> entries,
    String query,
  ) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return null;

    for (final entry in entries) {
      if (_normalize(entry.word) == normalizedQuery) return entry;
    }
    for (final entry in entries) {
      if (_normalize(entry.word).startsWith(normalizedQuery)) return entry;
    }
    return null;
  }

  static String _normalize(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static bool _chineseText(String value) => RegExp(r'[\u4e00-\u9fff]').hasMatch(value);
}
