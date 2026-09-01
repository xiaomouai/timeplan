import 'package:package_info_plus/package_info_plus.dart';
import 'api_service.dart';

/// 版本管理服务
/// 负责检查应用更新和API兼容性
class VersionService {
  static final VersionService _instance = VersionService._internal();
  factory VersionService() => _instance;
  VersionService._internal();

  static VersionService get instance => _instance;

  final ApiService _api = ApiService.instance;

  /// 获取当前应用版本信息
  Future<AppVersionInfo> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return AppVersionInfo(
      version: packageInfo.version,
      buildNumber: int.tryParse(packageInfo.buildNumber) ?? 0,
      appName: packageInfo.appName,
      packageName: packageInfo.packageName,
    );
  }

  /// 获取API版本信息
  Future<ApiVersionInfo> getApiVersion() async {
    try {
      final response = await _api.get('/api/v1/version/api');
      
      if (response['success'] == true && response['data'] != null) {
        return ApiVersionInfo.fromJson(response['data']);
      }
      
      throw Exception('获取API版本失败');
    } catch (e) {
      throw Exception('获取API版本失败: $e');
    }
  }

  /// 检查应用更新
  Future<UpdateCheckResult> checkUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();
      
      final response = await _api.post(
        '/api/v1/version/app/check',
        body: {
          'current_version': currentVersion.version,
          'build_number': currentVersion.buildNumber,
          'platform': 'android', // 或根据平台动态获取
        },
      );

      if (response['success'] == true && response['data'] != null) {
        return UpdateCheckResult.fromJson(response['data']);
      }

      throw Exception('检查更新失败');
    } catch (e) {
      throw Exception('检查更新失败: $e');
    }
  }

  /// 检查前后端兼容性
  Future<CompatibilityResult> checkCompatibility() async {
    try {
      final currentVersion = await getCurrentVersion();
      
      final response = await _api.post(
        '/api/v1/version/compatibility',
        body: {
          'app_version': currentVersion.version,
        },
      );

      if (response['success'] == true && response['data'] != null) {
        return CompatibilityResult.fromJson(response['data']);
      }

      throw Exception('兼容性检查失败');
    } catch (e) {
      throw Exception('兼容性检查失败: $e');
    }
  }

  /// 获取最新版本信息
  Future<LatestVersionInfo> getLatestVersion() async {
    try {
      final response = await _api.get('/api/v1/version/app/latest');
      
      if (response['success'] == true && response['data'] != null) {
        return LatestVersionInfo.fromJson(response['data']);
      }
      
      throw Exception('获取最新版本失败');
    } catch (e) {
      throw Exception('获取最新版本失败: $e');
    }
  }
}

/// 应用版本信息
class AppVersionInfo {
  final String version;
  final int buildNumber;
  final String appName;
  final String packageName;

  AppVersionInfo({
    required this.version,
    required this.buildNumber,
    required this.appName,
    required this.packageName,
  });

  @override
  String toString() => 'v$version ($buildNumber)';
}

/// API版本信息
class ApiVersionInfo {
  final String version;
  final int build;
  final String releaseDate;
  final String minAppVersion;
  final List<String> features;

  ApiVersionInfo({
    required this.version,
    required this.build,
    required this.releaseDate,
    required this.minAppVersion,
    required this.features,
  });

  factory ApiVersionInfo.fromJson(Map<String, dynamic> json) {
    return ApiVersionInfo(
      version: json['version'] ?? '',
      build: json['build'] ?? 0,
      releaseDate: json['release_date'] ?? '',
      minAppVersion: json['min_app_version'] ?? '',
      features: (json['features'] as List?)?.cast<String>() ?? [],
    );
  }
}

/// 更新检查结果
class UpdateCheckResult {
  final bool hasUpdate;
  final String currentVersion;
  final int currentBuild;
  final String? latestVersion;
  final int? latestBuild;
  final bool forceUpdate;
  final UpdateInfo? updateInfo;

  UpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    required this.currentBuild,
    this.latestVersion,
    this.latestBuild,
    this.forceUpdate = false,
    this.updateInfo,
  });

  factory UpdateCheckResult.fromJson(Map<String, dynamic> json) {
    return UpdateCheckResult(
      hasUpdate: json['has_update'] ?? false,
      currentVersion: json['current_version'] ?? '',
      currentBuild: json['current_build'] ?? 0,
      latestVersion: json['latest_version'],
      latestBuild: json['latest_build'],
      forceUpdate: json['force_update'] ?? false,
      updateInfo: json['update_info'] != null
          ? UpdateInfo.fromJson(json['update_info'])
          : null,
    );
  }
}

/// 更新信息
class UpdateInfo {
  final String version;
  final int buildNumber;
  final String releaseDate;
  final String downloadUrl;
  final List<String> changelog;
  final bool forceUpdate;
  final String fileSize;
  final String md5;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.downloadUrl,
    required this.changelog,
    required this.forceUpdate,
    required this.fileSize,
    required this.md5,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] ?? '',
      buildNumber: json['build_number'] ?? 0,
      releaseDate: json['release_date'] ?? '',
      downloadUrl: json['download_url'] ?? '',
      changelog: (json['changelog'] as List?)?.cast<String>() ?? [],
      forceUpdate: json['force_update'] ?? false,
      fileSize: json['file_size'] ?? '',
      md5: json['md5'] ?? '',
    );
  }
}

/// 兼容性检查结果
class CompatibilityResult {
  final bool compatible;
  final String appVersion;
  final String apiVersion;
  final String minAppVersion;
  final String message;

  CompatibilityResult({
    required this.compatible,
    required this.appVersion,
    required this.apiVersion,
    required this.minAppVersion,
    required this.message,
  });

  factory CompatibilityResult.fromJson(Map<String, dynamic> json) {
    return CompatibilityResult(
      compatible: json['compatible'] ?? false,
      appVersion: json['app_version'] ?? '',
      apiVersion: json['api_version'] ?? '',
      minAppVersion: json['min_app_version'] ?? '',
      message: json['message'] ?? '',
    );
  }
}

/// 最新版本信息
class LatestVersionInfo {
  final String platform;
  final String version;
  final int buildNumber;
  final String releaseDate;
  final String downloadUrl;
  final List<String> changelog;
  final String fileSize;

  LatestVersionInfo({
    required this.platform,
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.downloadUrl,
    required this.changelog,
    required this.fileSize,
  });

  factory LatestVersionInfo.fromJson(Map<String, dynamic> json) {
    return LatestVersionInfo(
      platform: json['platform'] ?? 'android',
      version: json['version'] ?? '',
      buildNumber: json['build_number'] ?? 0,
      releaseDate: json['release_date'] ?? '',
      downloadUrl: json['download_url'] ?? '',
      changelog: (json['changelog'] as List?)?.cast<String>() ?? [],
      fileSize: json['file_size'] ?? '',
    );
  }
}
