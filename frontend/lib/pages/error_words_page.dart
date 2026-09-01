import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../utils/sound_service.dart';
import 'home_page.dart';

/// 错词本页面
class ErrorWordsPage extends StatefulWidget {
  const ErrorWordsPage({super.key});

  @override
  State<ErrorWordsPage> createState() => _ErrorWordsPageState();
}

class _ErrorWordsPageState extends State<ErrorWordsPage> {
  List<Map<String, dynamic>> _errorWords = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadErrorWords();
  }

  /// 加载错词
  Future<void> _loadErrorWords() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await BackendApiService.get(
        '/user/error-words',
        queryParams: {
          'page': _currentPage.toString(),
          'page_size': '20',
        },
      );
      
      if (response['code'] == 200 && mounted) {
        setState(() {
          _errorWords = List<Map<String, dynamic>>.from(response['data']['words']);
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

  /// 开始强化训练
  void _startTraining() {
    SoundService.playTapSound();
    if (_errorWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('错词本为空，继续保持！')),
      );
      return;
    }
    
    // 导航到学习模式
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // 可以传递错词列表
      ),
    );
  }

  /// 清空错词本
  void _clearErrorWords() {
    SoundService.playTapSound();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有错词记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _errorWords.clear();
                _totalCount = 0;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已清空错词本')),
              );
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('错词本'),
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_errorWords.isNotEmpty)
            IconButton(
              onPressed: _clearErrorWords,
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清空错词本',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorWords.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // 统计信息
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('错词数', _totalCount.toString(), Icons.error_outline),
                              _buildStatItem('需强化', _totalCount.toString(), Icons.fitness_center),
                              _buildStatItem('已攻克', '0', Icons.emoji_events),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _startTraining,
                            icon: const Icon(Icons.school),
                            label: const Text('开始强化训练'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red.shade400,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 错词列表
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _errorWords.length,
                        itemBuilder: (context, index) {
                          final item = _errorWords[index];
                          return _buildWordCard(item, index);
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _errorWords.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _startTraining,
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始训练'),
              backgroundColor: Colors.red.shade400,
            )
          : null,
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
    final errorCount = item['error_count'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.shade100,
          width: 2,
        ),
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
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(
              Icons.priority_high,
              color: Colors.red.shade400,
              size: 28,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              item['word'] ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '错 $errorCount 次',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
        trailing: IconButton(
          icon: Icon(Icons.volume_up, color: Colors.red.shade400),
          onPressed: () {
            SoundService.playTapSound();
            // TODO: 播放发音
          },
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
            Icons.emoji_events,
            size: 80,
            color: Colors.amber.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '太棒了！',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '目前没有错词记录',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '继续保持学习的好习惯！',
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
              backgroundColor: Colors.red.shade400,
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
