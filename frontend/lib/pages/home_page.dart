import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/responsive_helper.dart';

// 导入自定义控制器
import 'home/controllers/home_controller.dart';
import 'home/controllers/word_learning_controller.dart';

// 导入各个标签页
import 'home/tabs/word_tab.dart';
import 'home/tabs/plan_tab.dart';
import 'home/tabs/ai_study_tab.dart';
import 'home/tabs/study_center_tab.dart';
import 'home/tabs/profile_tab.dart';

// 导入公共组件
import 'home/widgets/home_bottom_navigation_bar.dart';
import 'home/widgets/red_envelope_banner.dart';
import '../utils/app_theme.dart';

/// 首页入口页面
/// 负责底导切换逻辑、全局状态分发以及首页脚手架构建
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 控制是否显示底部红包/福利条
  bool _showRedEnvelopeBanner = true;

  @override
  void initState() {
    super.initState();
    // 异步加载用户数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<HomeController>().loadUserProfile();
        context.read<WordLearningController>().loadWordsFromSelectedWordBook();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = (double size) => ResponsiveHelper.s(context, size);
    
    // 使用 Consumer 监听首页控制器状态变化
    return Consumer<HomeController>(
      builder: (context, controller, child) {
        return Scaffold(
          // 根据主题模式设置背景色
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkBackgroundColor 
              : AppTheme.backgroundColor,
          
          // 使用 IndexedStack 保持各个 Tab 的页面状态
          body: Stack(
            children: [
              IndexedStack(
                index: controller.currentTabIndex,
                children: const [
                  WordTab(),         // 单词学习页
                  PlanTab(),         // 学习计划页
                  AIStudyTab(),      // AI 智学页
                  StudyCenterTab(),  // 学习中心页
                  ProfileTab(),      // 个人中心页
                ],
              ),
              
              // 底部红包/优惠券悬浮提示条（仅在首页单词 Tab 显示）
              if (_showRedEnvelopeBanner && controller.currentTabIndex == 0)
                Positioned(
                  left: s(16),
                  right: s(16),
                  bottom: s(16),
                  child: RedEnvelopeBanner(
                    onTap: () {
                      // 点击跳转到个人中心或指定页面
                      controller.setTabIndex(4);
                    },
                    onClose: () {
                      setState(() {
                        _showRedEnvelopeBanner = false;
                      });
                    },
                  ),
                ),
            ],
          ),
          
          // 自定义底部导航栏
          bottomNavigationBar: HomeBottomNavigationBar(
            currentIndex: controller.currentTabIndex,
            onTap: (index) {
              controller.setTabIndex(index);
            },
          ),
        );
      },
    );
  }
}
