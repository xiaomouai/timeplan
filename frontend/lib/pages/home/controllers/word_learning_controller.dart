import 'package:flutter/material.dart';
import 'dart:math';
import '../../../models/word_book.dart';
import '../../../models/word_learning_record.dart';
import '../../../models/syllable_info.dart';
import '../../../utils/english_word_api_service.dart';
import '../../../utils/learning_data_service.dart';
import '../../../utils/algorithm_manager.dart';
import '../../../utils/cache_service.dart';
import '../../../services/word_audio_service.dart';
import '../../../services/backend_api_service.dart';

/// 单词学习控制器，管理单词加载、进度、动画状态等
class WordLearningController extends ChangeNotifier {
  List<WordData> _words = [];
  bool _isLoading = false;
  String? _errorMessage;
  WordDetailResponse? _currentWord;
  SyllableInfo? _currentSyllables;
  int _todayStudiedCount = 0;
  bool _showMeaning = false;
  bool _wordAnimationCompleted = false;
  String? _selectedBookName;
  WordBook? _currentBook;
  int _masteredCount = 0;
  int _studiedCount = 0;
  bool _isCurrentFavorited = false;
  bool _isCurrentMastered = false;
  
  // Unit support
  static const int WORDS_PER_UNIT = 20;
  int? _currentUnitIndex;
  List<WordData> _learningQueue = [];
  int _currentIndex = 0;

  // Getters
  List<WordData> get words => _words;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  WordDetailResponse? get currentWord => _currentWord;
  SyllableInfo? get currentSyllables => _currentSyllables;
  int get todayStudiedCount => _todayStudiedCount;
  bool get showMeaning => _showMeaning;
  bool get wordAnimationCompleted => _wordAnimationCompleted;
  String? get selectedBookName => _selectedBookName;
  WordBook? get currentBook => _currentBook;
  int get masteredCount => _masteredCount;
  int get studiedCount => _studiedCount;
  int? get currentUnitIndex => _currentUnitIndex;
  List<WordData> get learningQueue => _learningQueue;
  int get currentIndex => _currentIndex;
  bool get isCurrentFavorited => _isCurrentFavorited;
  bool get isCurrentMastered => _isCurrentMastered;

  int get unitCount => (_words.isEmpty) ? 0 : (_words.length / WORDS_PER_UNIT).ceil();

  final Random _random = Random();

  /// 获取指定单元的单词列表
  List<WordData> getWordsForUnit(int unitIndex) {
    if (unitIndex < 0 || unitIndex >= unitCount) return [];
    final start = unitIndex * WORDS_PER_UNIT;
    final end = min(start + WORDS_PER_UNIT, _words.length);
    return _words.sublist(start, end);
  }

  /// 设置学习范围（按单元）
  void setLearningUnit(int unitIndex) {
    _currentUnitIndex = unitIndex;
    _learningQueue = getWordsForUnit(unitIndex);
    _currentIndex = 0; // 重置索引
    _loadWordAtIndex(_currentIndex); // 从第一个单词开始
  }

