/// 词库模型
/// 表示一个可选择的词库，包含基本信息和词汇数据链接
class WordBook {
  final String id;             // 词书ID (API使用)
  final String name;           // 词库名称
  final String translationUrl; // 单词和翻译CSV文件的URL (兼容旧代码)
  final int wordCount;         // 单词数量
  final String? coverUrl;      // 封面图片URL
  
  const WordBook({
    this.id = '',
    required this.name,
    this.translationUrl = '',
    this.wordCount = 0,
    this.coverUrl,
  });

  /// 从JSON创建WordBook对象
  factory WordBook.fromJson(Map<String, dynamic> json) {
    return WordBook(
      id: json['id'] ?? json['bookId'] ?? '',
      name: json['title'] ?? json['name'] ?? '',
      translationUrl: json['translationUrl'] ?? '',
      wordCount: json['wordCount'] ?? 0,
      coverUrl: json['coverUrl'] ?? json['cover_url'] ?? json['icon'],
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'translationUrl': translationUrl,
      'wordCount': wordCount,
      'coverUrl': coverUrl,
    };
  }

  /// 生成封面颜色（初音莫奈配色）
  int get coverColor {
    final hash = name.hashCode;
    final colors = [
      0xFF60B473, // 绿色调
      0xFF60B488, // 绿青色调
      0xFF60B49D, // 主要初音色
      0xFF60B4B2, // 青色调
      0xFF60A1B4, // 蓝色调
    ];
    return colors[hash.abs() % colors.length];
  }

  /// 获取封面图标颜色
  int get iconColor {
    return 0xFFFFFFFF; // 改为白色图标，更清晰
  }

  bool get isEchoType => id.startsWith('echo-type:');

  String? get echoTypeId => isEchoType ? id.substring('echo-type:'.length) : null;

  @override
  String toString() => 'WordBook(name: $name, wordCount: $wordCount)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WordBook && 
           other.name == name && 
           other.translationUrl == translationUrl;
  }
  
  @override
  int get hashCode => name.hashCode ^ translationUrl.hashCode;
}

/// 单词数据模型
/// 表示一个具体的单词及其翻译
class WordData {
  final String word;        // 英文单词
  final String translation; // 中文翻译
  final DateTime? lastLearningTime; // 上次学习时间
  final String? bookId;     // 所属词书ID
  final int? wordRank;      // 单词序号
  final Map<String, dynamic>? detailData; // 存储完整的 API 返回数据

  const WordData({
    required this.word,
    required this.translation,
    this.lastLearningTime,
    this.bookId,
    this.wordRank,
    this.detailData,
  });

  /// 从CSV行创建WordData对象
  factory WordData.fromCsvRow(List<String> row) {
    return WordData(
      word: row.isNotEmpty ? row[0].trim() : '',
      translation: row.length > 1 ? row[1].trim() : '',
    );
  }

  /// 从JSON创建WordData对象
  factory WordData.fromJson(Map<String, dynamic> json) {
    // 处理翻译字段
    String translation = '';
    if (json['translation'] != null) {
      translation = json['translation'];
    } else if (json['tranCn'] != null) {
      translation = json['tranCn'];
    } else if (json['translations'] != null && json['translations'] is List) {
      // 处理后端返回的翻译列表
      final List transList = json['translations'];
      if (transList.isNotEmpty) {
        translation = transList.map((t) {
          if (t is Map) {
            final pos = t['pos'] ?? '';
            final tran = t['tranCn'] ?? '';
            return pos.isNotEmpty ? '$pos. $tran' : tran;
          }
          return t.toString();
        }).where((s) => s.isNotEmpty).join('\n');
      }
    }

    // 处理单词序号
    int? rank;
    if (json['wordRank'] != null) {
      rank = json['wordRank'] is int ? json['wordRank'] : int.tryParse(json['wordRank'].toString());
    } else if (json['word_rank'] != null) {
      rank = json['word_rank'] is int ? json['word_rank'] : int.tryParse(json['word_rank'].toString());
    }

    return WordData(
      word: json['word'] ?? json['headWord'] ?? json['head_word'] ?? '',
      translation: translation,
      bookId: json['bookId'] ?? json['book_id'],
      wordRank: rank,
      detailData: json,
    );
  }

  @override
  String toString() => 'WordData(word: $word, translation: $translation)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WordData && 
           other.word == word && 
           other.translation == translation;
  }
  
  @override
  int get hashCode => word.hashCode ^ translation.hashCode;
} 
