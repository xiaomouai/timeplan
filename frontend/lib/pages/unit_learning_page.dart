import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word_book.dart';
import '../utils/english_word_api_service.dart';
import 'home/controllers/word_learning_controller.dart';
import '../utils/sound_service.dart';
import '../services/word_audio_service.dart';
import '../services/backend_api_service.dart';
import '../services/recorder_service.dart';
import 'ai_chat_page.dart';

class PhonicsChunk {
  final String text;
  final String kind;
  PhonicsChunk({required this.text, required this.kind});
}

class PhonicsSyllable {
  final List<PhonicsChunk> chunks;
  PhonicsSyllable(this.chunks);
  String get text => chunks.map((e) => e.text).join();
}

class PhonicsAnalysis {
  final List<PhonicsChunk> chunks;
  final List<PhonicsSyllable> syllables;
  final List<String> vowelTeams;
  final List<String> rControlled;
  final bool silentE;
  PhonicsAnalysis({
    required this.chunks,
    required this.syllables,
    required this.vowelTeams,
    required this.rControlled,
    required this.silentE,
  });
}

class PhonicsAnalyzer {
  static final Set<String> vowels = {'a', 'e', 'i', 'o', 'u'};
  static final List<String> vowelTeams = [
    'igh','ee','ea','ai','ay','oa','oe','ie','ei','oi','oy','au','aw','ou','ow','oo'
  ];
  static final List<String> rControlled = ['ar','er','ir','or','ur'];
  static final List<String> consDigraphs = ['sh','ch','th','ph','wh','ck','qu','ng'];

  static PhonicsAnalysis analyze(String word) {
    final lower = word.toLowerCase();
    final chunks = _chunk(lower);
    final silentE = _detectSilentE(lower);
    final nucleiIdx = <int>[];
    for (var i = 0; i < chunks.length; i++) {
      final k = chunks[i].kind;
      if (k == 'V' || k == 'VT' || k == 'RC') nucleiIdx.add(i);
    }
    final syllables = <PhonicsSyllable>[];
    if (nucleiIdx.isEmpty) {
      syllables.add(PhonicsSyllable(chunks));
    } else {
      var start = 0;
      for (var n = 0; n < nucleiIdx.length; n++) {
        if (n == nucleiIdx.length - 1) {
          syllables.add(PhonicsSyllable(chunks.sublist(start)));
        } else {
          final ni = nucleiIdx[n];
          final nj = nucleiIdx[n + 1];
          if (nj - ni == 2) {
            syllables.add(PhonicsSyllable(chunks.sublist(start, nj)));
            start = nj;
          } else if (nj - ni >= 3) {
            final split = ni + 2;
            syllables.add(PhonicsSyllable(chunks.sublist(start, split)));
            start = split;
          } else {
            syllables.add(PhonicsSyllable(chunks.sublist(start, nj)));
            start = nj;
          }
        }
      }
    }
    final vtFound = <String>[];
    final rcFound = <String>[];
    for (final c in chunks) {
      if (c.kind == 'VT' && !vtFound.contains(c.text)) vtFound.add(c.text);
      if (c.kind == 'RC' && !rcFound.contains(c.text)) rcFound.add(c.text);
    }
    return PhonicsAnalysis(
      chunks: chunks,
      syllables: syllables,
      vowelTeams: vtFound,
      rControlled: rcFound,
      silentE: silentE,
    );
  }

  static bool _isVowelChar(String ch) {
    if (vowels.contains(ch)) return true;
    return ch == 'y';
  }

  static bool _detectSilentE(String w) {
    if (w.length < 3) return false;
    if (!w.endsWith('e')) return false;
    final beforeE = w.substring(0, w.length - 1);
    final last = beforeE.isNotEmpty ? beforeE[beforeE.length - 1] : '';
    final hasVowel = beforeE.split('').any((c) => _isVowelChar(c));
    if (last.isEmpty) return false;
    final isCons = !vowels.contains(last);
    return hasVowel && isCons;
  }

  static List<PhonicsChunk> _chunk(String w) {
    final list = <PhonicsChunk>[];
    var i = 0;
    while (i < w.length) {
      final remain = w.substring(i);
      var matched = false;
      if (i <= w.length - 3) {
        final tri = w.substring(i, i + 3);
        if (tri == 'igh') {
          list.add(PhonicsChunk(text: tri, kind: 'VT'));
          i += 3;
          matched = true;
        }
      }
      if (matched) continue;
      if (i <= w.length - 2) {
        final bi = w.substring(i, i + 2);
        if (rControlled.contains(bi)) {
          list.add(PhonicsChunk(text: bi, kind: 'RC'));
          i += 2;
          continue;
        }
        if (vowelTeams.contains(bi)) {
          list.add(PhonicsChunk(text: bi, kind: 'VT'));
          i += 2;
          continue;
        }
        if (consDigraphs.contains(bi)) {
          list.add(PhonicsChunk(text: bi, kind: 'C'));
          i += 2;
          continue;
        }
      }
      final ch = w[i];
      if (i == w.length - 1 && ch == 'e' && _detectSilentE(w)) {
        list.add(PhonicsChunk(text: ch, kind: 'SE'));
      } else if (_isVowelChar(ch)) {
        list.add(PhonicsChunk(text: ch, kind: 'V'));
      } else {
        list.add(PhonicsChunk(text: ch, kind: 'C'));
      }
      i += 1;
    }
    return list;
  }
}

