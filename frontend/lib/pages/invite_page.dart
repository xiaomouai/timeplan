import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/auth_service.dart';
import '../utils/sound_service.dart';
import 'dart:math';

/// 邀请页面
/// 用户可以生成邀请码，分享给好友获得奖励
class InvitePage extends StatefulWidget {
  const InvitePage({super.key});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // 用户邀请码
  String _inviteCode = '';
  
  // 邀请统计
  int _invitedCount = 0;
  int _rewardPoints = 0;
  
  // 邀请奖励列表
  final List<InviteReward> _rewards = [
    InviteReward(count: 1, reward: 'VIP体验3天', icon: Icons.card_giftcard),
    InviteReward(count: 3, reward: 'VIP体验7天', icon: Icons.workspace_premium),
    InviteReward(count: 5, reward: 'VIP会员1个月', icon: Icons.diamond),
    InviteReward(count: 10, reward: 'VIP会员3个月', icon: Icons.stars),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _loadInviteData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _animationController.forward();
  }

  /// 加载邀请数据
  Future<void> _loadInviteData() async {
    // 生成用户邀请码（基于用户ID）
    final userId = AuthService.instance.userId ?? '';
    _inviteCode = _generateInviteCode(userId);
    
    // TODO: 从后端加载真实的邀请统计数据
    // 这里使用模拟数据
    setState(() {
      _invitedCount = 0;
      _rewardPoints = 0;
    });
  }

  /// 生成邀请码
  String _generateInviteCode(String userId) {
    if (userId.isEmpty) {
      return 'XUEBA${Random().nextInt(999999).toString().padLeft(6, '0')}';
    }
    
    // 基于用户ID生成6位邀请码
    final hash = userId.hashCode.abs();
    return 'XUEBA${(hash % 1000000).toString().padLeft(6, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () {
            SoundService.playTapSound();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          '邀请好友',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 邀请卡片
                _buildInviteCard(),
                
                const SizedBox(height: 20),
                
                // 邀请统计
                _buildInviteStats(),
                
                const SizedBox(height: 20),
                
                // 奖励进度
                _buildRewardProgress(),
                
                const SizedBox(height: 20),
                
                // 邀请规则
                _buildInviteRules(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建邀请卡片
  Widget _buildInviteCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00E676), Color(0xFF00C897)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C897).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.card_giftcard,
            size: 60,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          const Text(
            '邀请好友，共享学习',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '每邀请1位好友注册，双方均可获得奖励',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // 邀请码
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '我的邀请码：',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _inviteCode,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.copy,
                  label: '复制邀请码',
                  onTap: _copyInviteCode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share,
                  label: '分享给好友',
                  onTap: _shareInvite,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        SoundService.playTapSound();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF00C897)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C897),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建邀请统计
  Widget _buildInviteStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.people,
              label: '已邀请',
              value: '$_invitedCount',
              color: const Color(0xFF00C897),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade200,
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.stars,
              label: '获得积分',
              value: '$_rewardPoints',
              color: const Color(0xFFFFB74D),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
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

  /// 构建奖励进度
  Widget _buildRewardProgress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '邀请奖励',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          
          ..._rewards.map((reward) => _buildRewardItem(reward)),
        ],
      ),
    );
  }

  /// 构建奖励项
  Widget _buildRewardItem(InviteReward reward) {
    final isCompleted = _invitedCount >= reward.count;
    final progress = _invitedCount / reward.count;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // 图标
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted 
                  ? const Color(0xFF00C897) 
                  : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : reward.icon,
              color: isCompleted ? Colors.white : Colors.grey.shade400,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      reward.reward,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isCompleted 
                            ? const Color(0xFF00C897) 
                            : const Color(0xFF333333),
                      ),
                    ),
                    Text(
                      '${reward.count}人',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                
                // 进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress > 1.0 ? 1.0 : progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted 
                          ? const Color(0xFF00C897) 
                          : const Color(0xFF00E676),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建邀请规则
  Widget _buildInviteRules() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 20,
                color: Color(0xFF00C897),
              ),
              const SizedBox(width: 8),
              const Text(
                '邀请规则',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildRuleItem('1. 分享邀请码给好友，好友注册时填写邀请码'),
          _buildRuleItem('2. 好友成功注册后，双方均可获得奖励'),
          _buildRuleItem('3. 邀请越多，奖励越丰厚'),
          _buildRuleItem('4. 奖励将自动发放到账户'),
          _buildRuleItem('5. 活动最终解释权归猫头鹰学英语所有'),
        ],
      ),
    );
  }

  /// 构建规则项
  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 复制邀请码
  void _copyInviteCode() {
    Clipboard.setData(ClipboardData(text: _inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('邀请码已复制到剪贴板'),
        backgroundColor: Color(0xFF00C897),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 分享邀请
  void _shareInvite() {
    final userName = AuthService.instance.getUserNickname();
    final shareText = '''
🎉 $userName 邀请你一起使用猫头鹰学英语APP！
📚 智能英语学习助手，让背单词更高效
🎁 使用邀请码：$_inviteCode 注册，即可获得新人礼包

立即下载：https://app.mty.mingboai.com/download/mtyapp.apk
''';

    Share.share(
      shareText,
      subject: '猫头鹰学英语 - 邀请好友',
    );
  }
}

/// 邀请奖励模型
class InviteReward {
  final int count;
  final String reward;
  final IconData icon;

  InviteReward({
    required this.count,
    required this.reward,
    required this.icon,
  });
}
