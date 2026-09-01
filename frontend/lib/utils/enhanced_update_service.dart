import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/version_service.dart';
import '../widgets/update_dialog.dart';
import '../config/api_config.dart';

/// 增强的自动更新服务
/// 支持版本检查、兼容性检测和自动更新提示
class EnhancedUpdateService {
  static final EnhancedUpdateService _instance = EnhancedUpdateService._internal();
  factory EnhancedUpdateService() => _instance;
  EnhancedUpdateService._internal();

  static EnhancedUpdateService get instance => _instance;

  final VersionService _versionService = VersionService.instance;
  
  static const String _lastCheckKey = 'last_update_check_time';
  static const String _skipVersionKey = 'skip_update_version';

  bool _isChecking = false;

  /// 初始化服务
  Future<void> initialize() async {
    // 可以在这里做一些初始化工作
  }

  /// 应用启动时检查更新
  Future<void> checkOnAppStart(BuildContext context) async {
    if (!ApiConfig.enableAutoUpdateCheck) return;
    
    // 检查是否需要进行更新检查
    if (!await _shouldCheckUpdate()) {
      return;
    }

    // 延迟检查，避免影响启动速度
    await Future.delayed(const Duration(seconds: 3));
    
    if (context.mounted) {
      await checkUpdate(context, silent: true);
    }
  }

  /// 应用恢复时检查更新
  Future<void> checkOnAppResume(BuildContext context) async {
    if (!ApiConfig.enableAutoUpdateCheck) return;
    
    if (!await _shouldCheckUpdate()) {
      return;
    }

    if (context.mounted) {
      await checkUpdate(context, silent: true);
    }
  }

  /// 手动检查更新
  Future<void> checkUpdate(
    BuildContext context, {
    bool silent = false,
    bool showNoUpdate = false,
  }) async {
    if (_isChecking) return;
    
    _isChecking = true;

    try {
      // 显示加载提示（非静默模式）
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在检查更新...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // 检查更新
      final updateResult = await _versionService.checkUpdate();
      
      // 更新最后检查时间
      await _updateLastCheckTime();

      if (!context.mounted) return;

      if (updateResult.hasUpdate) {
        // 检查是否跳过此版本
        if (silent && await _isVersionSkipped(updateResult.latestVersion ?? '')) {
          return;
        }

        // 显示更新对话框
        await UpdateDialog.show(
          context,
          updateResult,
          onLater: () => _skipVersion(updateResult.latestVersion ?? ''),
        );
      } else if (showNoUpdate) {
        // 显示已是最新版本提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已是最新版本'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('检查更新失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      _isChecking = false;
    }
  }

  /// 检查兼容性
  Future<void> checkCompatibility(BuildContext context) async {
    try {
      final result = await _versionService.checkCompatibility();
      
      if (!context.mounted) return;

      if (!result.compatible) {
        await CompatibilityDialog.show(context, result);
      }
    } catch (e) {
      // 兼容性检查失败不影响应用使用
      debugPrint('兼容性检查失败: $e');
    }
  }

  /// 获取API版本信息
  Future<ApiVersionInfo?> getApiVersion() async {
    try {
      return await _versionService.getApiVersion();
    } catch (e) {
      debugPrint('获取API版本失败: $e');
      return null;
    }
  }

  /// 获取当前应用版本
  Future<AppVersionInfo> getCurrentVersion() async {
    return await _versionService.getCurrentVersion();
  }

  /// 是否应该检查更新
  Future<bool> _shouldCheckUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // 检查间隔（小时转毫秒）
    final interval = ApiConfig.versionCheckInterval * 60 * 60 * 1000;
    
    return (now - lastCheck) > interval;
  }

  /// 更新最后检查时间
  Future<void> _updateLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// 跳过某个版本
  Future<void> _skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skipVersionKey, version);
  }

  /// 检查版本是否被跳过
  Future<bool> _isVersionSkipped(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final skippedVersion = prefs.getString(_skipVersionKey);
    return skippedVersion == version;
  }

  /// 清除跳过的版本
  Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_skipVersionKey);
  }

  /// 释放资源
  void dispose() {
    // 清理资源
  }
}