class UnitLearningPage extends StatefulWidget {
  const UnitLearningPage({super.key});

  @override
  State<UnitLearningPage> createState() => _UnitLearningPageState();
}

class _UnitLearningPageState extends State<UnitLearningPage> {
  FlutterTts? _flutterTts;
  int _currentStep = 0; // 0:学, 1:读, 2:练, 3:拼, 4:写
  final List<String> _steps = ['学', '读', '练', '拼', '写'];

  // State for Read Step
  bool _isRecording = false;

  // State for Practice Step
  List<String>? _practiceOptions;
  int? _correctOptionIndex;
  int? _selectedOptionIndex;
  bool _isPracticeAnswered = false;

  // State for Spell Step
  List<String> _shuffledLetters = [];
  List<String> _filledSlots = [];
  
  // State for Write Step
  final TextEditingController _writeController = TextEditingController();
  bool _isWriteCorrect = false;
  bool _isWriteChecked = false;

  int? _syllableQuizChoice;
  bool _syllableQuizChecked = false;
  String? _vowelTeamQuizChoice;
  bool _vowelTeamQuizChecked = false;
  bool _syllableMode = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }
  
  @override
  void dispose() {
    _writeController.dispose();
    super.dispose();
  }

  void _initTts() {
    _flutterTts = FlutterTts();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WordLearningController>(
      builder: (context, controller, child) {
        final unitIndex = controller.currentUnitIndex ?? 0;
        final words = controller.learningQueue;
        final currentWord = controller.currentWord;
        final currentIndex = controller.currentIndex;

        if (controller.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (words.isEmpty || currentWord == null) {
          return Scaffold(
            appBar: AppBar(title: Text('Unit ${unitIndex + 1}')),
            body: const Center(child: Text('暂无数据')),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: _buildAppBar(context, unitIndex),
          body: Column(
            children: [
              _buildTopWordList(words, currentIndex, controller),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildMainCard(controller, currentWord),
                ),
              ),
              _buildBottomBar(controller, currentIndex, words.length),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, int unitIndex) {
    return AppBar(
      backgroundColor: const Color(0xFFF5F7FA),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Unit ${unitIndex + 1}',
        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.black87),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildTopWordList(List<WordData> words, int currentIndex, WordLearningController controller) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: words.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final isSelected = index == currentIndex;
          return GestureDetector(
            onTap: () {
              SoundService.playTapSound();
              controller.jumpToWord(index);
              WordAudioService.playWordPronunciation(words[index].word);
              setState(() {
                _currentStep = 0;
                _resetStepState();
              });
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    words[index].word,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF00C897) : Colors.grey.shade400,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      height: 2,
                      width: 20,
                      color: const Color(0xFF00C897),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainCard(WordLearningController controller, WordDetailResponse currentWord) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildProgressSteps(),
          const SizedBox(height: 32),
          _buildStepContent(controller, currentWord),
        ],
      ),
    );
  }

  Widget _buildStepContent(WordLearningController controller, WordDetailResponse currentWord) {
    switch (_currentStep) {
      case 0: // 学
        return _buildStudyStep(controller, currentWord);
      case 1: // 读
        return _buildReadStep(currentWord);
      case 2: // 练
        return _buildPracticeStep(controller, currentWord);
      case 3: // 拼
        return _buildSpellStep(currentWord);
      case 4: // 写
        return _buildWriteStep(currentWord);
      default:
        return _buildStudyStep(controller, currentWord);
    }
  }

  Widget _buildStudyStep(WordLearningController controller, WordDetailResponse currentWord) {
    return Column(
      children: [
        _buildWordDisplay(controller, currentWord),
        const SizedBox(height: 16),
        _buildPhonetic(currentWord),
        const SizedBox(height: 16),
        _buildPhonicsSection(currentWord.word),
        const SizedBox(height: 24),
        _buildMeaning(currentWord),
        // const SizedBox(height: 32),
        // _buildSpellingGrid(currentWord.word),
        const SizedBox(height: 32),
        _buildExampleSentence(currentWord),
        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 16),
        _buildActionRow(controller, currentWord),
      ],
    );
  }

  Widget _buildReadStep(WordDetailResponse currentWord) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          currentWord.word,
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 16),
        _buildPhonetic(currentWord),
        const SizedBox(height: 48),
        GestureDetector(
          onLongPressStart: (_) async {
            final started = await RecorderService.start();
            if (!mounted) return;
            if (!started) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('无法开始录音，请检查麦克风权限')),
              );
              return;
            }
            setState(() => _isRecording = true);
          },
          onLongPressEnd: (_) async {
            if (!_isRecording) return;
            setState(() => _isRecording = false);
            final path = await RecorderService.stop();
            if (path != null) await _onPronunciationEvaluate(currentWord, path);
          },
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _isRecording ? const Color(0xFF00C897) : const Color(0xFF00C897).withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: _isRecording ? [
                BoxShadow(color: const Color(0xFF00C897).withOpacity(0.4), blurRadius: 20, spreadRadius: 5)
              ] : [],
            ),
            child: Icon(
              Icons.mic_rounded, 
              size: 64, 
              color: _isRecording ? Colors.white : const Color(0xFF00C897),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _isRecording ? '松开结束' : '按住录音',
          style: TextStyle(
            color: _isRecording ? const Color(0xFF00C897) : Colors.grey, 
            fontSize: 16,
            fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Future<void> _onPronunciationEvaluate(WordDetailResponse currentWord, String filePath) async {
    try {
      final queue = context.read<WordLearningController>().learningQueue;
      final idx = context.read<WordLearningController>().currentIndex;
      WordData? wordData;
      if (queue.isNotEmpty && idx >= 0 && idx < queue.length) {
        wordData = queue[idx];
      }

      final result = await BackendApiService.evaluatePronunciation(
        word: currentWord.word,
        filePath: filePath,
        bookId: wordData?.bookId,
        wordRank: wordData?.wordRank,
      );
      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂未获得真实发音评测，请检查登录和网络后重试')),
          );
        }
        return;
      }
      final score = result.overallScore.round();
      final isCorrect = result.isCorrect;

      if (wordData?.bookId != null && wordData?.wordRank != null) {
        await BackendApiService.updateWordLearning(
          bookId: wordData!.bookId!,
          wordRank: wordData.wordRank!,
          action: 'read',
          score: score,
          isCorrect: isCorrect,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发音评分: $score 分'), duration: const Duration(seconds: 1)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发音评分出错: $e'), duration: const Duration(seconds: 1)),
      );
    }
  }

  Widget _buildPracticeStep(WordLearningController controller, WordDetailResponse currentWord) {
    // Initialize options if not already done
    if (_practiceOptions == null) {
      // Mock options logic
      final correctMeaning = currentWord.translations.isNotEmpty 
          ? '${currentWord.translations[0].pos}. ${currentWord.translations[0].tranCn}' 
          : '未知含义';
      
      _practiceOptions = [
        correctMeaning,
        'n. 错误的选项一',
        'adj. 错误的选项二',
        'v. 错误的选项三',
      ]..shuffle(); // Ideally use real distractors from other words
      
      _correctOptionIndex = _practiceOptions!.indexOf(correctMeaning);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            currentWord.word,
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          '请选择正确的含义：',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ...List.generate(4, (index) {
          final isSelected = _selectedOptionIndex == index;
          final isCorrect = index == _correctOptionIndex;
          
          Color bgColor = Colors.white;
          Color borderColor = Colors.grey.shade300;
          Color textColor = Colors.black87;
          IconData? icon;
          
          if (_isPracticeAnswered) {
            if (isCorrect) {
              bgColor = const Color(0xFFE8F5E9); // Green tint
              borderColor = const Color(0xFF00C897);
              textColor = const Color(0xFF00C897);
              icon = Icons.check_circle;
            } else if (isSelected) {
              bgColor = const Color(0xFFFFEBEE); // Red tint
              borderColor = Colors.red;
              textColor = Colors.red;
              icon = Icons.cancel;
            }
          } else if (isSelected) {
             borderColor = const Color(0xFF00C897);
          }

          return GestureDetector(
            onTap: _isPracticeAnswered ? null : () {
              setState(() {
                _selectedOptionIndex = index;
                _isPracticeAnswered = true;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _practiceOptions![index],
                      style: TextStyle(fontSize: 16, color: textColor),
                    ),
                  ),
                  if (icon != null)
                    Icon(icon, color: textColor),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSpellStep(WordDetailResponse currentWord) {
    final correctWord = currentWord.word;
    final letters = correctWord.split('');
    
    if (_shuffledLetters.isEmpty) {
      _shuffledLetters = List.from(letters)..shuffle();
      _filledSlots = List.filled(letters.length, '');
    }

    return Column(
      children: [
        _buildMeaning(currentWord),
        const SizedBox(height: 32),
        Wrap(
          spacing: 8,
          children: List.generate(letters.length, (index) {
            final filledChar = _filledSlots[index];
            final isFilled = filledChar.isNotEmpty;
            final isCorrect = isFilled && filledChar == letters[index];
            
            return GestureDetector(
              onTap: () {
                if (isFilled) {
                  setState(() {
                    _filledSlots[index] = '';
                  });
                }
              },
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isFilled ? (isCorrect ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE)) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFilled ? (isCorrect ? const Color(0xFF00C897) : Colors.red) : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  filledChar,
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold,
                    color: isFilled ? (isCorrect ? const Color(0xFF00C897) : Colors.red) : Colors.black,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _shuffledLetters.map((l) {
            // Count how many times this letter is needed vs used
            final neededCount = letters.where((c) => c == l).length;
            final usedCount = _filledSlots.where((c) => c == l).length;
            final isExhausted = usedCount >= neededCount;

            return GestureDetector(
              onTap: isExhausted ? null : () {
                // Find first empty slot
                final emptyIndex = _filledSlots.indexOf('');
                if (emptyIndex != -1) {
                  setState(() {
                    _filledSlots[emptyIndex] = l;
                  });
                }
              },
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isExhausted ? Colors.grey.shade200 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isExhausted ? [] : [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                child: Text(
                  l,
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold,
                    color: isExhausted ? Colors.grey : const Color(0xFF2C3E50),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWriteStep(WordDetailResponse currentWord) {
    return Column(
      children: [
        _buildMeaning(currentWord),
        const SizedBox(height: 32),
        TextField(
          controller: _writeController,
          decoration: InputDecoration(
            hintText: '请输入单词',
            filled: true,
            fillColor: _isWriteChecked 
                ? (_isWriteCorrect ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE))
                : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: _isWriteChecked 
                ? Icon(
                    _isWriteCorrect ? Icons.check_circle : Icons.error,
                    color: _isWriteCorrect ? const Color(0xFF00C897) : Colors.red,
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          onSubmitted: (_) => _checkWriteAnswer(currentWord),
        ),
        const SizedBox(height: 24),
        if (!_isWriteChecked)
          ElevatedButton(
            onPressed: () => _checkWriteAnswer(currentWord),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C897),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
            ),
            child: const Text('检查', style: TextStyle(fontSize: 16)),
          ),
        if (_isWriteChecked && !_isWriteCorrect)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              '正确答案: ${currentWord.word}',
              style: const TextStyle(color: Color(0xFF00C897), fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  void _checkWriteAnswer(WordDetailResponse currentWord) {
    if (_writeController.text.trim().isEmpty) return;
    
    setState(() {
      _isWriteChecked = true;
      _isWriteCorrect = _writeController.text.trim().toLowerCase() == currentWord.word.toLowerCase();
    });
  }

  Widget _buildProgressSteps() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_steps.length, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;
        
        return Expanded(
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _currentStep = index;
                    _resetStepState();
                  });
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFFFB74D) : (isCompleted ? const Color(0xFF00C897) : Colors.transparent),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive || isCompleted ? Colors.transparent : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isActive || isCompleted 
                    ? Text(
                        _steps[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Text(
                        _steps[index],
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                ),
              ),
              if (index != _steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted ? const Color(0xFF00C897).withOpacity(0.5) : Colors.grey.shade100,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  void _resetStepState() {
    // Reset transient state when switching steps manually or automatically
    _isPracticeAnswered = false;
    _selectedOptionIndex = null;
    _practiceOptions = null;
    
    _shuffledLetters = [];
    _filledSlots = [];
    
    _writeController.clear();
    _isWriteChecked = false;
    _isWriteCorrect = false;
    _syllableQuizChoice = null;
    _syllableQuizChecked = false;
    _vowelTeamQuizChoice = null;
    _vowelTeamQuizChecked = false;
  }

  Widget _buildWordDisplay(WordLearningController controller, dynamic currentWord) {
    final syllables = controller.currentSyllables?.syllables ?? [];
    
    if (syllables.isNotEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: syllables.map((s) {
          // Simple heuristic for coloring: highlight vowels or stressed syllables
          // For now, just alternating or using specific logic if available
          // Screenshot shows 'he' black, 'l' green, 'lo' black? No, 'h' black 'e' green 'l' black 'l' black 'o' green?
          // Actually looks like 'h' 'e'(green) 'l' 'l' 'o'(green)
          // Let's just color vowels green for visual similarity
          final isVowel = RegExp(r'[aeiouAEIOU]').hasMatch(s.text);
          return Text(
            s.text,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: isVowel ? const Color(0xFF00C897) : const Color(0xFF2C3E50),
              letterSpacing: 1,
            ),
          );
        }).toList(),
      );
    }

    return Text(
      currentWord.word,
      style: const TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2C3E50),
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildPhonetic(dynamic currentWord) {
    return GestureDetector(
      onTap: () => WordAudioService.playWordPronunciation(currentWord.word),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '/${currentWord.usPhone}/', // Using US phone as default
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF00C897),
                fontFamily: 'Arial', // Ensure phonetic support
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.volume_up_rounded, color: Color(0xFF00C897), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMeaning(dynamic currentWord) {
    // Assuming currentWord has translations list
    final translations = currentWord.translations;
    if (translations == null || translations.isEmpty) return const SizedBox();

    return Column(
      children: translations.map<Widget>((t) {
        return Text(
          '${t.pos}. ${t.tranCn}',
          style: const TextStyle(fontSize: 16, color: Color(0xFF4A4A4A), height: 1.5),
          textAlign: TextAlign.center,
        );
      }).toList(),
    );
  }

  // Widget _buildSpellingGrid(String word) {
  //   final letters = word.split('');
  //   return Column(
  //     children: [
  //       Wrap(
  //         spacing: 8,
  //         runSpacing: 8,
  //         children: letters.map((l) {
  //           // Mocking the colored tiles
  //           final color = _getLetterColor(l);
  //           return Container(
  //             width: 40,
  //             height: 40,
  //             alignment: Alignment.center,
  //             decoration: BoxDecoration(
  //               color: Colors.white,
  //               borderRadius: BorderRadius.circular(8),
  //               border: Border.all(color: color.withOpacity(0.3)),
  //               boxShadow: [
  //                 BoxShadow(color: color.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
  //               ],
  //             ),
  //             child: Text(
  //               l,
  //               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
  //             ),
  //           );
  //         }).toList(),
  //       ),
  //       const SizedBox(height: 12),
  //       // Phonetic tiles row (mockup)
  //       Wrap(
  //         spacing: 8,
  //         children: letters.map((l) {
  //           return Container(
  //             width: 40,
  //             height: 40,
  //             alignment: Alignment.center,
  //             decoration: BoxDecoration(
  //               color: const Color(0xFFF5F7FA),
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //             child: Text(
  //               _getMockPhoneme(l), // Mock phoneme
  //               style: const TextStyle(fontSize: 14, color: Colors.grey),
  //             ),
  //           );
  //         }).toList(),
  //       ),
  //       const SizedBox(height: 8),
  //       Row(
  //         mainAxisAlignment: MainAxisAlignment.end,
  //         children: const [
  //           Icon(Icons.hub, size: 16, color: Color(0xFF00C897)),
  //           SizedBox(width: 4),
  //           Text('联动', style: TextStyle(fontSize: 12, color: Colors.grey)),
  //         ],
  //       ),
  //     ],
  //   );
  // }

  Color _getLetterColor(String letter) {
    // Mock logic for colors
    if ('helo'.contains(letter)) {
       if (letter == 'h') return const Color(0xFFFFB74D);
       if (letter == 'e') return const Color(0xFF00C897);
       if (letter == 'o') return const Color(0xFF00C897);
    }
    return Colors.grey.shade400;
  }

  String _getMockPhoneme(String letter) {
    // Just for visual similarity
    if (letter == 'h') return '/h/';
    if (letter == 'e') return '/ə/';
    if (letter == 'l') return '//';
    if (letter == 'o') return '/əʊ/';
    return '';
  }

  Widget _buildPhonicsSection(String word) {
    final analysis = PhonicsAnalyzer.analyze(word);
    final syllableCount = analysis.syllables.length;
    final segmented = analysis.syllables.map((s) => s.text).join(' - ');
    final hasVt = analysis.vowelTeams.isNotEmpty;
    final vt = hasVt ? analysis.vowelTeams.first : null;
    final vtOptions = <String>[];
    if (vt != null) {
      vtOptions.add(vt);
      for (final cand in ['ai','ea','ee','oa','ou','ow','oo','ie','oy']) {
        if (!vtOptions.contains(cand) && word.contains(cand)) vtOptions.add(cand);
      }
      for (final cand in ['ai','ea','ee','oa','ou','ow','oo','ie','oy']) {
        if (!vtOptions.contains(cand)) vtOptions.add(cand);
        if (vtOptions.length >= 4) break;
      }
      vtOptions.shuffle();
    }
    final ipaBySyllable = analysis.syllables.map((syl) {
      final p = syl.chunks.map(_phonemeForChunk).where((e) => e.isNotEmpty).join('');
      return p;
    }).where((e) => e.isNotEmpty).toList();
    final ipaDisplay =
        ipaBySyllable.isNotEmpty ? '/${ipaBySyllable.join(' ')}/' : '';
    final colors = analysis.chunks.map((c) {
      if (c.kind == 'V') return const Color(0xFF00C897);
      if (c.kind == 'VT') return const Color(0xFFFFB74D);
      if (c.kind == 'RC') return const Color(0xFF42A5F5);
      if (c.kind == 'SE') return Colors.grey;
      return const Color(0xFF2C3E50);
    }).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('自然拼读'),
                selected: !_syllableMode,
                onSelected: (v) {
                  setState(() {
                    _syllableMode = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('音节拆分'),
                selected: _syllableMode,
                onSelected: (v) {
                  setState(() {
                    _syllableMode = true;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_syllableMode)
            Center(
              child: Text(
                word,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                  letterSpacing: 1,
                ),
              ),
            ),
          if (!_syllableMode) const SizedBox(height: 8),
          Visibility(
            visible: _syllableMode,
            child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: analysis.syllables.map((syl) {
              final t = syl.text;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE4B2)),
                ),
                child: RichText(
                  text: TextSpan(
                    children: t.split('').map((ch) {
                      final isV = PhonicsAnalyzer.vowels.contains(ch.toLowerCase());
                      return TextSpan(
                        text: ch,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isV ? const Color(0xFF00C897) : const Color(0xFF2C3E50),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            }).toList(),
          )),
          const SizedBox(height: 8),
          if (!_syllableMode && ipaDisplay.isNotEmpty)
            Center(
              child: GestureDetector(
                onTap: () => _speakPhonemeSequence(analysis),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ipaDisplay,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF00C897),
                          fontFamily: 'Arial',
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.volume_up_rounded, color: Color(0xFF00C897), size: 20),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Visibility(
            visible: !_syllableMode,
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: List.generate(analysis.chunks.length, (i) {
                final c = analysis.chunks[i];
                final color = colors[i];
                return GestureDetector(
                  onTap: () => _speakChunk(c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Text(
                      c.text,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Visibility(
            visible: !_syllableMode,
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: analysis.chunks.map((c) {
                final p = _phonemeForChunk(c);
                return GestureDetector(
                  onTap: () => _speakChunk(c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F3F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      p.isEmpty ? '/·/' : '/$p/',
                      style: const TextStyle(
                        color: Color(0xFF607D8B),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // const SizedBox(height: 10),
          // Row(
          //   children: [
          //     Expanded(
          //       child: Text(
          //         segmented,
          //         style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
          //       ),
          //     ),
          //     Text('$syllableCount 音节', style: const TextStyle(color: Colors.grey)),
          //   ],
          // ),
          // const SizedBox(height: 10),
          // Row(
          //   children: [
          //     ElevatedButton(
          //       onPressed: () => _speakSegmented(analysis),
          //       style: ElevatedButton.styleFrom(
          //         backgroundColor: const Color(0xFF00C897),
          //         foregroundColor: Colors.white,
          //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          //       ),
          //       child: const Text('分段读'),
          //     ),
          //     const SizedBox(width: 12),
          //     OutlinedButton(
          //       onPressed: () => WordAudioService.playWordPronunciation(word),
          //       style: OutlinedButton.styleFrom(
          //         foregroundColor: const Color(0xFF00C897),
          //         side: const BorderSide(color: Color(0xFF00C897)),
          //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          //       ),
          //       child: const Text('连读'),
          //     ),
          //   ],
          // ),
          // const SizedBox(height: 12),
          // Container(height: 1, color: Colors.grey.shade300),
          // const SizedBox(height: 12),
          // Row(
          //   children: [
          //     Expanded(
          //       child: Column(
          //         crossAxisAlignment: CrossAxisAlignment.start,
          //         children: [
          //           const Text('音节数', style: TextStyle(fontWeight: FontWeight.bold)),
          //           const SizedBox(height: 8),
          //           Wrap(
          //             spacing: 8,
          //             children: List.generate(4, (i) {
          //               final val = i + 1;
          //               final selected = _syllableQuizChoice == val;
          //               Color bg = Colors.white;
          //               Color bd = Colors.grey.shade300;
          //               if (_syllableQuizChecked) {
          //                 if (val == syllableCount) {
          //                   bg = const Color(0xFFE8F5E9);
          //                   bd = const Color(0xFF00C897);
          //                 } else if (selected) {
          //                   bg = const Color(0xFFFFEBEE);
          //                   bd = Colors.red;
          //                 }
          //               } else if (selected) {
          //                 bd = const Color(0xFF00C897);
          //               }
          //               return GestureDetector(
          //                 onTap: _syllableQuizChecked ? null : () {
          //                   setState(() {
          //                     _syllableQuizChoice = val;
          //                   });
          //                 },
          //                 child: Container(
          //                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          //                   decoration: BoxDecoration(
          //                     color: bg,
          //                     borderRadius: BorderRadius.circular(12),
          //                     border: Border.all(color: bd),
          //                   ),
          //                   child: Text('$val'),
          //                 ),
          //               );
          //             }),
          //           ),
          //           const SizedBox(height: 8),
          //           Align(
          //             alignment: Alignment.centerLeft,
          //             child: TextButton(
          //               onPressed: () {
          //                 setState(() {
          //                   _syllableQuizChecked = true;
          //                 });
          //               },
          //               child: const Text('检查'),
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //     const SizedBox(width: 12),
          //     Expanded(
          //       child: Column(
          //         crossAxisAlignment: CrossAxisAlignment.start,
          //         children: [
          //           const Text('元音组合', style: TextStyle(fontWeight: FontWeight.bold)),
          //           const SizedBox(height: 8),
          //           if (vt != null)
          //             Wrap(
          //               spacing: 8,
          //               children: vtOptions.map((opt) {
          //                 final selected = _vowelTeamQuizChoice == opt;
          //                 Color bg = Colors.white;
          //                 Color bd = Colors.grey.shade300;
          //                 if (_vowelTeamQuizChecked) {
          //                   if (opt == vt) {
          //                     bg = const Color(0xFFE8F5E9);
          //                     bd = const Color(0xFF00C897);
          //                   } else if (selected) {
          //                     bg = const Color(0xFFFFEBEE);
          //                     bd = Colors.red;
          //                   }
          //                 } else if (selected) {
          //                   bd = const Color(0xFF00C897);
          //                 }
          //                 return GestureDetector(
          //                   onTap: _vowelTeamQuizChecked ? null : () {
          //                     setState(() {
          //                       _vowelTeamQuizChoice = opt;
          //                     });
          //                   },
          //                   child: Container(
          //                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          //                     decoration: BoxDecoration(
          //                       color: bg,
          //                       borderRadius: BorderRadius.circular(12),
          //                       border: Border.all(color: bd),
          //                     ),
          //                     child: Text(opt),
          //                   ),
          //                 );
          //               }).toList(),
          //             )
          //           else
          //             const Text('无明显元音组合', style: TextStyle(color: Colors.grey)),
          //           const SizedBox(height: 8),
          //           Align(
          //             alignment: Alignment.centerLeft,
          //             child: TextButton(
          //               onPressed: () {
          //                 setState(() {
          //                   _vowelTeamQuizChecked = true;
          //                 });
          //               },
          //               child: const Text('检查'),
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ],
          // ),
          // const SizedBox(height: 8),
          // if (analysis.silentE)
          //   Row(
          //     children: const [
          //       Icon(Icons.info_outline, size: 16, color: Colors.grey),
          //       SizedBox(width: 6),
          //       Text('含无声 e', style: TextStyle(color: Colors.grey)),
          //     ],
          //   ),
        ],
      ),
    );
  }

  Future<void> _speakSegmented(PhonicsAnalysis analysis) async {
    if (_flutterTts == null) return;
    await _flutterTts!.setSpeechRate(0.3);
    for (final syl in analysis.syllables) {
      await _flutterTts!.speak(syl.text);
      await Future.delayed(const Duration(milliseconds: 400));
    }
    await _flutterTts!.setSpeechRate(0.5);
  }

  Future<void> _speakChunk(PhonicsChunk c) async {
    if (_flutterTts == null) return;
    final text = c.text;
    var toSpeak = text;
    if (c.kind == 'SE') return;
    if (c.kind == 'RC') {
      toSpeak = text.replaceFirst('r', 'r ');
    }
    await _flutterTts!.setSpeechRate(0.35);
    await _flutterTts!.speak(toSpeak);
    await _flutterTts!.setSpeechRate(0.5);
  }

  Future<void> _speakPhonemeSequence(PhonicsAnalysis analysis) async {
    for (final c in analysis.chunks) {
      await _speakChunk(c);
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  String _phonemeForChunk(PhonicsChunk c) {
    final t = c.text;
    if (c.kind == 'SE') return '';
    if (c.kind == 'RC') {
      if (t == 'ar') return 'ɑːr';
      if (t == 'er' || t == 'ir' || t == 'ur') return 'ɜːr';
      if (t == 'or') return 'ɔːr';
    }
    if (c.kind == 'VT') {
      if (t == 'igh') return 'aɪ';
      if (t == 'ai' || t == 'ay') return 'eɪ';
      if (t == 'ea' || t == 'ee') return 'iː';
      if (t == 'ie') return 'aɪ';
      if (t == 'oa' || t == 'oe') return 'oʊ';
      if (t == 'oi' || t == 'oy') return 'ɔɪ';
      if (t == 'au' || t == 'aw') return 'ɔː';
      if (t == 'ou' || t == 'ow') return 'aʊ';
      if (t == 'oo') return 'uː';
    }
    if (c.kind == 'C') {
      if (t == 'sh') return 'ʃ';
      if (t == 'ch') return 'tʃ';
      if (t == 'th') return 'θ';
      if (t == 'ph') return 'f';
      if (t == 'wh') return 'w';
      if (t == 'ck') return 'k';
      if (t == 'qu') return 'kw';
      if (t == 'ng') return 'ŋ';
      if (t == 'c') return 'k';
      if (t == 'g') return 'g';
      return t;
    }
    if (c.kind == 'V') {
      if (t == 'a') return 'æ';
      if (t == 'e') return 'e';
      if (t == 'i') return 'ɪ';
      if (t == 'o') return 'ɒ';
      if (t == 'u') return 'ʌ';
      if (t == 'y') return 'i';
    }
    return t;
  }

  Widget _buildExampleSentence(WordDetailResponse currentWord) {
    if (currentWord.sentences == null || currentWord.sentences.isEmpty) {
      return const SizedBox();
    }
    final sentence = currentWord.sentences[0];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            sentence.sContent,
            style: const TextStyle(fontSize: 16, color: Color(0xFF2C3E50), height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            sentence.sCn,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSentenceControl(Icons.volume_up_rounded, () {
                // Play sentence audio
                 // Using TTS for now if url is empty
                 if (_flutterTts != null) {
                   _flutterTts!.speak(sentence.sContent);
                 }
              }),
              const SizedBox(width: 16),
              _buildSentenceControl(Icons.catching_pokemon, () { // Turtle icon approximation
                 if (_flutterTts != null) {
                   _flutterTts!.setSpeechRate(0.2);
                   _flutterTts!.speak(sentence.sContent);
                   _flutterTts!.setSpeechRate(0.5); // Reset
                 }
              }),
              const SizedBox(width: 16),
              _buildSentenceControl(Icons.mic_none_rounded, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceControl(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF00C897)),
      ),
    );
  }

  Widget _buildActionRow(WordLearningController controller, WordDetailResponse currentWord) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionItem(
          controller.isCurrentFavorited ? Icons.star_rounded : Icons.star_border_rounded,
          '收藏',
          () async {
            SoundService.playTapSound();
            await controller.toggleFavorite();
            final favorited = controller.isCurrentFavorited;
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(favorited ? '已加入生词本' : '已取消收藏'), duration: const Duration(seconds: 1)),
            );
          },
          color: controller.isCurrentFavorited ? const Color(0xFFFFC107) : Colors.grey.shade600,
        ),
        _buildActionItem(
          controller.isCurrentMastered ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
          '掌握',
          () async {
            SoundService.playTapSound();
            await controller.markAsMasteredAndStay();
            if (!mounted) return;
            if (controller.isCurrentMastered) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已标记为掌握'), duration: Duration(seconds: 1)),
              );
            }
          },
          color: controller.isCurrentMastered ? const Color(0xFF00C897) : Colors.grey.shade600,
        ),
        _buildActionItem(
          Icons.help_outline_rounded,
          '详解',
          () async {
            SoundService.playTapSound();
            controller.toggleMeaning();

            WordData? wordData;
            final queue = controller.learningQueue;
            final idx = controller.currentIndex;
            if (queue.isNotEmpty && idx >= 0 && idx < queue.length) {
              wordData = queue[idx];
            }

            if (wordData?.bookId != null && wordData?.wordRank != null) {
              BackendApiService.updateWordLearning(
                bookId: wordData!.bookId!,
                wordRank: wordData.wordRank!,
                action: 'view',
              );
            }

            if (!mounted) return;
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (context) {
                return DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.65,
                  minChildSize: 0.4,
                  maxChildSize: 0.9,
                  builder: (context, scrollController) {
                    return SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                currentWord.word,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF00C897)),
                                onPressed: () {
                                  WordAudioService.playWordPronunciation(currentWord.word);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (currentWord.usPhone.isNotEmpty || currentWord.ukPhone.isNotEmpty)
                            Row(
                              children: [
                                if (currentWord.usPhone.isNotEmpty)
                                  Text(
                                    '美: [${currentWord.usPhone}]',
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                if (currentWord.ukPhone.isNotEmpty) ...[
                                  const SizedBox(width: 16),
                                  Text(
                                    '英: [${currentWord.ukPhone}]',
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ],
                            ),
                          const SizedBox(height: 16),
                          const Text(
                            '释义',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...currentWord.translations.map((t) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.pos.isNotEmpty ? '${t.pos}. ' : '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      t.tranCn,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          if (currentWord.sentences.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              '例句',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...currentWord.sentences.map((s) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.sContent,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.sCn,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
          color: Colors.blueGrey,
        ),
        _buildActionItem(
          Icons.psychology_outlined,
          'AI学',
          () {
            final currentWord = controller.currentWord;
            if (currentWord == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AIChatPage(
                  chatType: 'vocabulary',
                  title: 'AI学：${currentWord.word}',
                  systemPrompt: '你是一位英语单词老师，请围绕单词 "${currentWord.word}" 用中英双语讲解词义、用法、常见搭配，并设计几个简单练习帮助学生记忆这个单词。',
                ),
              ),
            );
          },
          color: const Color(0xFF00C897),
        ),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color ?? Colors.grey.shade600, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color ?? Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(WordLearningController controller, int currentIndex, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: (currentIndex > 0 || _currentStep > 0) ? () {
                  if (_currentStep > 0) {
                    setState(() {
                      _currentStep--;
                      _resetStepState();
                    });
                  } else {
                    controller.previousWord();
                    // Optional: decide if we want to go to the last step of previous word
                    // For now, let's just go to the start of previous word as it's less confusing context switch
                    // or maybe the user just wants to review the previous word.
                    // Let's keep it simple: previous word starts at step 0.
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C897),
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: Text(_currentStep > 0 ? '上一步' : '上一词', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: (currentIndex < total - 1 || _currentStep < _steps.length - 1) ? () {
                  if (_currentStep < _steps.length - 1) {
                    setState(() {
                      _currentStep++;
                      _resetStepState();
                    });
                  } else {
                    controller.nextWord();
                    setState(() {
                      _currentStep = 0;
                      _resetStepState();
                    });
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C897),
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: Text(_currentStep < _steps.length - 1 ? '下一步' : '下一词', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
