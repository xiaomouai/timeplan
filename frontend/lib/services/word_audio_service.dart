import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/api_config.dart';

/// 单词发音服务
/// 根据平台自动选择最佳音频播放方案
class WordAudioService {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  /// 播放单词发音
  /// 
  /// [word] 要发音的单词
  /// [isUK] 是否英式发音（true=英式，false=美式）
  static Future<bool> playWordPronunciation(String word, {bool isUK = true}) async {
    try {
      await _audioPlayer.stop();
      
      final audioUrl = _getAudioUrl(word, isUK);
      await _audioPlayer.play(UrlSource(audioUrl));
      
      return true;
    } catch (e) {
      if (kIsWeb) {
        debugPrint('Web平台发音播放失败: $e');
      } else {
        debugPrint('发音播放失败: $e');
      }
      return false;
    }
  }

  /// 播放指定URL的音频
  static Future<bool> playUrl(String url) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      return true;
    } catch (e) {
      debugPrint('URL音频播放失败: $e');
      return false;
    }
  }

  /// 根据平台获取音频URL
  static String _getAudioUrl(String word, bool isUK) {
    final audioType = isUK ? '1' : '2';
    
    if (kIsWeb) {
      // Web平台使用后端代理
      return '${ApiConfig.apiPath}/audio/proxy?word=${Uri.encodeComponent(word)}&type=$audioType';
    } else {
      // 移动端/桌面端直接使用有道API
      return 'https://dict.youdao.com/dictvoice?audio=$word&type=$audioType';
    }
  }

  /// 预加载音频（可选）
  static Future<void> preloadAudio(String word, {bool isUK = true}) async {
    try {
      final audioUrl = _getAudioUrl(word, isUK);
      await _audioPlayer.setSource(UrlSource(audioUrl));
    } catch (e) {
      debugPrint('音频预加载失败: $e');
    }
  }

  /// 停止播放
  static Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('停止播放失败: $e');
    }
  }

  /// 释放资源
  static Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
    } catch (e) {
      debugPrint('释放音频资源失败: $e');
    }
  }

  /// 检查是否正在播放
  static Future<bool> isPlaying() async {
    try {
      // audioplayers 5.x 版本使用 state 属性
      return _audioPlayer.state == PlayerState.playing;
    } catch (e) {
      return false;
    }
  }

  /// 播放例句发音（使用TTS）
  /// 
  /// [text] 要发音的例句文本
  /// [isUK] 是否英式发音（true=英式，false=美式）
  static Future<bool> playSentencePronunciation(String text, {bool isUK = true}) async {
    try {
      await _audioPlayer.stop();
      
      final audioUrl = _getSentenceAudioUrl(text, isUK);
      await _audioPlayer.play(UrlSource(audioUrl));
      
      return true;
    } catch (e) {
      if (kIsWeb) {
        debugPrint('Web平台例句发音播放失败: $e');
      } else {
        debugPrint('例句发音播放失败: $e');
      }
      return false;
    }
  }

  /// 获取例句音频URL（使用后端TTS服务）
  static String _getSentenceAudioUrl(String text, bool isUK) {
    final lang = isUK ? 'en-GB' : 'en-US';
    // 使用后端TTS服务生成例句发音
    return '${ApiConfig.apiPath}/audio/tts?text=${Uri.encodeComponent(text)}&lang=$lang';
  }
}
