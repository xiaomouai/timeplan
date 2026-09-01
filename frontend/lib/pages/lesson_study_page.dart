// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word_book.dart';
import '../utils/english_word_api_service.dart';
import '../utils/deepseek_api_service.dart';
import '../utils/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../utils/performance_optimizer.dart';
import '../utils/sound_service.dart';
import '../utils/settings_helper.dart';
import '../models/pronunciation_result.dart';
import '../services/backend_api_service.dart';
import '../services/recorder_service.dart';

/// 课文学习页面 - 支持单元、句子、语音朗读
/// 数据结构: 单元(Unit) -> 句子(Sentence) -> 词汇(Word) + 语音(Audio)
class LessonStudyPage extends StatefulWidget {
  final String unitTitle;  // 单元标题，如 "Unit 1 Hello!"
  final List<SentenceContent> sentences;  // 句子列表
  final WordData? wordData;  // 关联单词数据（可选）
  final VoidCallback? onNext;

  const LessonStudyPage({
    super.key,
    required this.unitTitle,
    required this.sentences,
    this.wordData,
    this.onNext,
  });

  @override
  State<LessonStudyPage> createState() => _LessonStudyPageState();
}

/// 句子内容数据模型
class SentenceContent {
  final String english;
  final String chinese;
  final String? audioUrl;  // 语音URL（可选）

  SentenceContent({
    required this.english,
    required this.chinese,
    this.audioUrl,
  });

  factory SentenceContent.fromJson(Map<String, dynamic> json) {
    return SentenceContent(
      english: json['english'] as String? ?? '',
      chinese: json['chinese'] as String? ?? '',
      audioUrl: json['audio_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'english': english,
    'chinese': chinese,
    'audio_url': audioUrl,
  };
}

class _LessonStudyPageState extends State<LessonStudyPage> with WidgetsBindingObserver {
  late FlutterTts _flutterTts;
  int _currentSentenceIndex = 0;
  bool _isPlaying = false;
  bool _isPronouncing = false;
  double _playProgress = 0.0;
  PronunciationType _pronunciationType = PronunciationType.uk;
  bool _autoPlayPronunciation = true;
  
  // 学习进度
  int _completedCount = 0;
  List<bool> _sentenceCompleted = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTts();
    _loadSettings();
    _sentenceCompleted = List<bool>.filled(widget.sentences.length, false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flutterTts.stop();
    super.dispose();
  }

  /// 初始化文本转语音
  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [IosTextToSpeechAudioCategoryOptions.defaultToSpeaker],
      );
    }

    _flutterTts.setProgressHandler((String textKey, int start, int end, String word) {
      // 更新朗读进度
    });

