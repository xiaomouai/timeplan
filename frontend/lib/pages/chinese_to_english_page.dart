import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'membership_page.dart';
import '../providers/chat_provider.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/echo_type_wordbook_service.dart';
import '../services/recorder_service.dart';
import '../services/work_english_api_service.dart';
import '../widgets/chat_input_bar.dart';

class _WorkRole {
  const _WorkRole(this.id, this.titleZh, this.titleEn, this.goal);

  final String id;
  final String titleZh;
  final String titleEn;
  final String goal;
}

class _WorkScenario {
  const _WorkScenario(
    this.id,
    this.titleZh,
    this.titleEn,
    this.goal,
    this.sceneTitles,
    this.scenePrompts,
  );

  final String id;
  final String titleZh;
  final String titleEn;
  final String goal;
  final List<String> sceneTitles;
  final List<String> scenePrompts;

  String sceneTitle(int index) => sceneTitles[index.clamp(0, sceneTitles.length - 1) as int];

  String scenePrompt(int index) => scenePrompts[index.clamp(0, scenePrompts.length - 1) as int];
}

const _workRoles = <_WorkRole>[
  _WorkRole('foreign_trade_sales', '外贸销售', 'Foreign trade sales', '把客户沟通说得清楚、专业，并推动下一步。'),
  _WorkRole('client_support', '客户支持', 'Customer support', '先稳住客户，再确认问题和解决方案。'),
  _WorkRole('global_project', '外企项目协作', 'Global project work', '在会议、邮件和协作中汇报进度、风险与行动。'),
];

const _workScenarios = <_WorkScenario>[
  _WorkScenario(
    'quote_follow_up',
    '报价跟进',
    'Follow up on a quote',
    '礼貌确认客户是否看过报价，并把对话推进到下一步。',
    ['给客户跟进报价', '补充报价背景', '确认下一步'],
    ['我想礼貌确认客户是否看过报价，并问他还有没有问题。', '客户觉得价格高，我想解释报价依据，同时保持合作空间。', '我想确认客户什么时候可以给出下一步决定。'],
  ),
  _WorkScenario(
    'clarify_requirements',
    '确认需求',
    'Clarify requirements',
    '复述客户需求，并确认数量、规格、交期或优先级。',
    ['确认客户需求', '追问关键细节', '向团队交接'],
    ['我想复述一遍客户需求，确认我们理解一致。', '我还需要问清楚数量、规格和交付时间。', '我想把确认后的重点清楚地交接给团队。'],
  ),
  _WorkScenario(
    'negotiate_terms',
    '价格和条款谈判',
    'Negotiate terms',
    '解释价格或条款原因，同时给出可以讨论的选项。',
    ['回应压价', '提出替代方案', '确认最终条款'],
    ['客户希望降价，我想先认可对方，再解释我们的价格。', '我想用数量、付款或交期换取更好的条件。', '我想确认双方已经同意的最终条款。'],
  ),
  _WorkScenario(
    'delay_solution',
    '交期延误',
    'Handle a delay',
    '先承担责任和道歉，再说明原因与可执行的解决方案。',
    ['告知延期', '给出解决方案', '重新建立信任'],
    ['我需要告诉客户订单会延期，并先为此道歉。', '我想说明原因，并给客户一个具体的新交期或替代方案。', '我想让客户放心，我们会持续跟进并避免再次发生。'],
  ),
  _WorkScenario(
    'meeting_update',
    '会议汇报',
    'Give a meeting update',
    '用简短英文汇报进度、风险和下一步行动。',
    ['汇报当前进度', '说明风险', '请求决定'],
    ['我想在会议上用一句话汇报项目当前进度。', '我需要说明一个风险，以及它可能影响什么。', '我想明确下一步行动，并请求对方做决定。'],
  ),
  _WorkScenario(
    'escalate_support',
    '升级问题',
    'Escalate an issue',
    '向同事或主管说明问题、影响和请求的支持。',
    ['说明问题', '请求支持', '对齐行动计划'],
    ['我想清楚说明目前遇到的问题和它造成的影响。', '我需要向同事或主管请求具体支持，而不是只说“请帮忙”。', '我想确认谁在什么时候完成哪一步。'],
  ),
];

class ChineseToEnglishPage extends StatefulWidget {
  const ChineseToEnglishPage({super.key});

  @override
  State<ChineseToEnglishPage> createState() => _ChineseToEnglishPageState();
}

