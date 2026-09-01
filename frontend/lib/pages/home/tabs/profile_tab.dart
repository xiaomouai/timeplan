import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/home_controller.dart';
import '../../../utils/sound_service.dart';
import '../../../utils/cache_service.dart';
import '../../../utils/learning_data_service.dart';
import '../../../utils/spaced_repetition_service.dart';
import '../../../services/auth_service.dart';

/// 首页“我的”标签页
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isEditingNickname = false;
  late TextEditingController _nicknameController;
  LearningStats? _stats;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<HomeController>(context, listen: false);
    _nicknameController = TextEditingController(text: controller.userName);
    _loadLearningStats();
  }

  Future<void> _loadLearningStats() async {
    try {
      final wordBookName = await CacheService.getSelectedWordBook() ?? 'default';
      final stats = await LearningDataService.instance.getLearningStats(wordBookName);
      if (mounted) setState(() => _stats = stats);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _updateNickname() async {
    final controller = Provider.of<HomeController>(context, listen: false);
    final newNickname = _nicknameController.text.trim();
    if (newNickname.isNotEmpty && newNickname != controller.userName) {
      final success = await controller.updateNickname(newNickname);
      if (success) {
        setState(() {
          _isEditingNickname = false;
        });
      }
    } else {
      setState(() {
        _isEditingNickname = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeController>(
      builder: (context, controller, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FBFB),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // 1. 顶部用户信息区
                _buildHeader(controller),
                
                // 2. 会员卡片和数据统计区
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildVipCard(controller),
                      _buildStatistics(),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // 3. 菜单列表
                _buildMenuList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(HomeController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF88D8C0), Color(0xFFF8FBFB)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          // 头像
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              image: const DecorationImage(
                image: AssetImage('assets/images/default_avatar.png'),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 昵称和手机号
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _isEditingNickname
                    ? _buildNicknameEditor()
                    : _buildNicknameDisplay(controller),
                const SizedBox(height: 4),
                Text(
                  controller.userPhone.isNotEmpty
                      ? (controller.userPhone.length >= 11
                          ? '${controller.userPhone.substring(0, 3)}****${controller.userPhone.substring(7)}'
                          : controller.userPhone)
                      : '手机号未绑定',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNicknameEditor() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _nicknameController,
            autofocus: true,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A535C),
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              border: UnderlineInputBorder(),
            ),
            onSubmitted: (_) => _updateNickname(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check, color: Colors.green),
          onPressed: _updateNickname,
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () {
            setState(() {
              _isEditingNickname = false;
              _nicknameController.text = Provider.of<HomeController>(context, listen: false).userName;
            });
          },
        ),
      ],
    );
  }

  Widget _buildNicknameDisplay(HomeController controller) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isEditingNickname = true;
          _nicknameController.text = controller.userName;
        });
      },
      child: Row(
        children: [
          Text(
            controller.userName == '新用户' ? 'HI，请设置昵称' : controller.userName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A535C),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade600),
        ],
      ),
    );
  }

  Widget _buildVipCard(HomeController controller) {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE0B2), Color(0xFFFFF3E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    AuthService.instance.isVip() ? '尊贵会员' : '免费用户',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF795548),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.stars_rounded, color: Colors.amber.shade700, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                AuthService.instance.isVip()
                    ? (AuthService.instance.userInfo?.vipExpireAt != null
                        ? '会员有效期至：${AuthService.instance.userInfo!.vipExpireAt}'
                        : '会员状态已由服务端确认')
                    : '开通会员，解锁更多功能',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.brown.withOpacity(0.7),
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: () {
                SoundService.playTapSound();
                Navigator.pushNamed(context, '/membership');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  AuthService.instance.isVip() ? '立即续费' : '立即开通',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF795548),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              Icons.workspace_premium,
              size: 80,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    final stats = _stats;
    final mastered = stats?.levelStats.entries
            .where((entry) => entry.key.index >= 4)
            .fold<int>(0, (total, entry) => total + entry.value) ??
        0;
    return Transform.translate(
      offset: const Offset(0, -15),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(stats == null ? '—' : '${stats.totalWords}词', '累计学词'),
            _buildStatItem(stats == null ? '—' : '${mastered}词', '累计掌握'),
            _buildStatItem(stats == null ? '—' : '${stats.learningDays}天', '坚持天数'),
            _buildStatItem('—', '总学习时长'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A535C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            _buildMenuItem(Icons.person_outline_rounded, '个人信息', () => Navigator.pushNamed(context, '/profile')),
            _buildMenuItem(Icons.workspace_premium_outlined, '我的会员', () => Navigator.pushNamed(context, '/membership')),
            _buildMenuItem(Icons.settings_outlined, '系统设置', () => Navigator.pushNamed(context, '/settings')),
            _buildMenuItem(Icons.help_outline_rounded, '帮助与反馈', () => Navigator.pushNamed(context, '/feedback')),
            _buildMenuItem(Icons.info_outline_rounded, '关于我们', () {
              showAboutDialog(
                context: context,
                applicationName: '猫头鹰学英语',
                applicationVersion: '1.0.0',
                applicationIcon: const FlutterLogo(),
                children: [
                  const Text('猫头鹰学英语是一款专业的英语词汇学习工具。'),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1A535C)),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: () {
        SoundService.playTapSound();
        onTap();
      },
    );
  }
}
