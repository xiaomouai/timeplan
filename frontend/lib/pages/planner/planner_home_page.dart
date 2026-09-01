import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show AlwaysStoppedAnimation, LinearProgressIndicator, ScaffoldMessenger, SnackBar;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../models/health_models.dart';
import '../../models/planner_models.dart';
import '../../services/health_plan_service.dart';
import '../../services/health_store.dart';
import '../../services/planner_agent_service.dart';
import '../../services/planner_stats.dart';
import '../../services/planner_store.dart';
import '../../services/pomodoro_engine.dart';

const _kIndigo = Color(0xFF5E5CE6);
const _kGreen = Color(0xFF30B06A);

/// timePlan 主页（Cupertino 风格）：
/// 上：月历（有任务的日子带圆点）；下：选中日的任务进度表。
/// 点击日期 → 自动聚焦输入并开始听写 → 说完自动生成该日计划。
/// 任务用番茄钟执行，进度自动累计，到点语音+弹窗提醒，底部自动反馈。
class PlannerHomePage extends StatefulWidget {
  const PlannerHomePage({super.key});

  @override
  State<PlannerHomePage> createState() => _PlannerHomePageState();
}

class _PlannerHomePageState extends State<PlannerHomePage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final PomodoroEngine _engine = PomodoroEngine();
  final FlutterTts _tts = FlutterTts();
  final Set<String> _remindedTaskIds = {};
  Timer? _dueCheckTimer;

  bool _speechReady = false;
  bool _listening = false;
  /// 防止连点/重入：浏览器端 SpeechRecognition 重复 start() 会抛
  /// InvalidStateError: recognition has already started
  bool _listenStarting = false;
  bool _generating = false;
  bool _dialogOpen = false;
  bool _autoGenFired = false;

  DateTime _selectedDay = _today();
  DateTime _displayedMonth = DateTime(_today().year, _today().month, 1);
  List<PlannerTask> _dayTasks = [];
  List<PlannerTask> _allTasks = [];
  Map<String, int> _taskCountByDay = {};
  String? _lastNote;

  // 健康底座（与计划表共用本地存储）
  Map<String, Map<String, double>> _healthLogs = {};
  int _healthPhaseIndex = 0;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    // 引擎回调返回的 Future 必须由我们来兜底，否则抛错会变成未捕获的 "Uncaught Error"
    _engine.onWorkCompleted = (id) {
      _handleWorkCompleted(id).catchError(
          (e) => debugPrint('[planner] onWorkCompleted 异常：$e'));
    };
    _engine.onRestCompleted = () {
      _handleRestCompleted()
          .catchError((e) => debugPrint('[planner] onRestCompleted 异常：$e'));
    };
    _dueCheckTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _checkDueTasks());
    _reload();
  }

  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize(
        onError: (_) => _setListening(false),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') _setListening(false);
        },
      );
    } catch (_) {
      _speechReady = false;
    }
    if (mounted) setState(() {});
  }

  void _setListening(bool v) {
    if (mounted) setState(() => _listening = v);
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.5);
    } catch (_) {}
  }

  Future<void> _speak(String msg) async {
    try {
      await _tts.stop();
      await _tts.speak(msg);
    } catch (_) {}
  }

  Future<void> _reload() async {
    try {
      // 计划表来自本地 SharedPreferences，必须成功；健康后端若不可用则降级为空。
      List<PlannerTask> all = [];
      try {
        all = await PlannerStore.loadAll();
      } catch (e) {
        debugPrint('[planner] 读取本地计划表失败：$e');
      }
      Map<String, Map<String, double>> logs = {};
      int phaseIndex = _healthPhaseIndex;
      try {
        logs = await HealthStore.loadLogs();
        phaseIndex = await HealthStore.loadPhase();
      } catch (e) {
        // 后端短暂不可达 / 鉴权失败 / 数据异常：保留当前计划表，健康条降级为空
        debugPrint('[planner] 健康数据加载失败，已降级：$e');
      }
      if (!mounted) return;
      setState(() {
        _allTasks = all;
        _healthLogs = logs;
        _healthPhaseIndex = phaseIndex;
        final counts = <String, int>{};
        for (final t in all) {
          counts[_dayKey(t.start)] = (counts[_dayKey(t.start)] ?? 0) + 1;
        }
        _taskCountByDay = counts;
        _dayTasks = all
            .where((t) => _dayKey(t.start) == _dayKey(_selectedDay))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
      });
    } catch (e) {
      // setState 闭包或数据解析异常也兜底，避免变成未捕获的 "Uncaught Error"
      debugPrint('[planner] _reload 渲染异常：$e');
    }
  }

  // ---------------- 计划生成 ----------------

  Future<void> _generatePlan() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) {
      _toast('先说出或输入要做的事');
      return;
    }
    setState(() => _generating = true);
    try {
      final dayStart =
          DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 8, 0);
      final plan = await PlannerAgentService.decompose(
        input: input,
        dayStart: dayStart,
      );
      await PlannerStore.appendAll(plan.tasks);
      _inputCtrl.clear();
      await _reload();
      if (!mounted) return;
      setState(() => _lastNote = plan.note.isEmpty ? null : plan.note);
      _speak('已为${_dayLabel()}生成${plan.tasks.length}项计划');
      // 生成来源仅写入日志，界面不暴露模型/引擎信息
      debugPrint('[planner] 计划来源：${plan.source}');
      _toast('已生成 ${plan.tasks.length} 项计划');
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// 语音听写：说完（finalResult）自动生成计划
  Future<void> _startListening({bool autoGenerate = true}) async {
    if (!_speechReady) {
      _toast('当前环境不支持语音识别，请直接输入文字');
      _inputFocus.requestFocus();
      return;
    }
    // 防止连点重入：同一时刻只允许一个 listen 流程在跑
    if (_listenStarting) return;
    _listenStarting = true;
    try {
      // 浏览器端 SpeechRecognition 若仍在运行，再次 start() 会抛
      // InvalidStateError: recognition has already started
      if (_speech.isListening) {
        try {
          await _speech.stop();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;
      }
      _autoGenFired = !autoGenerate;
      await _speech.listen(
        onResult: (r) {
          if (!mounted) return;
          setState(() => _inputCtrl.text = r.recognizedWords);
          if (autoGenerate &&
              r.finalResult &&
              r.recognizedWords.trim().isNotEmpty &&
              !_autoGenFired) {
            _autoGenFired = true;
            Future.delayed(const Duration(milliseconds: 400), () async {
              try {
                await _generatePlan();
              } catch (e) {
                debugPrint('[planner] 延迟生成计划异常：$e');
              }
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: 'zh_CN',
          partialResults: true,
          cancelOnError: true,
        ),
      );
      if (!mounted) return;
      _setListening(true);
    } catch (e) {
      // 启动失败（已启动/权限/不支持）不应变成未捕获异常
      debugPrint('[planner] 语音识别启动失败：$e');
      _setListening(false);
      if (mounted) _toast('语音识别启动失败，请重试或直接输入文字');
    } finally {
      _listenStarting = false;
    }
  }

  Future<void> _toggleListen() async {
    // 以插件真实状态为准：Dart 侧 _listening 可能与浏览器 SpeechRecognition 不同步
    if (_listening || _speech.isListening) {
      try {
        await _speech.stop();
      } catch (e) {
        debugPrint('[planner] 停止语音识别异常：$e');
      }
      _setListening(false);
      return;
    }
    await _startListening();
  }

  // ---------------- 日历 ----------------

  /// 点击日历日期：选中该日 → 聚焦输入框 → 直接开始听写
  Future<void> _onDatePicked(DateTime day) async {
    setState(() {
      _selectedDay = day;
      _displayedMonth = DateTime(day.year, day.month, 1);
      _lastNote = null;
    });
    await _reload();
    _inputFocus.requestFocus();
    if (_speechReady) {
      await _startListening();
    } else {
      _toast('为${_dayLabel()}安排：输入或点击麦克风说话');
    }
  }

  // ---------------- 番茄钟与提醒 ----------------

  void _startPomodoro(PlannerTask t) {
    if (t.done) {
      _toast('该任务已完成');
      return;
    }
    _engine.startWork(taskId: t.id, title: t.title);
    _speak('开始专注：${t.title}');
    setState(() {});
  }

  Future<void> _handleWorkCompleted(String taskId) async {
    final rec = await PlannerStore.completePomodoro(taskId);
    await _reload();
    if (rec == null) return;
    final (task, justCompleted) = rec;
    await _speak(justCompleted ? '任务完成，干得漂亮！' : '番茄完成，休息一下');
    if (!mounted) return;
    _showDialog(
      justCompleted ? '🎉 任务完成' : '🍅 完成一个番茄',
      justCompleted
          ? '《${task.title}》已完成！\n累计专注 ${task.donePomodoros * PomodoroLength.minutes} 分钟，进度自动记录为 100%。'
          : '《${task.title}》进度 ${(task.progress * 100).toStringAsFixed(0)}%'
              '（${task.donePomodoros}/${task.plannedPomodoros} 番茄）',
      justCompleted
          ? [('收工', null)]
          : [
              ('休息 5 分钟', () => _engine.startRest()),
              ('继续专注', () {
                final t = _dayTasks.where((x) => x.id == taskId).firstOrNull;
                if (t != null) _startPomodoro(t);
              }),
            ],
    );
  }

  Future<void> _handleRestCompleted() async {
    await _speak('休息结束，准备继续');
    if (!mounted) return;
    _showDialog('⏰ 休息结束', '精神满格，继续下一个番茄吧！', [('知道了', null)]);
  }

  /// 到点提醒：任务开始时间到了（且未完成）弹窗 + 语音提醒
  Future<void> _checkDueTasks() async {
    try {
      if (!mounted || _engine.running || _dialogOpen) return;
    final now = DateTime.now();
    for (final t in _dayTasks) {
      final due = t.start.isBefore(now) && now.difference(t.start).inMinutes < 2;
      if (due && !t.done && !_remindedTaskIds.contains(t.id)) {
        _remindedTaskIds.add(t.id);
        _speak('时间到了，该开始：${t.title}');
        _showDialog(
          '⏰ 到点提醒',
          '《${t.title}》时间到了（${t.timeRange}），开始一个专注番茄？',
          [('开始番茄', () => _startPomodoro(t)), ('稍后再说', null)],
        );
        break;
      }
    }
    } catch (e) {
      // Timer 回调里抛错会变成未捕获的 "Uncaught Error"，这里兜底
      debugPrint('[planner] _checkDueTasks 异常：$e');
    }
  }

  Future<void> _showDialog(
      String title, String content, List<(String, VoidCallback?)> actions) async {
    if (!mounted) return;
    setState(() => _dialogOpen = true);
    await showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(content, style: const TextStyle(fontSize: 14)),
        ),
        actions: [
          for (final (label, cb) in actions)
            CupertinoDialogAction(
              isDefaultAction: cb != null,
              onPressed: () {
                Navigator.pop(ctx);
                cb?.call();
              },
              child: Text(label),
            ),
        ],
      ),
    );
    if (mounted) setState(() => _dialogOpen = false);
  }

  // ---------------- UI ----------------
  // 注：AI 大模型（provider / model / API Key）统一由后端配置文件（.env）决定，
  // 前端不再提供密钥录入入口，也不在界面上暴露模型信息。

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle:
            const Text('timePlan', style: TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              onPressed: _openHealth,
              child: const Icon(CupertinoIcons.heart_fill,
                  size: 22, color: _kGreen),
            ),
            const SizedBox(width: 10),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              onPressed: () => Navigator.pushNamed(context, '/home'),
              child: const Icon(CupertinoIcons.book,
                  size: 22, color: _kIndigo),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_engine.running) _buildPomodoroBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  _buildCalendarCard(),
                  const SizedBox(height: 10),
                  _buildDayStats(),
                  const SizedBox(height: 10),
                  _buildHealthStrip(),
                  if (_lastNote != null) ...[
                    const SizedBox(height: 8),
                    _buildNote(),
                  ],
                  const SizedBox(height: 10),
                  if (_dayTasks.isEmpty)
                    _buildEmptyDayCard()
                  else
                    for (final t in _dayTasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildTaskCard(t),
                      ),
                  _buildStatsCard(),
                ],
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ---- 日历 ----

  Widget _buildCalendarCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(30, 30),
                onPressed: () => setState(() => _displayedMonth =
                    DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1)),
                child: const Icon(CupertinoIcons.chevron_left,
                    size: 18, color: _kIndigo),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _displayedMonth =
                        DateTime(_today().year, _today().month, 1);
                  }),
                  child: Text(
                    '${_displayedMonth.year}年${_displayedMonth.month}月',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(30, 30),
                onPressed: () => setState(() => _displayedMonth =
                    DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1)),
                child: const Icon(CupertinoIcons.chevron_right,
                    size: 18, color: _kIndigo),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final w in const ['一', '二', '三', '四', '五', '六', '日'])
                Expanded(
                  child: Center(
                    child: Text(w,
                        style: const TextStyle(
                            fontSize: 12, color: CupertinoColors.systemGrey)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          _buildMonthGrid(),
        ],
      ),
    );
  }

  Widget _buildMonthGrid() {
    final first = _displayedMonth;
    // 周一为首列：DateTime.weekday 周一=1…周日=7 → 列号 = weekday-1
    final lead = first.weekday - 1;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final cells = <DateTime?>[
      for (int i = 0; i < lead; i++) null,
      for (int d = 1; d <= daysInMonth; d++)
        DateTime(first.year, first.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return Column(
      children: [
        for (int r = 0; r < cells.length ~/ 7; r++)
          Row(
            children: [
              for (int c = 0; c < 7; c++)
                Expanded(child: _buildDayCell(cells[r * 7 + c])),
            ],
          ),
      ],
    );
  }

  Widget _buildDayCell(DateTime? day) {
    if (day == null) return const SizedBox(height: 44);
    final today = _today();
    final isToday = _dayKey(day) == _dayKey(today);
    final isSelected = _dayKey(day) == _dayKey(_selectedDay);
    final count = _taskCountByDay[_dayKey(day)] ?? 0;
    return GestureDetector(
      onTap: () => _onDatePicked(day),
      child: Container(
        height: 44,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? _kIndigo : null,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: isToday || isSelected ? FontWeight.w700 : null,
                color: isSelected
                    ? CupertinoColors.white
                    : isToday
                        ? _kIndigo
                        : CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 1),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? CupertinoColors.white
                    : count > 0
                        ? _kIndigo
                        : const Color(0x00000000),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayStats() {
    final done = _dayTasks.where((t) => t.done).length;
    final totalMin = _dayTasks.fold<int>(0, (s, t) => s + t.estimateMinutes);
    final pomos = _dayTasks.fold<int>(0, (s, t) => s + t.donePomodoros);
    final rate = _dayTasks.isEmpty ? 0.0 : done / _dayTasks.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(_dayLabel(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('完成 $done/${_dayTasks.length} · 番茄 x$pomos · ${_fmtMin(totalMin)}',
                  style: const TextStyle(
                      fontSize: 12, color: CupertinoColors.systemGrey)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 6,
              backgroundColor: CupertinoColors.systemGrey5,
              valueColor: const AlwaysStoppedAnimation(_kIndigo),
            ),
          ),
        ],
      ),
    );
  }

  /// 打开健康底座页；返回后刷新（可能已排入作息任务或推进了阶段）
  Future<void> _openHealth() async {
    await Navigator.pushNamed(context, '/health');
    if (mounted) await _reload();
  }

  /// 今日健康达标条：阶段 + 连续天数 + 分项达标，点击进入完整打卡页
  Widget _buildHealthStrip() {
    final phase = HealthPhases.at(_healthPhaseIndex);
    final status = HealthPlanService.dayStatus(
      day: _selectedDay,
      logs: _healthLogs,
      phase: phase,
    );
    final ev = HealthPlanService.evaluate(
      today: DateTime.now(),
      logs: _healthLogs,
      unlockedPhase: _healthPhaseIndex,
    );
    final missing = status.missingIds
        .map((id) => HealthItems.byId(id).title)
        .toList();
    return GestureDetector(
      onTap: _openHealth,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEAF6EE), Color(0xFFEEF0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.heart_fill,
                    size: 14, color: _kGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('健康底座 · ${phase.title}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                Text('连续 ${ev.streak} 天 · ${status.met}/${status.total}',
                    style: const TextStyle(
                        fontSize: 11, color: CupertinoColors.systemGrey)),
                const Icon(CupertinoIcons.chevron_right,
                    size: 12, color: CupertinoColors.systemGrey3),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final h in phase.habits)
                  _healthChip(h, status.values[h.id] ?? 0),
              ],
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('待补：${missing.join('、')}',
                  style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: CupertinoColors.systemGrey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _healthChip(HealthHabit h, double value) {
    final met = h.isMet(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: met ? _kGreen.withValues(alpha: 0.14) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: met ? _kGreen : CupertinoColors.systemGrey4,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? CupertinoIcons.checkmark : CupertinoIcons.circle,
            size: 11,
            color: met ? _kGreen : CupertinoColors.systemGrey,
          ),
          const SizedBox(width: 4),
          Text(
            h.no > 0 ? '${h.no}·${h.title.split(' ').first}' : '起身',
            style: TextStyle(
              fontSize: 11,
              color: met ? _kGreen : CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CupertinoColors.systemYellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle,
              size: 14, color: CupertinoColors.systemOrange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(_lastNote!,
                style: const TextStyle(
                    fontSize: 12, color: CupertinoColors.systemOrange)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(CupertinoIcons.calendar_badge_plus,
              size: 40, color: CupertinoColors.systemGrey3),
          SizedBox(height: 10),
          Text('这一天还没有计划',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('点上方日期后直接说出要做的事，Agent 自动拆任务排时间',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
        ],
      ),
    );
  }

  // ---- 番茄横幅 ----

  Widget _buildPomodoroBanner() {
    final isWork = _engine.phase == PomodoroPhase.work;
    final remaining = Duration(seconds: _engine.remainingSeconds);
    final mm = remaining.inMinutes.toString().padLeft(2, '0');
    final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isWork ? _kIndigo : CupertinoColors.systemGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(isWork ? CupertinoIcons.timer : CupertinoIcons.smiley,
                  color: CupertinoColors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${isWork ? "专注中" : "休息中"} · ${_engine.taskTitle ?? ""}',
                  style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('$mm:$ss',
                  style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _engine.sessionProgress,
              minHeight: 4,
              backgroundColor: CupertinoColors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation(CupertinoColors.white),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _pomAction(
                _engine.paused ? CupertinoIcons.play_fill : CupertinoIcons.pause,
                _engine.paused ? '继续' : '暂停',
                () => _engine.paused ? _engine.resume() : _engine.pause(),
              ),
              if (isWork)
                _pomAction(CupertinoIcons.checkmark_alt_circle, '提前完成',
                    _engine.finishWorkEarly)
              else
                _pomAction(
                    CupertinoIcons.forward_end, '跳过休息', _engine.skipRest),
              _pomAction(CupertinoIcons.xmark_circle, '放弃', _engine.stop),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pomAction(IconData icon, String label, VoidCallback onTap) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      minimumSize: Size.zero,
      onPressed: () {
        onTap();
        if (mounted) setState(() {});
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: CupertinoColors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: CupertinoColors.white, fontSize: 13)),
        ],
      ),
    );
  }

  // ---- 任务卡 ----

  Widget _buildTaskCard(PlannerTask t) {
    final color = switch (t.priority) {
      TaskPriority.high => CupertinoColors.systemRed,
      TaskPriority.medium => CupertinoColors.systemOrange,
      TaskPriority.low => CupertinoColors.systemGreen,
    };
    final active = _engine.running && _engine.taskId == t.id;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(12),
        border: active ? Border.all(color: _kIndigo, width: 1.5) : null,
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () async {
                  await PlannerStore.toggleDone(t.id);
                  await _reload();
                },
                child: Icon(
                  t.done
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  size: 24,
                  color: t.done
                      ? CupertinoColors.systemGreen
                      : CupertinoColors.systemGrey3,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        decoration: t.done ? TextDecoration.lineThrough : null,
                        color: t.done
                            ? CupertinoColors.systemGrey
                            : CupertinoColors.label,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text('${t.timeRange} · ${t.estimateMinutes}分钟',
                            style: const TextStyle(
                                fontSize: 12, color: CupertinoColors.systemGrey)),
                        const SizedBox(width: 8),
                        _statusChip(t),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('${t.donePomodoros}/${t.plannedPomodoros}番茄',
                            style: const TextStyle(
                                fontSize: 11, color: CupertinoColors.systemGrey)),
                        if (t.completedAt != null) ...[
                          const SizedBox(width: 6),
                          Text(
                              '完成于 ${t.completedAt!.hour.toString().padLeft(2, '0')}:${t.completedAt!.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: CupertinoColors.systemGreen)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!t.done)
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minimumSize: Size.zero,
                  onPressed: active ? null : () => _startPomodoro(t),
                  child: Icon(
                    active ? CupertinoIcons.timer : CupertinoIcons.play_circle,
                    size: 26,
                    color:
                        active ? _kIndigo : CupertinoColors.activeBlue,
                  ),
                ),
              CupertinoButton(
                padding: const EdgeInsets.all(6),
                minimumSize: Size.zero,
                onPressed: () async {
                  if (_engine.taskId == t.id) _engine.stop();
                  await PlannerStore.remove(t.id);
                  await _reload();
                },
                child: const Icon(CupertinoIcons.delete,
                    size: 18, color: CupertinoColors.systemGrey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: t.progress,
              minHeight: 4,
              backgroundColor: CupertinoColors.systemGrey5,
              valueColor: AlwaysStoppedAnimation(
                  t.done ? CupertinoColors.systemGreen : _kIndigo),
            ),
          ),
        ],
      ),
    );
  }

  /// 执行统计卡：数据瓦片 + 近 7 天完成率柱状图 + 自动评语
  Widget _buildStatsCard() {
    final stats = DayStats.of(_dayTasks, DateTime.now());
    final week = PlannerStats.last7Days(_allTasks);
    const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
    final today = _today();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF0FF), Color(0xFFE8F7EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.chart_bar_alt_fill,
                  size: 16, color: _kIndigo),
              const SizedBox(width: 6),
              const Text('执行统计',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_dayLabel()} · 计划 ${stats.plannedMinutes} 分钟',
                  style: const TextStyle(
                      fontSize: 11, color: CupertinoColors.systemGrey)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile('${(stats.completionRate * 100).toStringAsFixed(0)}%',
                  '完成率'),
              _statTile('${stats.doneTasks}/${stats.totalTasks}', '完成任务'),
              _statTile('${stats.focusMinutes}分', '实际专注'),
              _statTile('${stats.pomodoros}个', '完成番茄'),
              _statTile('${stats.overdueTasks}', '逾期未完'),
            ],
          ),
          const SizedBox(height: 12),
          const Text('近 7 天完成率',
              style:
                  TextStyle(fontSize: 11, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 6),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < week.length; i++)
                  _weekBar(week[i], weekLabels[week[i].day.weekday - 1],
                      _dayKey(week[i].day) == _dayKey(today)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(stats.comment,
              style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _statTile(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: CupertinoColors.systemGrey)),
        ],
      ),
    );
  }

  Widget _weekBar(WeekPoint p, String weekday, bool isToday) {
    final barHeight = p.hasData ? 8.0 + 42.0 * p.rate : 4.0;
    final color = !p.hasData
        ? CupertinoColors.systemGrey5
        : (isToday ? _kIndigo : const Color(0xFFAEAFE8));
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(p.hasData ? '${(p.rate * 100).toStringAsFixed(0)}%' : '',
              style: const TextStyle(
                  fontSize: 9, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 2),
          Container(
            width: 16,
            height: barHeight,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 3),
          Text(isToday ? '今' : weekday,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isToday ? FontWeight.w700 : null,
                color: isToday ? _kIndigo : CupertinoColors.systemGrey,
              )),
        ],
      ),
    );
  }

  /// 执行状态徽章：未开始/进行中/已完成/已逾期（按当前时间自动判定）
  Widget _statusChip(PlannerTask t) {
    final status = t.statusAt(DateTime.now());
    final color = switch (status) {
      TaskExecStatus.done => CupertinoColors.systemGreen,
      TaskExecStatus.inProgress => _kIndigo,
      TaskExecStatus.overdue => CupertinoColors.systemRed,
      TaskExecStatus.notStarted => CupertinoColors.systemGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.label,
          style: TextStyle(fontSize: 10, color: color)),
    );
  }

  // ---- 输入栏 ----

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: const BoxDecoration(
        color: CupertinoColors.tertiarySystemBackground,
        border: Border(
          top: BorderSide(color: CupertinoColors.systemGrey5, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(36, 36),
            onPressed: _toggleListen,
            child: Icon(
              _listening ? CupertinoIcons.stop_circle : CupertinoIcons.mic,
              size: 26,
              color: _listening ? CupertinoColors.systemRed : _kIndigo,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: CupertinoTextField(
              controller: _inputCtrl,
              focusNode: _inputFocus,
              minLines: 1,
              maxLines: 3,
              placeholder: _listening
                  ? '正在聆听，说出${_dayLabel()}要做的事…'
                  : '为${_dayLabel()}安排：点麦克风说话或输入…',
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CupertinoColors.systemGrey4),
              ),
              onSubmitted: (_) => _generatePlan(),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: Size.zero,
            onPressed: _generating ? null : _generatePlan,
            child: _generating
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : const Text('生成计划',
                    style: TextStyle(fontSize: 14, color: CupertinoColors.white)),
          ),
        ],
      ),
    );
  }

  // ---------------- 工具 ----------------

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  String _dayLabel() {
    final diff = _selectedDay.difference(_today()).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    if (diff == -1) return '昨天';
    const weeks = ['一', '二', '三', '四', '五', '六', '日'];
    return '${_selectedDay.month}月${_selectedDay.day}日（周${weeks[_selectedDay.weekday - 1]}）';
  }

  String _fmtMin(int minutes) {
    if (minutes < 60) return '$minutes分钟';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h小时' : '$h小时$m分';
  }

  @override
  void dispose() {
    _dueCheckTimer?.cancel();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    // 页面销毁时若识别仍在运行，stop() 的异常不能被丢弃（会变成未捕获异步错误）
    unawaited(Future<void>.sync(_speech.stop).catchError((Object e) {
      debugPrint('[planner] dispose 停止语音识别异常：$e');
    }));
    _engine.dispose();
    super.dispose();
  }
}