class _ChineseToEnglishPageState extends State<ChineseToEnglishPage> {
  final _sourceController = TextEditingController();
  final _focusController = TextEditingController();
  final _practiceController = TextEditingController();
  final _scrollController = ScrollController();
  String _roleId = _workRoles.first.id;
  String _scenarioId = _workScenarios.first.id;
  EnglishKnowledge? _knowledge;
  final _turns = <_PracticeTurn>[];
  final _sessionRecords = <Map<String, dynamic>>[];
  int _sceneIndex = 0;
  bool _awaitingRetry = false;
  bool _sessionCompleted = false;
  bool _sessionSaved = false;
  bool _generating = false;
  bool _sending = false;
  VoiceState _voiceState = VoiceState.idle;
  String? _error;
  int _savedSessionCount = 0;
  String? _lastSavedSummary;
  String? _draftSnapshot;
  String? _remoteSessionId;
  bool _remoteSessionSynced = false;
  String _pendingInputMode = 'text';
  String _selectedWordBookId = EchoTypeWordBookService.definitions.first.id;
  List<EchoTypeWordBookEntry> _wordBookEntries = const [];
  EchoTypeWordBookEntry? _matchedWordBookEntry;
  bool _wordBookLoading = true;

  static const _totalScenes = 3;
  static const _historyKey = 'work_english_training_history_v1';
  static const _draftKey = 'work_english_training_draft_v1';

  @override
  void initState() {
    super.initState();
    _loadTrainingHistory();
    _loadWordBook(_selectedWordBookId);
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _focusController.dispose();
    _practiceController.dispose();
    _scrollController.dispose();
    RecorderService.dispose();
    super.dispose();
  }

  _WorkRole get _selectedRole => _workRoles.firstWhere(
        (role) => role.id == _roleId,
        orElse: () => _workRoles.first,
      );

  _WorkScenario get _selectedScenario => _workScenarios.firstWhere(
        (scenario) => scenario.id == _scenarioId,
        orElse: () => _workScenarios.first,
      );

  String _scenePrompt(EnglishKnowledge knowledge) {
    if (_sceneIndex < knowledge.speakingPromptsZh.length) {
      return knowledge.speakingPromptsZh[_sceneIndex];
    }
    return _selectedScenario.scenePrompt(_sceneIndex);
  }

  String _sceneTitle() => _selectedScenario.sceneTitle(_sceneIndex);

