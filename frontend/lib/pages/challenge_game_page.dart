import 'package:flutter/material.dart';
import 'dart:async';
import '../services/backend_api_service.dart';
import '../services/word_audio_service.dart';
import '../utils/sound_service.dart';
import '../config/api_config.dart';
import '../widgets/acrylic_app_bar.dart';

class ChallengeGamePage extends StatefulWidget {
  final int challengeId;
  final List<dynamic> questions;

  const ChallengeGamePage({
    super.key,
    required this.challengeId,
    required this.questions,
  });

  @override
  State<ChallengeGamePage> createState() => _ChallengeGamePageState();
}

class _ChallengeGamePageState extends State<ChallengeGamePage> {
  int _currentIndex = 0;
  bool _isAnswered = false;
  String? _selectedOption;
  bool? _isCorrect;
  final TextEditingController _spellController = TextEditingController();
  
  // 计时器
  int _timeSpent = 0;
  Timer? _timer;
  
  // 结算数据
  Map<String, dynamic>? _settlementData;
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _playInitialAudio();
  }

  void _playInitialAudio() {
    final q = _currentQuestion;
    if (q['question_type'] == 'listen_choose') {
      final audioUrl = q['audio_url'];
      if (audioUrl != null) {
        final fullUrl = '${ApiConfig.apiPath}$audioUrl';
        WordAudioService.playUrl(fullUrl);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _spellController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timeSpent = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timeSpent++;
    });
  }

  Map<String, dynamic> get _currentQuestion => widget.questions[_currentIndex];

  @override
  Widget build(BuildContext context) {
    if (_settlementData != null) {
      return _buildSettlementView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0FAF9),
      appBar: AcrylicAppBar(
        title: '挑战中 (${_currentIndex + 1}/${widget.questions.length})',
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _confirmExit(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  _buildQuestionContent(),
                  const SizedBox(height: 40),
                  _buildAnswerArea(),
                ],
              ),
            ),
          ),
          if (_isAnswered) _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return LinearProgressIndicator(
      value: (_currentIndex + 1) / widget.questions.length,
      backgroundColor: Colors.grey[200],
      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C897)),
      minHeight: 6,
    );
  }

  Widget _buildQuestionContent() {
    final q = _currentQuestion;
    return Column(
      children: [
        if (q['question_type'] == 'listen_choose')
          IconButton(
            iconSize: 64,
            icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF00C897)),
            onPressed: () {
              final audioUrl = q['audio_url'];
              if (audioUrl != null) {
                final fullUrl = '${ApiConfig.apiPath}$audioUrl';
                WordAudioService.playUrl(fullUrl);
              }
              SoundService.playTapSound();
            },
          ),
        const SizedBox(height: 20),
        Text(
          q['question'] ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A535C),
          ),
        ),
        if (q['word'] != null && q['question_type'] == 'choose_meaning')
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              q['word'],
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildAnswerArea() {
    final q = _currentQuestion;
    if (q['question_type'] == 'spell_word') {
      return Column(
        children: [
          TextField(
            controller: _spellController,
            enabled: !_isAnswered,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '在这里输入单词',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (val) => _submitSpellAnswer(val),
          ),
          if (_isAnswered)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                '正确答案: ${q['correct_answer']}',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      );
    } else {
      final options = q['options'] as List<dynamic>;
      return Column(
        children: options.map((opt) {
          final isSelected = _selectedOption == opt['option'];
          Color cardColor = Colors.white;
          Color textColor = const Color(0xFF1A535C);
          
          if (_isAnswered) {
            if (opt['is_correct']) {
              cardColor = Colors.green.shade50;
              textColor = Colors.green;
            } else if (isSelected) {
              cardColor = Colors.red.shade50;
              textColor = Colors.red;
            }
          } else if (isSelected) {
            cardColor = const Color(0xFF00C897).withOpacity(0.1);
            textColor = const Color(0xFF00C897);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: _isAnswered ? null : () => _submitOptionAnswer(opt),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected || (_isAnswered && opt['is_correct'])
                        ? textColor.withOpacity(0.5)
                        : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      '${opt['option']}.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        opt['text'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (_isAnswered && opt['is_correct'])
                      const Icon(Icons.check_circle_rounded, color: Colors.green),
                    if (_isAnswered && isSelected && !opt['is_correct'])
                      const Icon(Icons.cancel_rounded, color: Colors.red),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    }
  }

  void _submitOptionAnswer(dynamic opt) async {
    setState(() {
      _isAnswered = true;
      _selectedOption = opt['option'];
      _isCorrect = opt['is_correct'];
    });
    
    if (_isCorrect!) {
      SoundService.playTapSound(); // TODO: 播放正确音效
    } else {
      SoundService.playTapSound(); // TODO: 播放错误音效
    }

    await BackendApiService.submitChallengeAnswer(
      challengeId: widget.challengeId,
      wordId: _currentQuestion['word_id'],
      userAnswer: opt['text'],
      isCorrect: _isCorrect!,
      timeSpent: _timeSpent,
    );
  }

  void _submitSpellAnswer(String val) async {
    if (val.trim().isEmpty) return;
    
    final correct = _currentQuestion['correct_answer'].toString().toLowerCase() == val.trim().toLowerCase();
    
    setState(() {
      _isAnswered = true;
      _isCorrect = correct;
    });

    await BackendApiService.submitChallengeAnswer(
      challengeId: widget.challengeId,
      wordId: _currentQuestion['word_id'],
      userAnswer: val,
      isCorrect: correct,
      timeSpent: _timeSpent,
    );
  }

  Widget _buildNextButton() {
    final isLast = _currentIndex == widget.questions.length - 1;
    return Container(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isFinishing ? null : () => _handleNext(isLast),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C897),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isFinishing 
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  isLast ? '完成挑战' : '下一题',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
        ),
      ),
    );
  }

  void _handleNext(bool isLast) async {
    SoundService.playTapSound();
    if (isLast) {
      setState(() => _isFinishing = true);
      final result = await BackendApiService.finishChallenge(widget.challengeId);
      if (!mounted) return;
      if (result != null && result['status'] == 'success') {
        setState(() {
          _settlementData = result['data'];
          _isFinishing = false;
        });
      } else {
        setState(() => _isFinishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('完成失败，请重试')),
        );
      }
    } else {
      setState(() {
        _currentIndex++;
        _isAnswered = false;
        _selectedOption = null;
        _isCorrect = null;
        _spellController.clear();
        _startTimer();
        _playInitialAudio();
      });
    }
  }

  Widget _buildSettlementView() {
    final data = _settlementData!;
    final isPassed = data['is_passed'] ?? false;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(
              isPassed ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
              size: 100,
              color: isPassed ? Colors.orange : Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              isPassed ? '闯关成功！' : '还需努力哦',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '得分: ${data['score']}',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Color(0xFF00C897)),
            ),
            const SizedBox(height: 40),
            _buildSettlementDetail('正确题目', '${data['correct_answers']}/${data['total_questions']}'),
            _buildSettlementDetail('获得积分', '+${data['points_earned'] ?? 0}'),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C897),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    '返回首页',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出挑战'),
        content: const Text('现在退出将无法获得任何积分和记录，确定退出吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
