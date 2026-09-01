import 'package:flutter/material.dart';
import '../../../utils/sound_service.dart';
import '../../phonetics_practice_page.dart';
import '../../challenge_main_page.dart';

/// 首页“学习中心”标签页
/// 提供绘本、听力、口语、视频等多元化学习资源
class StudyCenterTab extends StatelessWidget {
  const StudyCenterTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '学习中心',
          style: TextStyle(color: Color(0xFF1A535C), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStudyModule(
            context,
            '绘本阅读',
            '精选英文原版绘本，培养阅读习惯',
            Icons.menu_book_rounded,
            Colors.orange,
            () {
              // 暂时跳转到词库选择，后续可开发专门的绘本页面
              Navigator.pushNamed(context, '/library');
            },
          ),
          _buildStudyModule(
            context,
            '听力训练',
            '每日听力磨耳朵，提升语感',
            Icons.headset_rounded,
            Colors.blue,
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('听力训练功能开发中，敬请期待')),
              );
            },
          ),
          _buildStudyModule(
            context,
            '口语练习',
            'AI 纠音，自信开口说英语',
            Icons.mic_rounded,
            Colors.purple,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PhoneticsPracticePage()),
              );
            },
          ),
          _buildStudyModule(
            context,
            '视频课堂',
            '名师讲解，掌握核心知识点',
            Icons.play_circle_outline_rounded,
            Colors.red,
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('视频课堂功能开发中，敬请期待')),
              );
            },
          ),
          _buildStudyModule(
            context,
            '词汇竞赛',
            '与小伙伴一起PK，看谁词汇量更大',
            Icons.emoji_events_outlined,
            const Color(0xFF00C897),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChallengeMainPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 构建学习模块入口卡片
  Widget _buildStudyModule(BuildContext context, String title, String desc, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        SoundService.playTapSound();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A535C)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