  Future<void> _loadTrainingHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localHistory = prefs.getStringList(_historyKey) ?? const <String>[];
      final draft = prefs.getString(_draftKey);
      final remoteHistory = await WorkEnglishApiService.listSessions();
      if (!mounted) return;
      final history = remoteHistory == null || remoteHistory.isEmpty
          ? localHistory
          : remoteHistory;
      final latest = history.isNotEmpty ? history.first : null;
      if (!mounted) return;
      setState(() {
        _savedSessionCount = history.length;
        _draftSnapshot = draft;
        _lastSavedSummary = latest == null
            ? _summaryFromSnapshot(draft)
            : _summaryFromSnapshot(jsonEncode(latest));
      });
    } catch (error) {
      if (mounted) setState(() => _error = '本地训练记录读取失败：$error');
    }
  }

  String? _summaryFromSnapshot(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final snapshot = jsonDecode(raw);
      if (snapshot is! Map) return null;
      final role = snapshot['role_zh'] ?? '工作英语';
      final scenario = snapshot['scenario_zh'] ?? '临场训练';
      final completed = snapshot['completed'] == true;
      return '$role · $scenario · ${completed ? '已完成三场景' : '训练进行中'}';
    } catch (_) {
      return null;
    }
  }

  Future<void> _restoreDraft() async {
    final raw = _draftSnapshot;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('草稿格式不正确。');
      final snapshot = Map<String, dynamic>.from(decoded);
      final knowledgeJson = snapshot['knowledge'];
      final knowledge = knowledgeJson is Map
          ? EnglishKnowledge.fromJson(Map<String, dynamic>.from(knowledgeJson))
          : null;
      final savedSceneIndex = snapshot['scene_index'];
      final sceneIndex = savedSceneIndex is int ? savedSceneIndex : 0;
      final records = (snapshot['turns'] is List ? snapshot['turns'] as List : const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      final currentSceneRecords = records
          .where((item) => item['scene_index'] == sceneIndex + 1)
          .toList(growable: false);

      _sourceController.text = snapshot['source_zh']?.toString() ?? '';
      _focusController.text = snapshot['focus_word']?.toString() ?? '';
      if (mounted) {
        setState(() {
          _roleId = snapshot['role_id']?.toString() ?? _workRoles.first.id;
          _scenarioId = snapshot['scenario_id']?.toString() ?? _workScenarios.first.id;
          _knowledge = knowledge;
          _sessionRecords
            ..clear()
            ..addAll(records);
          _turns
            ..clear()
            ..addAll(currentSceneRecords.expand((item) => [
                  _PracticeTurn('user', item['answer_en']?.toString() ?? ''),
                  _PracticeTurn('assistant', item['feedback']?.toString() ?? ''),
                ]));
          _sceneIndex = sceneIndex.clamp(0, _totalScenes - 1) as int;
          _awaitingRetry = currentSceneRecords.length.isOdd;
          _sessionCompleted = false;
          _sessionSaved = false;
          _remoteSessionId = snapshot['session_id']?.toString();
          _remoteSessionSynced = _remoteSessionId != null;
          _error = null;
        });
        _updateMatchedWordBookEntry(_focusController.text);
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    }
  }

  Future<void> _saveTrainingSnapshot({required bool completed}) async {
    final snapshotMap = <String, dynamic>{
      'source_zh': _sourceController.text.trim(),
      'role_id': _selectedRole.id,
      'role_zh': _selectedRole.titleZh,
      'scenario_id': _selectedScenario.id,
      'scenario_zh': _selectedScenario.titleZh,
      'scene_index': _sceneIndex,
      'completed': completed,
      'saved_at': DateTime.now().toIso8601String(),
      'focus_word': _focusController.text.trim(),
      'turns': _sessionRecords,
      'knowledge': _knowledge?.toJson(),
    };
    if (_remoteSessionId != null) {
      snapshotMap['session_id'] = _remoteSessionId;
    }
    final snapshot = jsonEncode(snapshotMap);

    final prefs = await SharedPreferences.getInstance();
    if (!completed) {
      await prefs.setString(_draftKey, snapshot);
      _draftSnapshot = snapshot;
    } else {
      final history = prefs.getStringList(_historyKey) ?? <String>[];
      history.insert(0, snapshot);
      if (history.length > 20) history.removeRange(20, history.length);
      await prefs.setStringList(_historyKey, history);
      await prefs.remove(_draftKey);
      _draftSnapshot = null;
      if (mounted) {
        setState(() {
          _sessionSaved = true;
          _savedSessionCount = history.length;
          _lastSavedSummary = _summaryFromSnapshot(snapshot);
        });
      }
    }

    final canSync = ApiConfig.useSimulatedData || AuthService.instance.isLoggedIn;
    if (!canSync) return;
    final remote = await WorkEnglishApiService.saveSession(snapshotMap);
    if (!mounted) return;
    if (remote != null) {
      _remoteSessionId = remote['session_id']?.toString();
      if (!completed && _remoteSessionId != null) {
        snapshotMap['session_id'] = _remoteSessionId;
        _draftSnapshot = jsonEncode(snapshotMap);
        await prefs.setString(_draftKey, _draftSnapshot!);
      }
      setState(() => _remoteSessionSynced = true);
    } else {
      setState(() {
        _remoteSessionSynced = false;
        _error = WorkEnglishApiService.lastRequiresPro && completed
            ? '本次训练已保存在本机；跨设备历史复习属于 Pro 权益。'
            : (WorkEnglishApiService.lastErrorMessage ?? '本次训练已保存在本机，服务端同步失败，联网后可重试。');
      });
    }
  }

  void _resetToSetup() {
    setState(() {
      _knowledge = null;
      _turns.clear();
      _sessionRecords.clear();
      _sceneIndex = 0;
      _awaitingRetry = false;
      _sessionCompleted = false;
      _sessionSaved = false;
      _remoteSessionId = null;
      _remoteSessionSynced = false;
      _error = null;
    });
  }

  Future<void> _generateKnowledge() async {
    final source = _sourceController.text.trim();
    if (source.isEmpty) {
      setState(() => _error = '先输入你想用英文表达的中文内容。');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    final wordBookEntry = EchoTypeWordBookService.find(
      _wordBookEntries,
      _focusController.text,
    );
    final response = await AIService.chat(
      message: jsonEncode(<String, String>{
        'source_zh': source,
        'role': _selectedRole.titleEn,
        'role_zh': _selectedRole.titleZh,
        'scenario': _selectedScenario.titleEn,
        'scenario_zh': _selectedScenario.titleZh,
        'scenario_goal_zh': _selectedScenario.goal,
        'focus_word': _focusController.text.trim(),
        'wordbook_id': _selectedWordBookId,
        'wordbook_sentence': wordBookEntry?.sentence ?? '',
      }),
      chatType: 'general',
      systemPrompt: _knowledgePrompt,
      temperature: 0.35,
      maxTokens: 2600,
    );
    if (!mounted) return;
    if (!response.success || response.content == null) {
      setState(() {
        _generating = false;
        _error = response.error ?? '知识生成失败，请稍后重试。';
      });
      return;
    }
    try {
      final knowledge = EnglishKnowledge.fromJson(_jsonObject(response.content!));
      setState(() {
        _knowledge = knowledge;
        _turns.clear();
        _sessionRecords.clear();
        _sceneIndex = 0;
        _awaitingRetry = false;
        _sessionCompleted = false;
        _sessionSaved = false;
        _remoteSessionId = null;
        _remoteSessionSynced = false;
        _generating = false;
        _error = null;
      });
    } on FormatException catch (error) {
      setState(() {
        _generating = false;
        _error = error.message.toString();
      });
    }
  }

  Future<void> _loadWordBook(String id) async {
    setState(() {
      _wordBookLoading = true;
      _matchedWordBookEntry = null;
    });
    try {
      final entries = await EchoTypeWordBookService.load(id);
      if (!mounted) return;
      setState(() {
        _selectedWordBookId = id;
        _wordBookEntries = entries;
        _wordBookLoading = false;
      });
      _updateMatchedWordBookEntry(_focusController.text);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _wordBookEntries = const [];
        _wordBookLoading = false;
        _error = '词库加载失败，仍可继续使用 AI：$error';
      });
    }
  }

  void _updateMatchedWordBookEntry(String value) {
    final entry = EchoTypeWordBookService.find(_wordBookEntries, value);
    if (entry != _matchedWordBookEntry && mounted) {
      setState(() => _matchedWordBookEntry = entry);
    }
  }

  void _useWordBookEntry(EchoTypeWordBookEntry entry) {
    _focusController
      ..text = entry.word
      ..selection = TextSelection.collapsed(offset: entry.word.length);
    setState(() => _matchedWordBookEntry = entry);
  }

  Future<void> _sendPractice() async {
    final knowledge = _knowledge;
    final text = _practiceController.text.trim();
    if (knowledge == null || text.isEmpty || _sending || _sessionCompleted) return;
    final isRetry = _awaitingRetry;
    final inputMode = _pendingInputMode;
    _pendingInputMode = 'text';
    _practiceController.clear();
    setState(() {
      _sending = true;
      _turns.add(_PracticeTurn('user', text));
      _error = null;
    });
    final history = _turns
        .map((turn) => <String, String>{
              'role': turn.role,
              'content': turn.text,
            })
        .toList(growable: false);
    final response = await AIService.chat(
      message: text,
      chatType: 'speaking',
      systemPrompt: _practicePrompt(knowledge),
      conversationHistory: history,
      temperature: 0.55,
      maxTokens: 700,
    );
    if (!mounted) return;
    var completed = false;
    setState(() {
      _sending = false;
      if (response.success && response.content != null) {
        _turns.add(_PracticeTurn('assistant', response.content!));
        _sessionRecords.add(<String, dynamic>{
          'scene_index': _sceneIndex + 1,
          'scene_title': _sceneTitle(),
          'phase': isRetry ? 'retry' : 'first_attempt',
          'answer_en': text,
          'feedback': response.content!,
          'input_mode': inputMode,
        });
        if (!isRetry) {
          _awaitingRetry = true;
        } else if (_sceneIndex < _totalScenes - 1) {
          _sceneIndex += 1;
          _awaitingRetry = false;
          _turns.clear();
        } else {
          _awaitingRetry = false;
          _sessionCompleted = true;
          completed = true;
        }
      } else {
        _error = response.error ?? '反馈生成失败，请重试。';
      }
    });
    if (response.success && response.content != null) {
      try {
        await _saveTrainingSnapshot(completed: completed);
      } catch (error) {
        if (mounted) setState(() => _error = '反馈已生成，但本地训练记录保存失败：$error');
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startRecording() async {
    if (_sessionCompleted) return;
    if (await RecorderService.start() && mounted) {
      setState(() => _voiceState = VoiceState.recording);
    }
  }

  Future<void> _stopRecording() async {
    if (_voiceState != VoiceState.recording) return;
    setState(() => _voiceState = VoiceState.recognizing);
    try {
      final path = await RecorderService.stop();
      if (path == null) return;
      final text = await AIService.speechToText(path);
      if (text != null && text.trim().isNotEmpty && mounted) {
        _pendingInputMode = 'voice';
        _practiceController.text = text.trim();
        await _sendPractice();
      }
    } finally {
      if (mounted) setState(() => _voiceState = VoiceState.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('工作英语临场训练'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_knowledge != null)
            IconButton(
              onPressed: _resetToSetup,
              icon: const Icon(Icons.refresh),
              tooltip: '重新输入',
            ),
        ],
      ),
      body: _buildResponsiveBody(_knowledge == null ? _buildSetup() : _buildPractice()),
      );
  }

  Widget _buildResponsiveBody(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth >= 840 ? 760.0 : constraints.maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildSetup() {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _buildSetupHero(colors),
        if (_lastSavedSummary != null) ...[
          const SizedBox(height: 12),
          _buildHistoryCard(colors),
        ],
        const SizedBox(height: 20),
        _buildRoleSelector(colors),
        const SizedBox(height: 18),
        TextField(
          controller: _sourceController,
          minLines: 3,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: '今天要说的中文工作意图',
            hintText: '例如：我想礼貌确认客户是否看过报价，并问他还有没有问题。',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.edit_note_rounded),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _focusController,
          onChanged: _updateMatchedWordBookEntry,
          decoration: const InputDecoration(
            labelText: '英文聚焦词（可选）',
            hintText: '例如 reliable',
            prefixIcon: Icon(Icons.lightbulb_outline_rounded),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        _buildScenarioSelector(colors),
        const SizedBox(height: 18),
        _buildStartAction(colors),
        const SizedBox(height: 12),
        _buildWordBookReference(),
        const SizedBox(height: 12),
        _buildCommercialCard(),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _buildErrorText(),
        ],
      ],
    );
  }

  Widget _buildSetupHero(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outline.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                child: const Icon(Icons.forum_outlined),
              ),
              const SizedBox(width: 10),
              Text(
                'WORK ENGLISH · 3 MIN',
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '把中文工作意图，练成能说出口的英文。',
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '输入今天真的要说的话，先开口，再纠错，再把同一个表达迁移到 3 个工作场景。',
            style: TextStyle(color: colors.onPrimaryContainer.withOpacity(0.78), height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              '输入中文',
              '英文开口',
              '必须重说',
              if (ApiConfig.useSimulatedData) '模拟闭环',
            ]
                .map((label) => _buildSetupTag(label, colors))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupTag(String label, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: colors.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildHistoryCard(ColorScheme colors) {
    return Card(
      margin: EdgeInsets.zero,
      color: colors.secondaryContainer,
      child: ListTile(
        dense: true,
        leading: Icon(Icons.history_rounded, color: colors.onSecondaryContainer),
        title: Text(
          '已保存 $_savedSessionCount 次训练',
          style: TextStyle(color: colors.onSecondaryContainer, fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_lastSavedSummary!, style: TextStyle(color: colors.onSecondaryContainer.withOpacity(0.78))),
            if (_draftSnapshot != null)
              TextButton.icon(
                onPressed: _restoreDraft,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: colors.onSecondaryContainer,
                ),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('继续未完成草稿'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelector(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('选择你的工作角色', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _workRoles
              .map(
                (role) => ChoiceChip(
                  label: Text(role.titleZh),
                  selected: role.id == _roleId,
                  selectedColor: colors.primaryContainer,
                  checkmarkColor: colors.onPrimaryContainer,
                  labelStyle: TextStyle(
                    color: role.id == _roleId ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _roleId = role.id),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Text(_selectedRole.goal, style: TextStyle(color: colors.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildScenarioSelector(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('今天要处理的工作场景', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _workScenarios
              .map(
                (scenario) => ChoiceChip(
                  label: Text(scenario.titleZh),
                  selected: scenario.id == _scenarioId,
                  selectedColor: colors.primaryContainer,
                  checkmarkColor: colors.onPrimaryContainer,
                  labelStyle: TextStyle(
                    color: scenario.id == _scenarioId ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _scenarioId = scenario.id),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Text(_selectedScenario.goal, style: TextStyle(color: colors.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildStartAction(ColorScheme colors) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _generating ? null : _generateKnowledge,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
            ),
            icon: _generating
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_generating ? '正在建立英文知识…' : '开始 3 分钟训练'),
          ),
        ),
        const SizedBox(height: 6),
        Text('先说，再看完整知识；每一场都必须重说。', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }

  Widget _buildErrorText() {
    return Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error));
  }

  Widget _buildWordBookReference() {
    final colors = Theme.of(context).colorScheme;
    final definition = EchoTypeWordBookService.definition(_selectedWordBookId);
    final reference = _matchedWordBookEntry ?? (_wordBookEntries.isEmpty ? null : _wordBookEntries.first);
    return Card(
      margin: EdgeInsets.zero,
      color: colors.surface,
      child: ExpansionTile(
        leading: Icon(Icons.menu_book_rounded, color: colors.primary),
        title: const Text('词库参考（可选）'),
        subtitle: Text(
          definition.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (_wordBookLoading) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedWordBookId,
            decoration: const InputDecoration(
              labelText: '选择语境词库',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: EchoTypeWordBookService.definitions
                .map((book) => DropdownMenuItem<String>(value: book.id, child: Text(book.name)))
                .toList(growable: false),
            onChanged: _wordBookLoading ? null : (value) {
              if (value != null) _loadWordBook(value);
            },
          ),
          if (reference != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('例句：${reference.sentence}', style: TextStyle(color: colors.onSurfaceVariant)),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _useWordBookEntry(reference),
                icon: const Icon(Icons.add_circle_outline),
                label: Text('使用 ${reference.word} 作为聚焦词'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommercialCard() {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Icon(Icons.workspace_premium_outlined, color: colors.onTertiaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '想要更多真实场景？',
                    style: TextStyle(color: colors.onTertiaryContainer, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Pro 解锁更多训练、历史复习和自定义客户场景。',
                    style: TextStyle(color: colors.onTertiaryContainer.withOpacity(0.78), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const MembershipPage()),
              ),
              style: TextButton.styleFrom(foregroundColor: colors.onTertiaryContainer),
              child: const Text('查看方案'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPractice() {
    final knowledge = _knowledge!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              _buildTrainingProgress(),
              const SizedBox(height: 12),
              _buildPracticePromptCard(knowledge),
              const SizedBox(height: 12),
              ..._turns.map(_buildTurn),
              if (_sessionCompleted) _buildCompletionCard(),
              if (_error != null)
                _buildErrorText(),
              const SizedBox(height: 12),
              _knowledgeCard(knowledge),
            ],
          ),
        ),
        if (!_sessionCompleted)
          ChatInputBar(
            controller: _practiceController,
            isLoading: _sending,
            voiceState: _voiceState,
            onTextChanged: (_) {},
            onSend: _sendPractice,
            onStartRecording: _startRecording,
            onStopRecording: _stopRecording,
          ),
      ],
    );
  }

  Widget _buildPracticePromptCard(EnglishKnowledge knowledge) {
    final colors = Theme.of(context).colorScheme;
    final isRetry = _awaitingRetry && !_sessionCompleted;
    final title = _sessionCompleted
        ? '训练完成'
        : isRetry
            ? '请重说一次'
            : '先用英文说出来';
    return Card(
      margin: EdgeInsets.zero,
      color: isRetry ? colors.tertiaryContainer : colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRetry ? Icons.replay_rounded : Icons.record_voice_over_rounded,
                  color: isRetry ? colors.onTertiaryContainer : colors.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: isRetry ? colors.onTertiaryContainer : colors.onPrimaryContainer,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _scenePrompt(knowledge),
              style: TextStyle(
                color: isRetry ? colors.onTertiaryContainer : colors.onPrimaryContainer,
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!_sessionCompleted) ...[
              const SizedBox(height: 8),
              Text(
                isRetry ? '把刚才的问题改好，再补充一个细节。' : '可以直接输入英文，也可以按住下方按钮录音。',
                style: TextStyle(
                  color: (isRetry ? colors.onTertiaryContainer : colors.onPrimaryContainer).withOpacity(0.78),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingProgress() {
    final colors = Theme.of(context).colorScheme;
    final status = _sessionCompleted
        ? '本次训练已完成并保存'
        : _awaitingRetry
            ? '反馈已到：请用英文重说一次，才能进入下一场景'
            : '先完成一次英文回答，再根据反馈重说';
    return Card(
      margin: EdgeInsets.zero,
      color: _awaitingRetry ? colors.tertiaryContainer : colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selectedRole.titleZh} · ${_selectedScenario.titleZh}',
                    style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700),
                  ),
                ),
                Text('第 ${_sessionCompleted ? _totalScenes : _sceneIndex + 1}/$_totalScenes 场景'),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _sessionCompleted ? 1 : (_sceneIndex + 1) / _totalScenes,
                minHeight: 6,
                color: colors.primary,
                backgroundColor: colors.primaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text('当前任务：${_sceneTitle()}', style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(
              status,
              style: TextStyle(
                color: _awaitingRetry ? colors.onTertiaryContainer : colors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionCard() {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '完成了：你已经把同一个表达迁移到 $_totalScenes 个工作场景。',
              style: TextStyle(color: colors.onPrimaryContainer, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _sessionSaved
                  ? (_remoteSessionSynced
                      ? '本次结果已同步服务端并保存在本机，累计保存 $_savedSessionCount 次。'
                      : '本次结果已保存在本机，累计保存 $_savedSessionCount 次。')
                  : '本次结果暂未保存，请稍后再试。',
              style: TextStyle(color: colors.onPrimaryContainer.withOpacity(0.78)),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _resetToSetup,
              icon: const Icon(Icons.replay),
              label: const Text('再练一轮'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _knowledgeCard(EnglishKnowledge knowledge) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(Icons.menu_book_outlined, color: colors.primary),
        title: Text(
          '知识参考 · ${knowledge.targetWord} · ${knowledge.meaningZh}',
          style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${knowledge.partOfSpeech} · ${knowledge.pronunciation} · 展开查看完整知识'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _knowledgeSection('直接可以说', knowledge.recommendedExpressions),
          _knowledgeSection('中文组织顺序', knowledge.intentStructureZh),
          _knowledgeSection('开口起手式', <String>[
            if (knowledge.openingLine.isNotEmpty) knowledge.openingLine,
            if (knowledge.fallbackLine.isNotEmpty) '备用说法：${knowledge.fallbackLine}',
          ]),
          _knowledgeSection('常用搭配', knowledge.collocations),
          _knowledgeSection('例句', knowledge.exampleSentences),
          _knowledgeSection('语法提醒', knowledge.grammarNotesZh),
          _knowledgeSection('英文场景', knowledge.scenarios),
          _knowledgeSection('短文', <String>[knowledge.shortArticle]),
          _knowledgeSection('演讲练习', <String>[knowledge.speech]),
        ],
      ),
    );
  }

  Widget _knowledgeSection(String title, List<String> items) {
    final colors = Theme.of(context).colorScheme;
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('• $item', style: TextStyle(color: colors.onSurfaceVariant, height: 1.35)),
              )),
        ],
      ),
    );
  }

  Widget _buildTurn(_PracticeTurn turn) {
    final colors = Theme.of(context).colorScheme;
    final isUser = turn.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: isUser ? colors.secondaryContainer : colors.surface,
          border: isUser ? null : Border.all(color: colors.outline.withOpacity(0.18)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          turn.text,
          style: TextStyle(color: isUser ? colors.onSecondaryContainer : colors.onSurface),
        ),
      ),
    );
  }

  String _practicePrompt(EnglishKnowledge knowledge) => '''You are an English speaking coach for a Chinese-speaking learner.
The learner's original Chinese idea is: ${_sourceController.text.trim()}
Role: ${_selectedRole.titleEn}
Work scenario: ${_selectedScenario.titleEn}
Work goal: ${_selectedScenario.goal}
Target expression: ${knowledge.targetWord}
Scene ${_sceneIndex + 1} of 3: ${_sceneTitle()}
Scene prompt in Chinese: ${_scenePrompt(knowledge)}
Training phase: ${_awaitingRetry ? 'retry after feedback' : 'first attempt'}
Keep the learner speaking in English. Do not reveal a full model answer before the learner tries.
The wordbook is a reference, not a script to memorize. Keep the learner speaking in English.
After each attempt, respond briefly: encourage one strength, explain at most one important issue in Chinese, give one natural English correction, and ask the learner to say it again with one extra detail. On a retry, say whether the scene is ready to pass, but do not give more than one correction.''';

  static const _knowledgePrompt = '''你是中文环境中的英语知识教练。
用户会输入中文想法、句子或场景。请把它塑造成可用于英文口语训练的完整知识。
只返回 JSON，不要 Markdown，不要额外解释。JSON 必须包含：
{"source_zh":"","target_word":"","meaning_zh":"","part_of_speech":"","pronunciation":"","recommended_expressions":[],"intent_structure_zh":[],"opening_line":"","fallback_line":"","collocations":[],"example_sentences":[],"grammar_notes_zh":[],"scenarios":[],"speaking_prompts_zh":[],"short_article":"","speech":""}
source_zh 保留中文原意；target_word、recommended_expressions、opening_line、fallback_line、collocations、example_sentences、scenarios 使用自然英文；meaning_zh、intent_structure_zh、grammar_notes_zh、speaking_prompts_zh 使用中文。至少给出 2 个推荐说法、3 个中文组织步骤、3 个搭配、2 个例句、2 个英文场景和 3 个中文口语提示。三个口语提示要对应“首次表达、补充细节、推进下一步”三个工作场景。
短文写成 80-120 个词的自然英文，演讲写成适合 60-90 秒口述的英文。如果 wordbook_sentence 非空，先判断它是否适合用户场景；适合时吸收其自然搭配，不适合时改写，不要机械复制。''';

  static Map<String, dynamic> _jsonObject(String raw) {
    var text = raw.trim();
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false).firstMatch(text);
    if (fenced != null) text = fenced.group(1)!.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) throw const FormatException('AI 返回的知识不是有效 JSON。');
    final value = jsonDecode(text.substring(start, end + 1));
    if (value is! Map) throw const FormatException('AI 返回的知识格式不正确。');
    return Map<String, dynamic>.from(value);
  }
}

class _PracticeTurn {
  const _PracticeTurn(this.role, this.text);
  final String role;
  final String text;
}

class EnglishKnowledge {
  const EnglishKnowledge({
    required this.targetWord,
    required this.meaningZh,
    required this.partOfSpeech,
    required this.pronunciation,
    required this.recommendedExpressions,
    required this.intentStructureZh,
    required this.openingLine,
    required this.fallbackLine,
    required this.collocations,
    required this.exampleSentences,
    required this.grammarNotesZh,
    required this.scenarios,
    required this.speakingPromptsZh,
    required this.shortArticle,
    required this.speech,
  });

  final String targetWord;
  final String meaningZh;
  final String partOfSpeech;
  final String pronunciation;
  final List<String> recommendedExpressions;
  final List<String> intentStructureZh;
  final String openingLine;
  final String fallbackLine;
  final List<String> collocations;
  final List<String> exampleSentences;
  final List<String> grammarNotesZh;
  final List<String> scenarios;
  final List<String> speakingPromptsZh;
  final String shortArticle;
  final String speech;

  factory EnglishKnowledge.fromJson(Map<String, dynamic> json) {
    String required(String key) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      throw FormatException('知识结果缺少 $key。');
    }

    List<String> list(String key) => (json[key] is List ? json[key] as List : const [])
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    String optional(String key) => json[key] is String ? (json[key] as String).trim() : '';

    final prompts = list('speaking_prompts_zh');
    if (prompts.isEmpty) throw const FormatException('知识结果缺少口语提示。');
    return EnglishKnowledge(
      targetWord: required('target_word'),
      meaningZh: required('meaning_zh'),
      partOfSpeech: required('part_of_speech'),
      pronunciation: required('pronunciation'),
      recommendedExpressions: list('recommended_expressions'),
      intentStructureZh: list('intent_structure_zh'),
      openingLine: optional('opening_line'),
      fallbackLine: optional('fallback_line'),
      collocations: list('collocations'),
      exampleSentences: list('example_sentences'),
      grammarNotesZh: list('grammar_notes_zh'),
      scenarios: list('scenarios'),
      speakingPromptsZh: prompts,
      shortArticle: required('short_article'),
      speech: required('speech'),
    );
  }

  Map<String, dynamic> toJson() => {
        'target_word': targetWord,
        'meaning_zh': meaningZh,
        'part_of_speech': partOfSpeech,
        'pronunciation': pronunciation,
        'recommended_expressions': recommendedExpressions,
        'intent_structure_zh': intentStructureZh,
        'opening_line': openingLine,
        'fallback_line': fallbackLine,
        'collocations': collocations,
        'example_sentences': exampleSentences,
        'grammar_notes_zh': grammarNotesZh,
        'scenarios': scenarios,
        'speaking_prompts_zh': speakingPromptsZh,
        'short_article': shortArticle,
        'speech': speech,
      };
}
