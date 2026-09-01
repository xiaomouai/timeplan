import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'pages/onboarding_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/enhanced_word_review_page.dart';
import 'pages/algorithm_settings_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/invite_page.dart';
import 'pages/membership_page.dart';
import 'pages/checkin_page.dart';
import 'pages/profile_page.dart';
import 'pages/privacy_policy_page.dart';
import 'pages/grade_select_page.dart';
import 'pages/feedback_page.dart';
import 'utils/app_theme.dart';
import 'utils/learning_data_service.dart';
import 'utils/settings_helper.dart';
import 'utils/deepseek_api_service.dart';
import 'utils/auth_guard.dart';
import 'pages/library_page.dart';
import 'utils/algorithm_manager.dart';
import 'utils/auto_update_service.dart';
import 'utils/performance_optimizer.dart';
import 'utils/render_compatibility_helper.dart';
import 'services/auth_service.dart';
import 'pages/planner/planner_home_page.dart';
import 'pages/planner/health_page.dart';

import 'package:provider/provider.dart';
import 'pages/home/controllers/home_controller.dart';
import 'pages/home/controllers/word_learning_controller.dart';

void main() {
  // Zone 必须包住**整个**启动流程：
  // main() 里各服务初始化（认证/学习数据/自动更新）会派生未被 await 的后台 Future
  // （如拉取学习记录的网络请求）。若这些 Future 在根 zone 创建，reject 时会逃过
  // runZonedGuarded，变成浏览器里裸的 "Uncaught Error"（这正是之前反复复现的原因）。
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 启动标记：用于确认浏览器加载的是最新构建（排查缓存旧包导致的"改了没生效"）
      debugPrint('[boot] timePlan bundle 0901-D (speech-recognition guard)');

      // 平台层错误（zone 抓不到的渲染/引擎错误）也兜底，避免漏网白屏
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('[PlatformError] $error\n$stack');
        _showErrorOverlay(error, stack);
        return true;
      };

      // 全局错误兜底：捕获未处理的异步异常（如后端短暂不可达导致的 Future 拒绝），
      // 避免 Web 端出现 "Uncaught Error" 白屏，并把真实错误打到控制台 + 弹窗便于排查。
      FlutterError.onError = (details) {
        debugPrint('[FlutterError] ${details.exception}\n${details.stack}');
        _showErrorOverlay(details.exception, details.stack);
      };

      // 强制初始化渲染兼容性设置，彻底解决GPU渲染问题
      await RenderCompatibilityHelper.initialize();
  
  // 强制清理所有可能的渲染缓存
  // 确保应用以最干净的状态启动
  try {
    // 多次强制清理，确保彻底
    for (int i = 0; i < 3; i++) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await Future.delayed(const Duration(milliseconds: 100));
    }
  } catch (e) {
    // 忽略清理错误
  }

  // 优化渲染性能，解决特定设备滑动闪烁问题
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  // 立即设置默认的系统UI覆盖层（浅色模式）
  AppTheme.setLightSystemUIOverlay();
  
      // 各服务初始化：分开 try/catch，任何一项失败都不能阻断 runApp（否则白屏）
      try {
        await AuthService.instance.initialize();
      } catch (e) {
        debugPrint('[main] AuthService 初始化失败，已降级：$e');
      }

      try {
        await LearningDataService.instance.initialize();
      } catch (e) {
        debugPrint('[main] LearningDataService 初始化失败，已降级：$e');
      }

      try {
        await AutoUpdateService.instance.initialize();
      } catch (e) {
        debugPrint('[main] AutoUpdateService 初始化失败，已降级：$e');
      }

      // 检查API Key和学习模式的兼容性
      try {
        await _validateLearningModeAndApiKey();
      } catch (e) {
        debugPrint('[main] 校验学习模式失败，已忽略：$e');
      }

      // 延迟预热性能优化器对象池到首帧后，减少启动卡顿
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PerformanceOptimizer.preWarmPools();
      });

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => HomeController()),
            ChangeNotifierProvider(create: (_) => WordLearningController()),
          ],
          child: const XueBaApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('[Uncaught] $error\n$stack');
      _showErrorOverlay(error, stack);
    },
  );
}

