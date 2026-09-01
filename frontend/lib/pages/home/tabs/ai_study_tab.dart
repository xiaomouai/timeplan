import 'package:flutter/material.dart';
import '../../../utils/sound_service.dart';
import '../../../utils/responsive_helper.dart';
import '../../ai_chat_page.dart';
import '../../chinese_to_english_page.dart';
import '../../phonetics_practice_page.dart';

/// 首页“AI智学”标签页
/// 提供AI对话、智能练习等进阶学习功能
class AIStudyTab extends StatelessWidget {
  const AIStudyTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = (double size) => ResponsiveHelper.s(context, size);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FEFD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: s(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: s(15)),
              // 顶部标题
              _buildHeader(context),
              SizedBox(height: s(15)),
              
              // 顶部 Banner (Luna 老师)
              _buildHeroBanner(context),
              
              SizedBox(height: s(25)),
              
              // AI 智学助手标题
              Row(
                children: [
                  Text(
                    '📖 ',
                    style: TextStyle(fontSize: s(20)),
                  ),
                  Text(
                    'AI智学助手',
                    style: TextStyle(
                      fontSize: s(18), 
                      fontWeight: FontWeight.bold, 
                      color: const Color(0xFF333333),
                    ),
                  ),
                ],
              ),
              SizedBox(height: s(15)),
              
              // 工具矩阵网格
              _buildToolGrid(context),
              
