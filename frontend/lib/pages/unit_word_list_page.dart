import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home/controllers/word_learning_controller.dart';
import '../models/word_book.dart';
import 'unit_learning_page.dart';
import '../services/word_audio_service.dart';

class UnitWordListPage extends StatefulWidget {
  const UnitWordListPage({super.key});

  @override
  State<UnitWordListPage> createState() => _UnitWordListPageState();
}

class _UnitWordListPageState extends State<UnitWordListPage> with TickerProviderStateMixin {
  late TabController _tabController;
  int _coverMode = 0; // 0: 无遮盖, 1: 遮中文, 2: 遮英文

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<WordLearningController>(context, listen: false);
    // 确保有单词数据，如果没有则加载（通常应该是加载过的）
    if (controller.words.isEmpty) {
      controller.loadWordsFromSelectedWordBook().then((_) {
        _initTabController();
      });
    } else {
      _initTabController();
    }
  }

  void _initTabController() {
    final controller = Provider.of<WordLearningController>(context, listen: false);
    final unitCount = controller.unitCount > 0 ? controller.unitCount : 1;
    _tabController = TabController(length: unitCount, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WordLearningController>(
      builder: (context, controller, child) {
        if (controller.isLoading && controller.words.isEmpty) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final bookName = controller.currentBook?.name ?? '单词本';
        final unitCount = controller.unitCount > 0 ? controller.unitCount : 1;
        
        // 如果 TabController 还没初始化或长度不匹配，重新初始化
        if (!mounted) return const SizedBox();
        if (_tabController.length != unitCount) {
          _tabController.dispose();
          _tabController = TabController(length: unitCount, vsync: this, initialIndex: 0);
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFFE0F7FA), // 浅青色背景
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.black54, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              children: [
                Text(
                  '$bookName(新版本)',
                  style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: const Color(0xFFE0F7FA),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: const Color(0xFF00C897),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF00C897),
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  tabs: List.generate(unitCount, (index) => Tab(text: 'Unit ${index + 1}')),
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: List.generate(unitCount, (index) {
              return _buildUnitContent(controller, index);
            }),
          ),
          bottomNavigationBar: _buildBottomBar(controller),
        );
      },
    );
  }

  Widget _buildUnitContent(WordLearningController controller, int unitIndex) {
    final words = controller.getWordsForUnit(unitIndex);
    
    return Column(
      children: [
        // 顶部控制栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              Container(
                width: 8, 
                height: 8, 
                decoration: const BoxDecoration(color: Color(0xFFFFB74D), shape: BoxShape.circle)
              ),
              const SizedBox(width: 8),
              Text('词数: ${words.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: const [
                    Text('全部', style: TextStyle(fontSize: 12)),
                    Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
              const Spacer(),
              _buildCoverToggle(),
            ],
          ),
        ),
        
        // 单词列表
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: words.length + 1, // +1 for "No more data" text
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == words.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('没有更多数据了', style: TextStyle(color: Colors.grey))),
                );
              }
              return _buildWordItem(words[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCoverToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          _buildToggleItem('无遮盖', 0),
          _buildToggleItem('遮中文', 1),
          _buildToggleItem('遮英文', 2),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String text, int index) {
    final isSelected = _coverMode == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _coverMode = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))
          ] : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? const Color(0xFF00C897) : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildWordItem(WordData word) {
    final isCoverCn = _coverMode == 1;
    final isCoverEn = _coverMode == 2;

    // 解析翻译，通常格式为 "pos. definition"
    // 如果没有pos，就直接显示
    String pos = '';
    String def = word.translation;
    
    // 简单的解析逻辑，假设翻译中有 '.' 分隔词性
    if (def.contains('.')) {
      final parts = def.split('.');
      if (parts.length > 1) {
        pos = '${parts[0]}.';
        def = parts.sublist(1).join('.').trim();
      }
    }

    // 单词高亮部分逻辑 (模拟: 比如 hello 的 llo 高亮)
    // 这里简单处理，不高亮
    
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 英文部分
          Expanded(
            flex: 4,
            child: isCoverEn
                ? Container(
                    height: 24,
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                  )
                : GestureDetector(
                    onTap: () {
                      WordAudioService.playWordPronunciation(word.word);
                    },
                    child: Text(
                      word.word,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          // 中文部分
          Expanded(
            flex: 6,
            child: isCoverCn
                ? Container(
                    height: 24, 
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))
                  )
                : RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                      children: [
                        if (pos.isNotEmpty)
                          TextSpan(text: '$pos ', style: const TextStyle(color: Colors.grey)),
                        TextSpan(text: def),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(WordLearningController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.assignment_outlined, color: Colors.blue, size: 24),
              ),
              const SizedBox(height: 4),
              const Text('专项练习', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  // 开始学习当前单元
                  controller.setLearningUnit(_tabController.index);
                  
                  // 跳转到单元学习页
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UnitLearningPage()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C897),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text('开始学习', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