  /// 加载指定索引的单词
  Future<void> _loadWordAtIndex(int index) async {
    if (_learningQueue.isEmpty || index < 0 || index >= _learningQueue.length) return;
    
    _currentIndex = index;
    final wordData = _learningQueue[index];
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _resolveWordDetail(wordData);
      if (response != null) {
        _currentWord = response;
        _showMeaning = false;
        _wordAnimationCompleted = false;
        
        // 异步获取音节信息
        _currentSyllables = wordData.bookId?.startsWith('echo-type:') == true
            ? null
            : await BackendApiService.getSyllables(wordData.word);
        await _loadWordStatus(wordData);
      }
    } catch (e) {
      debugPrint('获取单词详情失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 上一个单词
  void previousWord() {
    if (_currentIndex > 0) {
      _loadWordAtIndex(_currentIndex - 1);
    }
  }

  /// 下一个单词
  void nextWord() {
    if (_currentIndex < _learningQueue.length - 1) {
      _loadWordAtIndex(_currentIndex + 1);
    }
  }

  /// 跳转到指定单词
  void jumpToWord(int index) {
    _loadWordAtIndex(index);
  }

  /// 加载选中词库的单词
  Future<void> loadWordsFromSelectedWordBook() async {
    _isLoading = true;
    _errorMessage = null;
    _currentUnitIndex = null; // 重置单元选择
    _learningQueue = [];
    notifyListeners();

    try {
      // 从 CacheService 获取选中的词库名称
      final selectedBookName = await CacheService.getSelectedWordBook();
      _selectedBookName = selectedBookName;
      
      if (selectedBookName != null) {
        // 获取词库详细信息
        final books = await CacheService.getCachedWordBooks();
        try {
          _currentBook = books.firstWhere((b) => b.name == selectedBookName);
        } catch (_) {
          // 如果找不到对应的书，可能被删除了，但名字还在缓存
          _currentBook = null;
        }

        // 加载学习统计
        await _loadLearningStats(selectedBookName);

        // 从 CacheService 获取缓存的单词数据
        final words = await CacheService.getCachedWordData(selectedBookName);
        if (words != null && words.isNotEmpty) {
          _words = words;
          _learningQueue = List.from(_words); // 默认全部单词
          if (_words.isNotEmpty) {
            await _loadNextRandomWord();
          }
        } else {
          _errorMessage = '词库中暂无单词，请先在书库下载';
        }
      } else {
        _errorMessage = '请先选择词库';
      }
    } catch (e) {
      _errorMessage = '加载单词失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载学习统计数据
  Future<void> _loadLearningStats(String bookName) async {
    try {
      final stats = await LearningDataService.instance.getLearningStats(bookName);
      _studiedCount = stats.totalWords; // 已学习的总数（有记录的单词数）
      _masteredCount = stats.levelStats[MemoryLevel.mastered] ?? 0;
    } catch (e) {
      debugPrint('加载学习统计失败: $e');
    }
  }

  /// 随机加载下一个单词
  Future<void> _loadNextRandomWord() async {
    if (_learningQueue.isEmpty) return;
    
    final randomIndex = _random.nextInt(_learningQueue.length);
    final wordData = _learningQueue[randomIndex];
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _resolveWordDetail(wordData);
      if (response != null) {
        _currentWord = response;
        _showMeaning = false;
        _wordAnimationCompleted = false;
        
        // 异步获取音节信息
        _currentSyllables = wordData.bookId?.startsWith('echo-type:') == true
            ? null
            : await BackendApiService.getSyllables(wordData.word);
        await _loadWordStatus(wordData);
      }
    } catch (e) {
      debugPrint('获取单词详情失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<WordDetailResponse?> _resolveWordDetail(WordData wordData) async {
    final localDetail = _buildEchoTypeWordDetail(wordData);
    if (localDetail != null) return localDetail;
    return EnglishWordApiService.getWordDetails(wordData.word);
  }

  WordDetailResponse? _buildEchoTypeWordDetail(WordData wordData) {
    if (wordData.bookId?.startsWith('echo-type:') != true) return null;
    final sentence = wordData.detailData?['sentence'];
    if (sentence is! String || sentence.trim().isEmpty) return null;

    final hasChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(sentence);
    final encodedWord = Uri.encodeComponent(wordData.word);
    return WordDetailResponse(
      word: wordData.word,
      ukPhone: '',
      usPhone: '',
      ukSpeech: 'https://dict.youdao.com/dictvoice?audio=$encodedWord&type=1',
      usSpeech: 'https://dict.youdao.com/dictvoice?audio=$encodedWord&type=2',
      translations: wordData.translation.isEmpty
          ? const []
          : [WordTranslation(pos: '', tranCn: wordData.translation)],
      sentences: hasChinese
          ? const []
          : [WordSentence(sContent: sentence, sCn: '')],
      phrases: const [],
      bookId: wordData.bookId!,
      wordRank: wordData.wordRank ?? 0,
    );
  }

  void toggleMeaning() {
    _showMeaning = !_showMeaning;
    notifyListeners();
  }

  void setWordAnimationCompleted(bool completed) {
    _wordAnimationCompleted = completed;
    notifyListeners();
  }

  /// 掌握当前单词（随机到下一词）
  Future<void> markAsMastered() async {
    await _markAsMasteredInternal(autoNextRandom: true);
  }

  /// 掌握当前单词（停留在当前词）
  Future<void> markAsMasteredAndStay() async {
    await _markAsMasteredInternal(autoNextRandom: false);
  }

  Future<void> _markAsMasteredInternal({required bool autoNextRandom}) async {
    if (_currentWord == null) return;
    
    try {
      final record = WordLearningRecord.firstTime(
        word: _currentWord!.word,
        translation: _currentWord!.translations.isNotEmpty 
            ? _currentWord!.translations.first.tranCn 
            : '',
      );
      await LearningDataService.instance.saveWordLearningRecord(record);

      WordData? wordData;
      if (_learningQueue.isNotEmpty && _currentIndex >= 0 && _currentIndex < _learningQueue.length) {
        wordData = _learningQueue[_currentIndex];
      }

      if (wordData != null && wordData.bookId != null && wordData.wordRank != null) {
        try {
          final success = await BackendApiService.markAsMastered(
            bookId: wordData.bookId!,
            wordRank: wordData.wordRank!,
            word: wordData.word,
          );
          if (success) {
            _isCurrentMastered = true;
          }
        } catch (e) {
          debugPrint('标记掌握失败: $e');
        }
      }

      _todayStudiedCount++;
      if (autoNextRandom) {
        await _loadNextRandomWord();
      } else {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('保存学习记录失败: $e');
    }
  }

  /// 收藏当前单词
  Future<void> toggleFavorite() async {
    if (_currentWord == null) return;
    if (_learningQueue.isEmpty || _currentIndex < 0 || _currentIndex >= _learningQueue.length) {
      return;
    }

    final wordData = _learningQueue[_currentIndex];
    if (wordData.bookId == null || wordData.wordRank == null) {
      return;
    }

    try {
      if (_isCurrentFavorited) {
        final success = await BackendApiService.removeFromFavorites(
          bookId: wordData.bookId!,
          wordRank: wordData.wordRank!,
        );
        if (success) {
          _isCurrentFavorited = false;
        }
      } else {
        final success = await BackendApiService.addToFavorites(
          bookId: wordData.bookId!,
          wordRank: wordData.wordRank!,
          word: wordData.word,
        );
        if (success) {
          _isCurrentFavorited = true;
        }
      }
    } catch (e) {
      debugPrint('收藏操作失败: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> _loadWordStatus(WordData wordData) async {
    if (wordData.bookId == null || wordData.wordRank == null) {
      _isCurrentFavorited = false;
      _isCurrentMastered = false;
      return;
    }

    final status = await BackendApiService.getWordStatus(
      bookId: wordData.bookId!,
      wordRank: wordData.wordRank!,
    );
    _isCurrentFavorited = status['is_favorited'] ?? false;
    _isCurrentMastered = status['is_mastered'] ?? false;
  }
}
