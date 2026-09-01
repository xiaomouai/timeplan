import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../utils/sound_service.dart';
import 'home_page.dart';

/// 收藏本页面（生词本）
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  /// 加载收藏单词
  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await BackendApiService.get(
        '/user/favorites',
        queryParams: {
          'page': _currentPage.toString(),
          'page_size': '20',
        },
      );
      
      if (response['code'] == 200 && mounted) {
        setState(() {
          _favorites = List<Map<String, dynamic>>.from(response['data']['words']);
          _totalCount = response['data']['total'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加载失败，请稍后重试')),
        );
      }
    }
  }

  /// 取消收藏
  Future<void> _removeFromFavorites(String bookId, int wordRank, int index) async {
    try {
      final success = await BackendApiService.removeFromFavorites(
        bookId: bookId,
        wordRank: wordRank,
      );
      
      if (success && mounted) {
        setState(() {
          _favorites.removeAt(index);
          _totalCount--;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已从生词本移除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败，请重试')),
        );
      }
    }
  }

  /// 开始学习
  void _startLearning() {
    SoundService.playTapSound();
    if (_favorites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生词本为空，快去收藏单词吧！')),
      );
      return;
    }
    
    // 导航到学习模式
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // 可以传递收藏单词列表
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('生词本'),
        backgroundColor: const Color(0xFF00C897),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_favorites.isNotEmpty)
            TextButton.icon(
              onPressed: _startLearning,
              icon: const Icon(Icons.play_circle_outline, color: Colors.white),
              label: const Text('开始学习', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // 统计信息
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C897),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('总词数', _totalCount.toString(), Icons.book),
                          _buildStatItem('今日学习', '0', Icons.today),
                          _buildStatItem('已掌握', '0', Icons.check_circle),
                        ],
                      ),
                    ),
                    
                    // 单词列表
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _favorites.length,
                        itemBuilder: (context, index) {
                          final item = _favorites[index];
                          return _buildWordCard(item, index);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  /// 统计项
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// 单词卡片
  Widget _buildWordCard(Map<String, dynamic> item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF00C897).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Color(0xFF00C897),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          item['word'] ?? '',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            item['translation'] ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.volume_up, color: Color(0xFF00C897)),
              onPressed: () {
                SoundService.playTapSound();
                // TODO: 播放发音
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              onPressed: () {
                SoundService.playTapSound();
                _removeFromFavorites(
                  item['book_id'] ?? '',
                  item['word_rank'] ?? 0,
                  index,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '生词本为空',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '学习时收藏的单词会显示在这里',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              SoundService.playTapSound();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回学习'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C897),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
