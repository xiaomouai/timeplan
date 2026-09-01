import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word_book.dart';
import 'performance_optimizer.dart';

/// 缓存服务
/// 负责管理词库数据的本地缓存
class CacheService {
  static const String _wordBooksKey = 'cached_word_books';
  static const String _wordDataPrefix = 'word_data_';
  static const String _downloadStatusPrefix = 'download_status_';
  static const String _selectedWordBookKey = 'selected_word_book';
  static const String _selectedWordBookIdKey = 'selected_word_book_id';
  
  /// 缓存词库列表 - 同时更新内存缓存
  static Future<void> cacheWordBooks(List<WordBook> wordBooks) async {
    final prefs = await SharedPreferences.getInstance();
    final wordBooksJson = wordBooks.map((book) => book.toJson()).toList();
    await prefs.setString(_wordBooksKey, jsonEncode(wordBooksJson));
    
    // 同时更新内存缓存
    MemoryCache.set(_wordBooksKey, wordBooks);
  }
  
  /// 获取缓存的词库列表 - 优化内存缓存
  static Future<List<WordBook>> getCachedWordBooks() async {
    // 先检查内存缓存
    final cachedList = MemoryCache.get<List<WordBook>>(_wordBooksKey);
    if (cachedList != null) {
      return cachedList;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final wordBooksString = prefs.getString(_wordBooksKey);
    if (wordBooksString != null) {
        final wordBooksJson = jsonDecode(wordBooksString) as List;
        final wordBooks = wordBooksJson.map((json) => WordBook.fromJson(json)).toList();
        
        // 存入内存缓存
        MemoryCache.set(_wordBooksKey, wordBooks);
        return wordBooks;
    }
    return [];
  }
  
  /// 缓存单词数据
  static Future<void> cacheWordData(String wordBookName, List<WordData> wordData) async {
    final prefs = await SharedPreferences.getInstance();
    // 使用稳定的名称作为键，避免 hashCode 不稳定
    final key = _wordDataPrefix + wordBookName.trim();
    final wordDataJson = wordData.map((word) => {
      'word': word.word,
      'translation': word.translation,
      'bookId': word.bookId,
      'wordRank': word.wordRank,
      'detailData': word.detailData,
    }).toList();
    await prefs.setString(key, jsonEncode(wordDataJson));
    
    // 同时缓存下载状态
    await prefs.setString(_downloadStatusPrefix + wordBookName.trim(), 'downloaded');
  }
  
  /// 获取缓存的单词数据
  static Future<List<WordData>?> getCachedWordData(String wordBookName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _wordDataPrefix + wordBookName.trim();
    
    // 尝试直接使用名称获取
    String? wordDataString = prefs.getString(key);
    
    // 兼容逻辑：如果找不到，尝试使用旧的 hashCode 方式
    if (wordDataString == null) {
      final oldKey = _wordDataPrefix + wordBookName.hashCode.toString();
      wordDataString = prefs.getString(oldKey);
    }

    if (wordDataString != null) {
        final wordDataJson = jsonDecode(wordDataString) as List;
        return wordDataJson.map((json) => WordData(
          word: json['word'],
          translation: json['translation'],
          bookId: json['bookId'],
          wordRank: json['wordRank'],
          detailData: json['detailData'] is Map
              ? Map<String, dynamic>.from(json['detailData'])
              : null,
        )).toList();
    }
    return null;
  }
  
  /// 检查词库是否已下载
  static Future<bool> isWordBookDownloaded(String wordBookName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _downloadStatusPrefix + wordBookName.trim();
    
    if (prefs.getString(key) == 'downloaded') return true;
    
    // 兼容逻辑
    final oldKey = _downloadStatusPrefix + wordBookName.hashCode.toString();
    return prefs.getString(oldKey) == 'downloaded';
  }
  
  /// 保存选中的词库
  static Future<void> saveSelectedWordBook(String wordBookName, [String? wordBookId]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedWordBookKey, wordBookName);
    if (wordBookId != null) {
      await prefs.setString(_selectedWordBookIdKey, wordBookId);
    }
  }
  
  /// 获取选中的词库名称
  static Future<String?> getSelectedWordBook() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedWordBookKey);
  }

  /// 获取选中的词库ID
  static Future<String?> getSelectedWordBookId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedWordBookIdKey);
  }
  

}
