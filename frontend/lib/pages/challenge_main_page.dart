import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../utils/sound_service.dart';
import '../widgets/acrylic_app_bar.dart';
import 'challenge_game_page.dart';

class ChallengeMainPage extends StatefulWidget {
  const ChallengeMainPage({super.key});

  @override
  State<ChallengeMainPage> createState() => _ChallengeMainPageState();
}

class _ChallengeMainPageState extends State<ChallengeMainPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<dynamic> _history = [];
  List<dynamic> _types = [];
  List<dynamic> _difficulties = [];
  List<dynamic> _books = [];
  
  String _selectedType = 'choose_meaning';
  String _selectedDifficulty = 'easy';
  String? _selectedBookId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        BackendApiService.getChallengeStats(),
        BackendApiService.getChallengeHistory(),
        BackendApiService.getChallengeTypes(),
        BackendApiService.getChallengeDifficulties(),
        BackendApiService.getBooks(),
        BackendApiService.getCurrentWordBook(),
      ]);

      setState(() {
        _stats = results[0] as Map<String, dynamic>?;
        _history = (results[1] as Map<String, dynamic>?)?['history'] ?? [];
        _types = (results[2] as List<Map<String, dynamic>>?) ?? [];
        _difficulties = (results[3] as List<Map<String, dynamic>>?) ?? [];
        _books = results[4] as List<Map<String, dynamic>>;
        
        final currentBook = results[5] as Map<String, dynamic>?;
        if (currentBook != null) {
          _selectedBookId = currentBook['id'].toString();
        } else if (_books.isNotEmpty) {
          _selectedBookId = _books[0]['id'].toString();
        }
        
        _isLoading = false;
      });
    } catch (e) {
      print('加载闯关数据失败: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FAF9),
      appBar: const AcrylicAppBar(
        title: '单词闯关',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsCard(),
                  const SizedBox(height: 24),
                  _buildSelectionSection(),
                  const SizedBox(height: 24),
                  _buildStartButton(),
                  const SizedBox(height: 24),
                  _buildHistorySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    if (_stats == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C897), Color(0xFF00A87E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C897).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '我的战绩',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('总场次', '${_stats!['total_challenges'] ?? 0}'),
              _buildStatItem('胜率', '${((_stats!['win_rate'] ?? 0) * 100).toStringAsFixed(0)}%'),
              _buildStatItem('最高分', '${_stats!['max_score'] ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '挑战设置',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A535C)),
        ),
        const SizedBox(height: 16),
        _buildSelectionCard(
          title: '选择教材',
          items: _books,
          selectedValue: _selectedBookId ?? '',
          onSelected: (val) => setState(() => _selectedBookId = val),
        ),
        const SizedBox(height: 16),
        _buildSelectionCard(
          title: '选择题型',
          items: _types,
          selectedValue: _selectedType,
          onSelected: (val) => setState(() => _selectedType = val),
        ),
        const SizedBox(height: 16),
        _buildSelectionCard(
          title: '选择难度',
          items: _difficulties,
          selectedValue: _selectedDifficulty,
          onSelected: (val) => setState(() => _selectedDifficulty = val),
        ),
      ],
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required List<dynamic> items,
    required String selectedValue,
    required Function(String) onSelected,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          items.isEmpty 
            ? Text('暂无可用选项', style: TextStyle(color: Colors.grey[400], fontSize: 12))
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((item) {
                  final id = item['id'].toString();
                  final isSelected = id == selectedValue;
                  return ChoiceChip(
                    label: Text(item['name'] ?? ''),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        SoundService.playTapSound();
                        onSelected(id);
                      }
                    },
                    selectedColor: const Color(0xFF00C897).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF00C897) : Colors.grey[600],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  );
                }).toList(),
              ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _selectedBookId == null ? null : _startChallenge,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C897),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: const Text(
          '开始挑战',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _startChallenge() async {
    SoundService.playTapSound();
    
    if (_selectedBookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择教材')),
      );
      return;
    }

    final result = await BackendApiService.createChallenge(
      wordBookId: _selectedBookId!,
      difficulty: _selectedDifficulty,
      questionType: _selectedType,
    );

    if (!mounted) return;

    if (result != null && result['status'] == 'success') {
      final challengeData = result['data'];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChallengeGamePage(
            challengeId: challengeData['challenge_id'],
            questions: challengeData['questions'],
          ),
        ),
      ).then((_) {
        if (mounted) _loadInitialData();
      });
    } else if (result != null && result['code'] == 403) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? '权限不足')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开启挑战失败，请稍后重试')),
      );
    }
  }

  Widget _buildHistorySection() {
    if (_history.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '挑战历史',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A535C)),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _history.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _history[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (item['score'] ?? 0) >= 60 ? Colors.green[50] : Colors.red[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      (item['score'] ?? 0) >= 60 ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                      color: (item['score'] ?? 0) >= 60 ? Colors.green : Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '得分: ${item['score']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${item['difficulty_name']} · ${item['type_name']}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item['created_at']?.substring(5, 16) ?? '',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
