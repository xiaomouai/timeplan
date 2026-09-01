import 'package:flutter/material.dart';
import '../../../utils/sound_service.dart';

/// 首页红包/福利悬浮条组件
class RedEnvelopeBanner extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onClose;

  const RedEnvelopeBanner({
    super.key,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F0),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 红包/优惠券图标
          Image.asset(
            'assets/images/coupon_icon.png',
            width: 40,
            height: 40,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.confirmation_number_rounded, color: Colors.orange),
            ),
          ),
          const SizedBox(width: 10),
          // 文案
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '恭喜您获得专属福利~',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6D4C41),
                  ),
                ),
                Text(
                  '有一张优惠券可以使用 共200元',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF00C897),
                  ),
                ),
              ],
            ),
          ),
          // 免费领按钮
          GestureDetector(
            onTap: () {
              SoundService.playTapSound();
              onTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00C897),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '免费领',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 关闭按钮
          GestureDetector(
            onTap: onClose,
            child: const Icon(
              Icons.close,
              size: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