/// 把真实错误以弹窗显示出来（不再只是控制台里的裸 "Uncaught"），
/// 方便用户直接把错误文案贴回来定位问题。
void _showErrorOverlay(Object error, [StackTrace? stack]) {
  try {
    SmartDialog.show(
      tag: 'global-error',
      clickMaskDismiss: true,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 420),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠️ 运行错误（请把这段贴给开发）',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                Text('$error', style: const TextStyle(fontSize: 13)),
                if (stack != null) ...[
                  const SizedBox(height: 8),
                  Text('$stack',
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  } catch (_) {
    // 弹窗失败也不应影响主流程
  }
}

/// 验证学习模式和API Key的兼容性
Future<void> _validateLearningModeAndApiKey() async {
    final learningMode = await SettingsHelper.getLearningMode();
    if (learningMode == LearningMode.deepLearning) {
      final apiKey = await DeepSeekApiService.getApiKey();
      final isApiKeyValid = apiKey != null && apiKey.isNotEmpty && apiKey.length >= 10;
      
      if (!isApiKeyValid) {
        // API Key无效，自动切换到快速学习模式
        await SettingsHelper.setLearningMode(LearningMode.quickMemory);
      }
    }
}

/// 猫头鹰学英语APP应用的主入口类
/// 负责应用的整体配置、主题设置和初始路由判断
class XueBaApp extends StatefulWidget {
  const XueBaApp({super.key});

  @override
  State<XueBaApp> createState() => _XueBaAppState();
}

class _XueBaAppState extends State<XueBaApp> with WidgetsBindingObserver {
  String _themeMode = 'light'; // light, dark, parchment, cream
  double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AutoUpdateService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 当应用从后台恢复到前台时检查更新
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AutoUpdateService.instance.checkOnAppResume(context);
        }
      });
    }
  }

  /// 初始化所有服务
  Future<void> _initServices() async {
      // 加载主题偏好
      _loadThemePreference();
      
      // 加载字体缩放偏好
      _loadFontScalePreference();
      
      // 初始化算法管理器（LearningDataService 已在 main() 中初始化）
      await AlgorithmManager.instance.initialize();
  }

  /// 加载字体缩放偏好设置
  void _loadFontScalePreference() async {
    final fontScale = await SettingsHelper.getFontScale();
    if (_fontScale != fontScale) {
      setState(() {
        _fontScale = fontScale;
      });
    }
  }

  /// 加载主题偏好设置
  void _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeMode = prefs.getString('theme_mode') ?? 'light';
    
    if (_themeMode != themeMode) {
      setState(() {
        _themeMode = themeMode;
      });
      
      // 设置对应的系统UI覆盖层
      if (themeMode == 'dark') {
        AppTheme.setDarkSystemUIOverlay();
      } else {
        AppTheme.setLightSystemUIOverlay();
      }
    }
  }

  /// 切换主题
  void _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // 简单的切换逻辑：light -> dark -> parchment -> cream -> light
    String newTheme;
    switch (_themeMode) {
      case 'light':
        newTheme = 'dark';
        break;
      case 'dark':
        newTheme = 'parchment';
        break;
      case 'parchment':
        newTheme = 'cream';
        break;
      case 'cream':
      default:
        newTheme = 'light';
        break;
    }
    
    setState(() {
      _themeMode = newTheme;
    });
    await prefs.setString('theme_mode', newTheme);
    
    // 更新系统UI覆盖层
    if (newTheme == 'dark') {
      AppTheme.setDarkSystemUIOverlay();
    } else {
      AppTheme.setLightSystemUIOverlay();
    }
  }

  /// 更新字体缩放
  void _updateFontScale(double scale) async {
    setState(() {
      _fontScale = scale;
    });
    await SettingsHelper.setFontScale(scale);
  }

  @override
  Widget build(BuildContext context) {
    // 根据主题模式选择对应的主题
    ThemeData selectedTheme;
    ThemeMode selectedThemeMode;
    
    switch (_themeMode) {
      case 'dark':
        selectedTheme = AppTheme.darkTheme;
        selectedThemeMode = ThemeMode.dark;
        break;
      case 'parchment':
        selectedTheme = AppTheme.parchmentTheme;
        selectedThemeMode = ThemeMode.light;
        break;
      case 'cream':
        selectedTheme = AppTheme.creamTheme;
        selectedThemeMode = ThemeMode.light;
        break;
      case 'light':
      default:
        selectedTheme = AppTheme.lightTheme;
        selectedThemeMode = ThemeMode.light;
        break;
    }
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'timePlan — AI 时间规划助手',
      // 使用自定义的简约主题，支持多种主题模式
      theme: selectedTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: selectedThemeMode,
      // 全局字体缩放实现
      builder: FlutterSmartDialog.init(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(_fontScale),
            ),
            child: child!,
          );
        },
      ),
      navigatorObservers: [FlutterSmartDialog.observer],
      // 使用兼容性优化的滚动行为，解决GPU渲染问题
      scrollBehavior: RenderCompatibilityHelper.getCompatibleScrollBehavior(),
      // 本地化配置
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 中文
        Locale('en', 'US'), // 英文
      ],
      locale: const Locale('zh', 'CN'), // 默认使用中文
      // timePlan：直接进入计划主页，原基座页面仍可通过路由访问
      home: const PlannerHomePage(),
      // 定义应用的路由配置
      routes: {
        '/planner': (context) => const PlannerHomePage(),
        // 健康底座：12 条证据项打卡 + 作息模板 + 周/月/季节奏
        '/health': (context) => const HealthPage(),
        '/onboarding': (context) => const OnboardingPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/grade_select': (context) => const GradeSelectPage(),
        '/privacy': (context) => const PrivacyPolicyPage(),
        '/feedback': (context) => const FeedbackPage(),
        // 需要登录的页面
        '/home': (context) => authGuard(const HomePage()),
        '/library': (context) => authGuard(const LibraryPage()),
        '/invite': (context) => authGuard(const InvitePage()),
        '/membership': (context) => authGuard(const MembershipPage()),
        '/checkin': (context) => authGuard(const CheckinPage()),
        '/settings': (context) => authGuard(
          ThemeProvider(
            toggleTheme: _toggleTheme,
            fontScale: _fontScale,
            updateFontScale: _updateFontScale,
            child: const SettingsPage(),
          ),
        ),
        '/enhanced_word_review': (context) => authGuard(const EnhancedWordReviewPage()),
        '/algorithm_settings': (context) => authGuard(const AlgorithmSettingsPage()),
        '/profile': (context) => authGuard(const ProfilePage()),
      },
    );
  }
}

