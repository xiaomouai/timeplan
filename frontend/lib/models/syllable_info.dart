class SyllableInfo {
  final String word;
  final String phonetic;
  final List<SyllableItem> syllables;
  final int syllableCount;
  final String stressPattern;

  SyllableInfo({
    required this.word,
    required this.phonetic,
    required this.syllables,
    required this.syllableCount,
    required this.stressPattern,
  });

  factory SyllableInfo.fromJson(Map<String, dynamic> json) {
    return SyllableInfo(
      word: json['word'] ?? '',
      phonetic: json['phonetic'] ?? '',
      syllables: (json['syllables'] as List? ?? [])
          .map((item) => SyllableItem.fromJson(item))
          .toList(),
      syllableCount: json['syllable_count'] ?? 0,
      stressPattern: json['stress_pattern'] ?? '',
    );
  }
}

class SyllableItem {
  final String text;
  final String phoneme;
  final int stress;
  final int index;

  SyllableItem({
    required this.text,
    required this.phoneme,
    required this.stress,
    required this.index,
  });

  factory SyllableItem.fromJson(Map<String, dynamic> json) {
    return SyllableItem(
      text: json['text'] ?? '',
      phoneme: json['phoneme'] ?? '',
      stress: json['stress'] ?? 0,
      index: json['index'] ?? 0,
    );
  }
}
