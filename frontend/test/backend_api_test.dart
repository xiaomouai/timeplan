import 'package:flutter_test/flutter_test.dart';
import 'package:xueba_dict/services/backend_api_service.dart';

void main() {
  group('Backend API Service Tests', () {
    test('健康检查', () async {
      final isHealthy = await BackendApiService.healthCheck();
      expect(isHealthy, isTrue);
    });

    test('获取分类列表', () async {
      final categories = await BackendApiService.getCategories();
      
      expect(categories, isNotEmpty);
      expect(categories.first, '全部');
      print('✅ 获取到 ${categories.length} 个分类');
      print('分类列表: $categories');
    });

    test('获取词书列表', () async {
      final books = await BackendApiService.getBooks();
      
      expect(books, isNotEmpty);
      expect(books.first, containsPair('id', isNotNull));
      expect(books.first, containsPair('title', isNotNull));
      print('✅ 获取到 ${books.length} 本词书');
    });

    test('按分类筛选词书', () async {
      final books = await BackendApiService.getBooks(category: '四级');
      
      expect(books, isNotEmpty);
      for (var book in books) {
        expect(book['category'], '四级');
      }
      print('✅ 四级词书: ${books.length} 本');
    });

    test('获取词书详情', () async {
      final bookDetail = await BackendApiService.getBookDetail('CET4luan_1');
      
      expect(bookDetail['id'], 'CET4luan_1');
      expect(bookDetail['title'], isNotNull);
      expect(bookDetail['wordCount'], greaterThan(0));
      print('✅ 词书详情: ${bookDetail['title']} (${bookDetail['wordCount']} 词)');
    });

    test('获取单词列表', () async {
      final wordsData = await BackendApiService.getWords('CET4luan_1', page: 1, pageSize: 10);
      
      expect(wordsData['words'], isNotEmpty);
      expect(wordsData['total'], greaterThan(0));
      expect(wordsData['page'], 1);
      expect(wordsData['page_size'], 10);
      print('✅ 单词列表: ${wordsData['words'].length} 个单词');
    });

    test('获取单词详情', () async {
      final wordDetail = await BackendApiService.getWordDetail('CET4luan_1', 1);
      
      expect(wordDetail['word'], isNotNull);
      expect(wordDetail['usphone'], isNotNull);
      expect(wordDetail['translations'], isNotEmpty);
      print('✅ 单词详情: ${wordDetail['word']} [${wordDetail['usphone']}]');
    });

    test('搜索单词', () async {
      final searchResult = await BackendApiService.searchWords('test');
      
      expect(searchResult['results'], isNotNull);
      expect(searchResult['keyword'], 'test');
      print('✅ 搜索结果: ${searchResult['total']} 个');
    });

    test('获取发音URL', () async {
      final ukUrl = await BackendApiService.getPronunciationUrl('hello', type: '1');
      final usUrl = await BackendApiService.getPronunciationUrl('hello', type: '2');
      
      expect(ukUrl, contains('dict.youdao.com'));
      expect(usUrl, contains('dict.youdao.com'));
      print('✅ 英音URL: $ukUrl');
      print('✅ 美音URL: $usUrl');
    });
  });
}