    _flutterTts.setCompletionHandler(() {
      setState(() => _isPlaying = false);
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('TTS Error: $msg');
      setState(() => _isPlaying = false);
    });
  }

  /// 加载用户设置
  Future<void> _loadSettings() async {
    try {
      final pronunciation = await SettingsHelper.getPronunciationType();
      final autoPlay = await SettingsHelper.getAutoPlayPronunciation();
      
      setState(() {
        _pronunciationType = pronunciation;
        _autoPlayPronunciation = autoPlay;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// 播放英文句子
  Future<void> _playEnglishSentence() async {
    SoundService.playTapSound();
    
    if (_isPlaying) {
      await _flutterTts.stop();
      setState(() => _isPlaying = false);
      return;
    }

    final sentence = widget.sentences[_currentSentenceIndex];
    setState(() => _isPlaying = true);

    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.8);
      
      await _flutterTts.speak(sentence.english);
    } catch (e) {
      debugPrint('Error playing sentence: $e');
      setState(() => _isPlaying = false);
    }
  }

  /// 语音评测 - 用户跟读
  Future<void> _pronounceSentence() async {
    SoundService.playTapSound();

    if (_isPronouncing) {
      final path = await RecorderService.stop();
      if (mounted) setState(() => _isPronouncing = false);
      if (path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有取得录音，请重新录制')),
          );
        }
        return;
      }
      final sentence = widget.sentences[_currentSentenceIndex];
      final result = await BackendApiService.evaluatePronunciation(
        word: widget.wordData?.word ?? sentence.english,
        filePath: path,
      );
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂未获得真实发音评测，请检查登录和网络后重试')),
        );
        return;
      }
      _showPronounceResult(result);
      return;
    }

    final started = await RecorderService.start();
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法开始录音，请检查麦克风权限')),
      );
      return;
    }
    setState(() => _isPronouncing = true);
  }

  /// 显示语音评测结果
  void _showPronounceResult(PronunciationResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkCardColor
            : AppTheme.cardColor,
        title: Row(
          children: [
            Icon(
              Icons.mic_none,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            const Text('语音评测结果'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildScoreItem('流畅度', result.fluencyScore.round()),
            const SizedBox(height: 12),
            _buildScoreItem('准确度', result.accuracyScore.round()),
            const SizedBox(height: 12),
            _buildScoreItem('综合分', result.overallScore.round()),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result.feedback.isNotEmpty ? result.feedback : '评测完成',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 14,
                ),
              ),
            ),
            if (result.suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('建议：${result.suggestions.join('；')}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markSentenceComplete();
              _nextSentence();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGray,
            ),
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  /// 显示分数项目
  Widget _buildScoreItem(String label, int score) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkSecondaryTextColor
                : AppTheme.secondaryTextColor,
          ),
        ),
        Row(
          children: [
            Text(
              '$score',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: score >= 80 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              backgroundColor: Colors.grey.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                score >= 80 ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 标记句子为已完成
  void _markSentenceComplete() {
    if (!_sentenceCompleted[_currentSentenceIndex]) {
      setState(() {
        _sentenceCompleted[_currentSentenceIndex] = true;
        _completedCount++;
      });
    }
  }

  /// 下一句
  void _nextSentence() {
    if (_currentSentenceIndex < widget.sentences.length - 1) {
      setState(() => _currentSentenceIndex++);
      
      if (_autoPlayPronunciation) {
        Future.delayed(const Duration(milliseconds: 300), _playEnglishSentence);
      }
    } else {
      _showCompletionDialog();
    }
  }

  /// 上一句
  void _previousSentence() {
    if (_currentSentenceIndex > 0) {
      setState(() => _currentSentenceIndex--);
    }
  }

  /// 显示完成对话框
  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkCardColor
            : AppTheme.cardColor,
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            const Text('课文学习完成'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              '完成进度: $_completedCount/${widget.sentences.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _completedCount / widget.sentences.length,
              minHeight: 8,
              backgroundColor: Colors.grey.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '很好！你已经完成了本单元的学习。继续加油！',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              widget.onNext?.call();
            },
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkBackgroundColor
              : AppTheme.backgroundColor,
          appBar: _buildAppBar(),
          body: _buildBody(),
          bottomNavigationBar: _buildBottomBar(),
        );
      },
    );
  }

  /// 构建应用栏
  PreferredSizeWidget _buildAppBar() {
    final progress = (_currentSentenceIndex + 1) / widget.sentences.length;

    return AppBar(
      title: OptimizedText(
        widget.unitTitle,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkPrimaryTextColor
              : AppTheme.primaryTextColor,
        ),
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkBackgroundColor
          : AppTheme.backgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkPrimaryGray
              : AppTheme.primaryGray,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: OptimizedText(
              '${_currentSentenceIndex + 1}/${widget.sentences.length}',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkSecondaryTextColor
                    : AppTheme.secondaryTextColor,
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 4,
          backgroundColor: Colors.grey.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }

  /// 构建主体内容
  Widget _buildBody() {
    final sentence = widget.sentences[_currentSentenceIndex];
    final isCompleted = _sentenceCompleted[_currentSentenceIndex];

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ResponsiveHelper.getMaxContentWidth(context),
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: ResponsiveHelper.getResponsivePadding(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 状态指示
              _buildStatusIndicator(isCompleted),
              const SizedBox(height: 32),

              // 英文句子卡片
              _buildSentenceCard(
                title: '英文句子',
                content: sentence.english,
                onPlay: _playEnglishSentence,
                isPlaying: _isPlaying,
              ),
              const SizedBox(height: 24),

              // 中文翻译卡片
              _buildTranslationCard(sentence.chinese),
              const SizedBox(height: 32),

              // 语音评测按钮
              _buildPronounceButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建状态指示器
  Widget _buildStatusIndicator(bool isCompleted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.green.withOpacity(0.1)
            : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green : Colors.blue,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.info,
            color: isCompleted ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isCompleted ? '这句已完成' : '请认真学习这句话',
              style: TextStyle(
                color: isCompleted ? Colors.green : Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建句子卡片
  Widget _buildSentenceCard({
    required String title,
    required String content,
    required VoidCallback onPlay,
    required bool isPlaying,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkCardColor
            : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkSecondaryTextColor
                  : AppTheme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkPrimaryTextColor
                  : AppTheme.primaryTextColor,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onPlay,
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            label: Text(isPlaying ? '暂停' : '播放'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建翻译卡片
  Widget _buildTranslationCard(String translation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '中文意思',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            translation,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkPrimaryTextColor
                  : AppTheme.primaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建语音评测按钮
  Widget _buildPronounceButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '跟读评测',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkSecondaryTextColor
                : AppTheme.secondaryTextColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _pronounceSentence,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      _isPronouncing ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isPronouncing ? '正在录音...' : '点击开始录音',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建底部导航栏
  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkCardColor
            : AppTheme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    _currentSentenceIndex > 0 ? _previousSentence : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('上一句'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGray.withOpacity(0.5),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _nextSentence,
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  _currentSentenceIndex >= widget.sentences.length - 1
                      ? '完成'
                      : '下一句',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGray,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
