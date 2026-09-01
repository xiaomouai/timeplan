import 'package:flutter/material.dart';
import '../../../utils/sound_service.dart';
import '../../../services/auth_service.dart';

/// 首页顶部工具栏组件
class HomeTopBar extends StatelessWidget {
  final String userName;
  final String userAvatar;
  final VoidCallback onProfileTap;

  const HomeTopBar({
    super.key,
    required this.userName,
    required this.userAvatar,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 用户头像
        GestureDetector(
          onTap: () {
            SoundService.playTapSound();
            onProfileTap();
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              color: Colors.grey.shade300,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: userAvatar.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      userAvatar,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAvatar();
                      },
                    ),
                  )
                : _buildDefaultAvatar(),
          ),
        ),
        const SizedBox(width: 10),
        // 用户信息
        GestureDetector(
          onTap: () {
            SoundService.playTapSound();
            onProfileTap();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (AuthService.instance.isVip())
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'VIP会员',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        // 搜索/设置等操作按钮 (可根据需要添加)
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {
            SoundService.playTapSound();
            // TODO: 搜索逻辑
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () {
            SoundService.playTapSound();
            // TODO: 通知逻辑
          },
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return const Center(
      child: Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}
