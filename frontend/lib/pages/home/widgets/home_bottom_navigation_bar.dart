import 'package:flutter/material.dart';
import '../../../utils/sound_service.dart';
import '../../../utils/responsive_helper.dart';

/// 首页底部导航栏组件
class HomeBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const HomeBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = (double size) => ResponsiveHelper.s(context, size);
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: s(10),
            offset: Offset(0, s(-2)),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s(8.0), vertical: s(8.0)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, 0, Icons.translate_rounded, '单词'),
              _buildNavItem(context, 1, Icons.assignment_outlined, '计划'),
              _buildNavItem(context, 2, Icons.auto_awesome_outlined, 'AI智学'),
              _buildNavItem(context, 3, Icons.menu_book_rounded, '学习'),
              _buildNavItem(context, 4, Icons.person_outline_rounded, '我的'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final s = (double size) => ResponsiveHelper.s(context, size);
    final isSelected = currentIndex == index;
    final color = isSelected ? Theme.of(context).primaryColor : Colors.grey.shade400;

    return GestureDetector(
      onTap: () {
        if (currentIndex != index) {
          SoundService.playTapSound();
          onTap(index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: s(26),
          ),
          SizedBox(height: s(4)),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: s(12),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

