import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../controllers/home_controller.dart';
import '../controllers/word_learning_controller.dart';
import '../widgets/home_top_bar.dart';
import '../../../utils/sound_service.dart';
import '../../../services/word_audio_service.dart';
import '../../favorites_page.dart';
import '../../error_words_page.dart';
import '../../checkin_page.dart';
import '../../challenge_main_page.dart';
import '../../phonetics_practice_page.dart';
import '../../learning_report_page.dart';
import '../../unit_word_list_page.dart';

/// 首页“单词”标签页
/// 负责展示当前学习进度、单词卡片以及核心功能入口
class WordTab extends StatefulWidget {
  const WordTab({super.key});

  @override
  State<WordTab> createState() => _WordTabState();
}

class _WordTabState extends State<WordTab> {
  @override
  Widget build(BuildContext context) {
    // 监听多个控制器的状态
    return Consumer2<HomeController, WordLearningController>(
      builder: (context, homeController, wordController, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 顶部用户信息和操作栏
                  const SizedBox(height: 12),
                  HomeTopBar(
                    userName: homeController.userName,
                    userAvatar: homeController.userAvatar,
                    onProfileTap: () => Navigator.pushNamed(context, '/profile'),
                  ),
                  const SizedBox(height: 20),
                  
                  // 2. 学习进度卡片
                  _buildProgressCard(wordController),
                  const SizedBox(height: 24),
                  
                  // 3. 核心单词卡片 (如果正在加载显示加载中)
                  if (wordController.isLoading)
                    const Center(child: CircularProgressIndicator())
                  // else if (wordController.currentWord != null)
                  //   _buildCurrentWordCard(wordController)
                  else
                    _buildEmptyState(wordController),
                    
                  const SizedBox(height: 24),
                  
                  // 4. 功能网格入口
                  _buildFunctionGrid(wordController),
                  const SizedBox(height: 100), // 为底部导航和红包条留出空间
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建学习进度卡片
  Widget _buildProgressCard(WordLearningController controller) {
    final book = controller.currentBook;
    final bookName = book?.name ?? '请选择教材';
    final totalWords = book?.wordCount ?? 0;
    final studiedCount = controller.studiedCount;
    final masteredCount = controller.masteredCount;
    
    // 计算进度 (防止除以零)
    final double progress = totalWords > 0 ? studiedCount / totalWords : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C897).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 顶部：标题和按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A535C),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '人教PEP版', // TODO: 从书名解析或存储版本信息
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildPillButton('切换教材', Icons.import_contacts, const Color(0xFFFFB74D), () async {
                    await Navigator.pushNamed(context, '/library');
                    controller.loadWordsFromSelectedWordBook();
                  }),
                  const SizedBox(height: 8),
                  _buildPillButton('学习记录 >', null, const Color(0xFF00C897), () {
                    if (controller.selectedBookName != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => LearningReportPage(wordBookName: controller.selectedBookName!)));
                    }
                  }),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // 中间：封面和进度圆环
          SizedBox(
            height: 220,
            width: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 进度圆环
                CustomPaint(
                  size: const Size(260, 220),
                  painter: ProgressArcPainter(
                    progress: progress,
                    backgroundColor: const Color(0xFFF0F0F0),
                    color: const Color(0xFF00C897),
                  ),
                ),
                // 书本封面
                Container(
                  width: 110,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: book?.coverUrl != null
                      ? Image.network(
                          book!.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Color(book?.coverColor ?? 0xFF00C897),
                            child: const Icon(Icons.menu_book, color: Colors.white, size: 40),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF00C897),
                          child: const Icon(Icons.menu_book, color: Colors.white, size: 40),
                        ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 底部统计
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('$studiedCount 词', '已学习', const Color(0xFFFFB74D)),
              _buildStatItem('$masteredCount 词', '已掌握', const Color(0xFF00C897)),
              _buildStatItem('$totalWords 词', '总词数', Colors.grey),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: _buildLargeActionButton(
                  '单元学习', 
                  const Color(0xFF00C897), 
                  Colors.white, 
                  () async {
                    if (controller.words.isEmpty) {
                      await controller.loadWordsFromSelectedWordBook();
                    }
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const UnitWordListPage()));
                  }
                )
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildLargeActionButton(
                  '单元复习', 
                  Colors.white, 
                  const Color(0xFF00C897), 
                  () {
                    // 跳转到错题集作为复习入口
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ErrorWordsPage()));
                  },
                  isOutlined: true
                )
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton(String text, IconData? icon, Color bgColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        SoundService.playTapSound();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              text, 
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color dotColor) {
     return Column(
       children: [
         Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A))),
         const SizedBox(height: 4),
         Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
             const SizedBox(width: 4),
             Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
           ],
         ),
       ],
     );
  }

  Widget _buildLargeActionButton(String text, Color bgColor, Color textColor, VoidCallback onTap, {bool isOutlined = false}) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: () {
          SoundService.playTapSound();
          onTap();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: isOutlined ? 0 : 4,
          shadowColor: isOutlined ? null : bgColor.withOpacity(0.4),
          side: isOutlined ? BorderSide(color: textColor, width: 1.5) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  /// 构建当前学习的单词卡片
  Widget _buildCurrentWordCard(WordLearningController controller) {
    final word = controller.currentWord!;
    return GestureDetector(
      onTap: () {
        SoundService.playTapSound();
        controller.toggleMeaning();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              word.word,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF1A535C), letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(word.usPhone.isNotEmpty ? '[${word.usPhone}]' : '', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF00C897)),
                  onPressed: () => WordAudioService.playWordPronunciation(word.word),
                ),
              ],
            ),
            
            // 音节拆解展示
            if (controller.currentSyllables != null)
              _buildSyllableBreakdown(controller),
              
            if (controller.showMeaning) ...[
              const Divider(height: 32),
              Column(
                children: word.translations.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 18, color: Color(0xFF1A535C)),
                      children: [
                        TextSpan(
                          text: '${t.pos}. ',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                        ),
                        TextSpan(text: t.tranCn),
                      ],
                    ),
                  ),
                )).toList(),
              ),
              if (word.sentences.isNotEmpty) ...[
                 const SizedBox(height: 12),
                 Text(
                   word.sentences.first.sContent,
                   style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                   textAlign: TextAlign.center,
                 ),
                 Text(
                   word.sentences.first.sCn,
                   style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                   textAlign: TextAlign.center,
                 ),
               ],
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton('认识', const Color(0xFFE8F5E9), const Color(0xFF2E7D32), () {
                  controller.markAsMastered();
                }),
                _buildActionButton('不认识', const Color(0xFFFBE9E7), const Color(0xFFD84315), () {
                  controller.toggleMeaning();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建音节拆解展示
  Widget _buildSyllableBreakdown(WordLearningController controller) {
    final syllableInfo = controller.currentSyllables!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Text(
            '音节拆解 (点击播放)',
            style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: syllableInfo.syllables.map((syllable) {
              return GestureDetector(
                onTap: () {
                  SoundService.playTapSound();
                  // 播放单个音节的发音
                  WordAudioService.playWordPronunciation(syllable.text);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        syllable.text,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                      if (syllable.phoneme.isNotEmpty)
                        Text(
                          syllable.phoneme,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(WordLearningController controller) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.library_books_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(controller.errorMessage ?? '暂无学习任务', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => controller.loadWordsFromSelectedWordBook(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionButton(String label, Color bgColor, Color textColor, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: () {
        SoundService.playTapSound();
        onTap();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFunctionGrid(WordLearningController controller) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 20,
      crossAxisSpacing: 10,
      children: [
        _buildFunctionItem(Icons.menu_book_rounded, '教材词库', const Color(0xFFE3F2FD), Colors.blue, () async {
          await Navigator.pushNamed(context, '/library');
          controller.loadWordsFromSelectedWordBook();
        }),
        _buildFunctionItem(Icons.history_rounded, '错题集', const Color(0xFFFBE9E7), Colors.deepOrange, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ErrorWordsPage()));
        }),
        _buildFunctionItem(Icons.star_outline_rounded, '生词本', const Color(0xFFFFF8E1), Colors.amber, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesPage()));
        }),
        _buildFunctionItem(Icons.graphic_eq_rounded, '语音测评', const Color(0xFFF3E5F5), Colors.purple, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const PhoneticsPracticePage()));
        }),
        _buildFunctionItem(Icons.games_outlined, '趣味练习', const Color(0xFFE8F5E9), Colors.green, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ChallengeMainPage()));
        }),
        _buildFunctionItem(Icons.leaderboard_outlined, '排行榜', const Color(0xFFEFEBE9), Colors.brown, () {
          if (controller.selectedBookName != null) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => LearningReportPage(wordBookName: controller.selectedBookName!)));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请先选择词库以查看排行榜')),
            );
          }
        }),
        _buildFunctionItem(Icons.card_giftcard_rounded, '打卡领奖', const Color(0xFFFFF3E0), Colors.orange, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CheckinPage()));
        }),
        _buildFunctionItem(Icons.more_horiz_rounded, '更多', const Color(0xFFECEFF1), Colors.blueGrey, () {
          // TODO: 更多功能
        }),
      ],
    );
  }

  Widget _buildFunctionItem(IconData icon, String label, Color bgColor, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        SoundService.playTapSound();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF4A4A4A)),
          ),
        ],
      ),
    );
  }
}

class ProgressArcPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color color;

  ProgressArcPainter({
    required this.progress,
    required this.backgroundColor,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // 留出足够的半径空间，避免被裁剪
    final radius = math.min(size.width, size.height) / 2 - 15;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    // 绘制背景圆弧
    // 从135度(左下)开始，绘制270度，到45度(右下)，底部留空90度
    const startAngle = 3 * math.pi / 4; // 135度
    const sweepAngle = 3 * math.pi / 2; // 270度
    
    paint.color = backgroundColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
    
    // 绘制进度圆弧
    paint.color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ProgressArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.backgroundColor != backgroundColor ||
           oldDelegate.color != color;
  }
}