/// 主题提供者，用于向设置页面传递主题切换函数
class ThemeProvider extends InheritedWidget {
  final VoidCallback toggleTheme;
  final double fontScale;
  final Function(double) updateFontScale;

  // ignore: use_super_parameters
  const ThemeProvider({
    super.key,
    required this.toggleTheme,
    required this.fontScale,
    required this.updateFontScale,
    required Widget child,
  }) : super(child: child);

  static ThemeProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return toggleTheme != oldWidget.toggleTheme || 
           fontScale != oldWidget.fontScale;
  }
}

/// 应用初始化器
/// 检查用户登录状态和初始设置，决定显示哪个页面
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    // 在应用启动后检查更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AutoUpdateService.instance.checkOnAppStart(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppStartupRoute>(
      // 检查应用启动路由
      future: _determineStartupRoute(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 加载中显示简约的启动画面
          return const Scaffold(
            backgroundColor: Color(0xFFF5F5F5),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF666666),
              ),
            ),
          );
        }
        
        // 根据路由类型决定显示的页面
        final route = snapshot.data ?? AppStartupRoute.onboarding;
        
        switch (route) {
          case AppStartupRoute.onboarding:
            return const OnboardingPage();
          case AppStartupRoute.login:
            return const LoginPage();
          case AppStartupRoute.home:
            return const HomePage();
        }
      },
    );
  }

  /// 确定应用启动路由
  /// 优先级：引导页 > 登录页 > 首页
  Future<AppStartupRoute> _determineStartupRoute() async {
    // 1. 检查是否完成引导页
    final onboardingCompleted = await _checkOnboardingStatus();
    if (!onboardingCompleted) {
      return AppStartupRoute.onboarding;
    }
    
    // 2. 检查是否已登录
    final isLoggedIn = AuthService.instance.isLoggedIn;
    if (!isLoggedIn) {
      return AppStartupRoute.login;
    }
    
    // 3. 已登录，进入首页
    return AppStartupRoute.home;
  }

  /// 检查用户是否已完成起始页配置
  /// 返回true表示已完成，false表示需要显示起始页
  Future<bool> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }
}

/// 应用启动路由枚举
enum AppStartupRoute {
  onboarding, // 引导页
  login,      // 登录页
  home,       // 首页
}