              SizedBox(height: s(30)),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部标题
  Widget _buildHeader(BuildContext context) {
    final s = (double size) => ResponsiveHelper.s(context, size);
    return Text(
      'AI零基础自由聊',
      style: TextStyle(
        fontSize: s(22),
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        foreground: Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
          ).createShader(Rect.fromLTWH(0.0, 0.0, s(200), s(70))),
      ),
    );
  }

  /// 顶部 Banner
  Widget _buildHeroBanner(BuildContext context) {
    final s = (double size) => ResponsiveHelper.s(context, size);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(s(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: s(15),
            offset: Offset(0, s(5)),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 背景渐变
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: s(150),
              height: s(150),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE0F7FA).withOpacity(0.8),
                    Colors.white.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          
          Padding(
            padding: EdgeInsets.all(s(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: s(10)),
                Text(
                  'hi，你好呀！',
                  style: TextStyle(
                    fontSize: s(24),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
                SizedBox(height: s(8)),
                SizedBox(
                  width: s(isDesktop ? 400 : (isTablet ? 300 : 200)),
                  child: Text(
                    '我是英语老师 Luna，比较擅长中英双语交流对话，快来跟我交流试试吧～',
                    style: TextStyle(
                      fontSize: s(14),
                      color: const Color(0xFF666666),
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: s(20)),
                
                // DeepSeek 入口卡片
                Container(
                  padding: EdgeInsets.symmetric(horizontal: s(12), vertical: s(10)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(s(16)),
                    border: Border.all(color: const Color(0xFFF0F0F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: s(40),
                        height: s(40),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.waves, color: const Color(0xFF2E7D32), size: s(24)),
                      ),
                      SizedBox(width: s(10)),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'DeepSeek AI畅聊',
                              style: TextStyle(
                                fontSize: s(15),
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF333333),
                              ),
                            ),
                            Text(
                              '口语学习，非常简单...',
                              style: TextStyle(
                                fontSize: s(11),
                                color: const Color(0xFF999999),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: s(8)),
                      ElevatedButton(
                        onPressed: () => _navigateToChat(context, 'DeepSeek AI畅聊', '你是一个全能的英语助手 Luna，擅长中英双语交流。'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D191),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(horizontal: s(15), vertical: 0),
                          minimumSize: Size(s(80), s(32)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(s(20)),
                          ),
                        ),
                        child: Text('开始对话', style: TextStyle(fontSize: s(13), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Luna 老师角色图 (右侧)
          Positioned(
            right: s(-10),
            top: s(-20),
            child: IgnorePointer(
              child: SizedBox(
                width: s(isDesktop ? 220 : (isTablet ? 180 : 140)),
                height: s(isDesktop ? 260 : (isTablet ? 220 : 180)),
                child: Image.network(
                  'https://api.iconify.design/noto:woman-teacher-light-skin-tone.svg',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.face_retouching_natural, size: s(100), color: Colors.teal),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 工具网格
  Widget _buildToolGrid(BuildContext context) {
    final s = (double size) => ResponsiveHelper.s(context, size);
    final columns = ResponsiveHelper.getResponsiveGridColumns(context) + 1; // 基础 2 列，平板/电脑更多
    
    final List<Map<String, dynamic>> tools = [
      {
        'title': '中文想法→英文',
        'subtitle': '先懂中文 再练英文',
        'icon': Icons.translate_rounded,
        'color': Colors.teal,
        'knowledge': true,
      },
      {
        'title': '百科问答',
        'subtitle': '回答你任何问题',
        'icon': Icons.menu_book_rounded,
        'color': Colors.blue,
        'prompt': '你是一个百科知识助手，请用简单易懂的英语回答学生的问题。',
      },
      {
        'title': '口语对练',
        'subtitle': '超实用英语外教',
        'icon': Icons.record_voice_over_rounded,
        'color': Colors.orange,
        'prompt': '你是一个英语外教，请与学生进行模拟口语练习。',
      },
      {
        'title': '语法讲解',
        'subtitle': '语法问题全搞定',
        'icon': Icons.architecture_rounded,
        'color': Colors.green,
        'prompt': '你是一个英语语法专家，请帮助学生分析并讲解语法难点。',
      },
      {
        'title': 'Ai写作',
        'subtitle': '英语作文不发愁',
        'icon': Icons.edit_note_rounded,
        'color': Colors.pink,
        'prompt': '你是一个英语写作老师，请指导学生进行作文创作并给予反馈。',
      },
      {
        'title': 'AI翻译',
        'subtitle': '你说汉语 我说英语',
        'icon': Icons.translate_rounded,
        'color': Colors.red,
        'prompt': '你是一个专业的同声传译助手，请帮助学生进行中英互译。',
      },
      {
        'title': '十万个为什么',
        'subtitle': '对世界有何疑问？',
        'icon': Icons.lightbulb_rounded,
        'color': Colors.amber,
        'prompt': '你是一个充满好奇心的科普专家，请用简单的语言解释科学奥秘。',
      },
      {
        'title': '学习规划',
        'subtitle': '让你学习更轻松',
        'icon': Icons.calendar_month_rounded,
        'color': Colors.teal,
        'prompt': '你是一个学习规划师，请根据学生的情况制定科学的英语学习计划。',
      },
      {
        'title': '词汇拓展',
        'subtitle': '词汇量大爆炸',
        'icon': Icons.style_rounded,
        'color': Colors.indigo,
        'prompt': '你是一个词汇专家，请帮助学生学习新单词及其用法、词根词缀等。',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: s(15),
        mainAxisSpacing: s(15),
        childAspectRatio: 1.6,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        return _buildToolCard(
          context,
          tool['title'],
          tool['subtitle'],
          tool['icon'],
          tool['color'],
          () => tool['knowledge'] == true
              ? Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChineseToEnglishPage(),
                  ),
                )
              : _navigateToChat(context, tool['title'], tool['prompt']),
        );
      },
    );
  }

  Widget _buildToolCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    final s = (double size) => ResponsiveHelper.s(context, size);
    return GestureDetector(
      onTap: () {
        SoundService.playTapSound();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.all(s(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(s(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: s(10),
              offset: Offset(0, s(4)),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: s(16),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
                SizedBox(height: s(4)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: s(11),
                    color: const Color(0xFF999999),
                  ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(s(4)),
                child: Icon(
                  icon,
                  color: color.withOpacity(0.6),
                  size: s(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToChat(BuildContext context, String title, String prompt) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AIChatPage(
          chatType: 'daily',
          title: title,
          systemPrompt: prompt,
        ),
      ),
    );
  }
}

