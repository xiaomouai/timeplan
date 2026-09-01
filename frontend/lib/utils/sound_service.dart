import 'package:flutter/foundation.dart';

/// 音效服务类 - 提供统一的音效播放功能
/// 注意：本地音效文件已禁用，以避免资源文件缺失错误
/// 单词发音通过后端API正常提供
class SoundService {
  /// 播放记住音效
  static void playRememberSound() async {
    // 音效已禁用 - 本地音频文件不存在
    if (kDebugMode) {
      debugPrint('音效播放（已禁用）: Remember');
    }
  }

  /// 播放忘记音效
  static void playForgotSound() async {
    // 音效已禁用 - 本地音频文件不存在
    if (kDebugMode) {
      debugPrint('音效播放（已禁用）: Forgot');
    }
  }

  /// 播放点击音效
  static void playTapSound() async {
    // 音效已禁用 - 本地音频文件不存在
    if (kDebugMode) {
      debugPrint('音效播放（已禁用）: Tap');
    }
  }

  /// 播放句子结果音效
  static void playResultSound() async {
    // 音效已禁用 - 本地音频文件不存在
    if (kDebugMode) {
      debugPrint('音效播放（已禁用）: Result');
    }
  }

  /// 播放成功音效
  static void playSuccessSound() async {
    // 音效已禁用 - 本地音频文件不存在
    if (kDebugMode) {
      debugPrint('音效播放（已禁用）: Success');
    }
  }

  /// 播放错误音效
  static void playErrorSound() async {
    // 音效已禁用 - 本地音频文件不存在
    if (kDebugMode) {
      debugPrint('音效播放（已禁用）: Error');
    }
  }

  /// 播放选择书籍音效
  static void playChooseBookSound() async {
    // 音效已禁用 - 本地音频文件不存在
    if (kDebugMode) {
      debugPrint('音效播放（已禁用）: Choose Book');
    }
  }

  /// 播放选择按钮音效
  static void playChooseButtonSound() async {
    // 音效已禁用 - 本地音频文件不存在
    if (kDebugMode) {
      debugPrint('音效播放（已禁用）: Choose Button');
    }
  }

  /// 播放下载成功音效
  static void playDownloadSuccessSound() async {
    // 音效已禁用 - 本地音频文件不存在
    if (kDebugMode) {
      debugPrint('音效播放（已禁用）: Download Success');
    }
  }

  /// 播放加载音效
  static void playLoadingSound() async {
    // 音效已禁用 - 本地音频文件不存在
    if (kDebugMode) {
      debugPrint('音效播放（已禁用）: Loading');
    }
  }

  /// 播放开关关闭音效
  static void playSwitchOffSound() async {
    // 音效已禁用 - 本地音频文件不存在
    if (kDebugMode) {
      debugPrint('音效播放（已禁用）: Switch Off');
    }
  }

  /// 播放开关开启音效
  static void playSwitchOnSound() async {
    // 音效已禁用 - 本地音频文件不存在
    if (kDebugMode) {
      debugPrint('音效播放（已禁用）: Switch On');
    }
  }

  /// 播放点击关闭音效
  static void playTapOffSound() async {
    // 音效已禁用 - 本地音频文件不存在
    if (kDebugMode) {
      debugPrint('音效播放（已禁用）: Tap Off');
    }
  }
}