import 'package:flutter/foundation.dart';

/// API 配置
class ApiConfig {
  // 开发环境配置
  // 1. 如果使用 Web 浏览器调试，使用 localhost
  // 2. 如果使用 Android 模拟器调试，使用 10.0.2.2
  // 3. 如果使用真机调试，请将此处改为你电脑的局域网 IP (如 192.168.x.x)
  // 本机 AirPlay 占用 5000，本地后端改跑 5055；可用 --dart-define=API_DEV_PORT=xxxx 覆盖
  static String get devBaseUrl {
    const envPort = String.fromEnvironment('API_DEV_PORT', defaultValue: '5055');
    if (kIsWeb) return 'http://localhost:$envPort';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://81.69.249.204:5000';
    }
    return 'http://localhost:$envPort';
  }

  // Production can be overridden at build time:
  // flutter build apk --dart-define=APP_PRODUCTION=true \
  //   --dart-define=API_BASE_URL=https://api.example.com
  static const String prodBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://xueba.mingboai.com',
  );
  
  // 当前使用的环境
  static const bool isProduction = bool.fromEnvironment(
    'APP_PRODUCTION',
    defaultValue: false,
  );

  /// 开发环境默认启用确定性 Demo，便于没有后端或模型密钥时走通训练闭环。
  /// 生产构建始终关闭，真实 API、会员和支付链路不被模拟数据替代。
  static const bool demoModeFlag = bool.fromEnvironment(
    'APP_DEMO_MODE',
    defaultValue: true,
  );

  static bool get useSimulatedData => !isProduction && demoModeFlag;

  /// Demo 中默认使用 Pro，便于验收完整训练和历史复习路径。
  /// 设置 --dart-define=APP_DEMO_PRO=false 可验证免费权益拦截。
  static const bool demoProEnabled = bool.fromEnvironment(
    'APP_DEMO_PRO',
    defaultValue: true,
  );
  
  // 获取当前 API 基础 URL
  static String get baseUrl => isProduction ? prodBaseUrl : devBaseUrl;
  
  // API 版本
  static const String apiVersion = 'v1';
  
  // 完整的API路径
  static String get apiPath => '$baseUrl/api/$apiVersion';
  
  // API 超时时间
  static const Duration timeout = Duration(seconds: 10);
  
  // 是否启用日志
  static const bool enableLogging = true;
  
  // 缓存过期时间
  static const Duration cacheExpiration = Duration(hours: 24);
  
  // 版本检查间隔（小时）
  static const int versionCheckInterval = 24;
  
  // 是否启用自动更新检查
  static const bool enableAutoUpdateCheck = true;
  
  // ========== 单词API配置 ==========
  
  // 单词搜索接口
  static String get wordSearchUrl => '$apiPath/words/search';
  
  // 单词详情接口
  static String wordDetailUrl(String bookId, int wordRank) => 
      '$apiPath/words/$bookId/$wordRank';
  
  // 词书单词列表接口
  static String bookWordsUrl(String bookId) => 
      '$apiPath/books/$bookId/words';
  
  // 今日推荐单词接口
  static String get dailyRecommendUrl => '$apiPath/words/daily-recommend';
}

