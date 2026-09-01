import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show AlwaysStoppedAnimation, LinearProgressIndicator, ScaffoldMessenger, SnackBar;

import 'dart:convert';

import '../../models/health_models.dart';
import '../../models/planner_models.dart';
import '../../services/health_plan_service.dart';
import '../../services/health_store.dart';
import '../../services/health_api.dart';
import '../../services/planner_store.dart';

const _kIndigo = Color(0xFF5E5CE6);
const _kGreen = Color(0xFF30B06A);

/// 健康底座页
///
/// 核心立场：**健康不是工作的对立面，是认知产能的维护成本。**
/// 靠脑力吃饭，睡够、动够、吃对，保护的就是赚钱的那台发动机。
///
/// 页面四块：阶段推进 → 今日 12 项打卡 → 崩盘兜底 → 作息与周/月/季节奏。
/// 打卡数据全部落本机 SharedPreferences，与计划表共用一套本地存储。
class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  Map<String, Map<String, double>> _logs = {};
  int _phaseIndex = 0;
  final DateTime _day = _today();
  bool _loading = true;
  String? _error;
  bool _showInactive = false;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await HealthStore.loadLogs();
      final phase = await HealthStore.loadPhase();
      await HealthStore.loadStartDate();
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _phaseIndex = phase;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  HealthPhase get _phase => HealthPhases.at(_phaseIndex);

  HealthDayStatus get _status => HealthPlanService.dayStatus(
        day: _day,
        logs: _logs,
        phase: _phase,
      );

  HealthPhaseEvaluation get _evaluation => HealthPlanService.evaluate(
        today: _day,
        logs: _logs,
        unlockedPhase: _phaseIndex,
      );

  // ---------------- 操作 ----------------

  Future<void> _setMet(HealthHabit h, bool met) async {
    final v = met ? h.passValue : 0.0;
    _logs = await HealthStore.setValue(_day, h.id, v);
    if (mounted) setState(() {});
  }

  Future<void> _adjust(HealthHabit h, double delta) async {
    final cur = HealthPlanService.aggregate(_logs, _day, h);
    final next = (cur + delta).clamp(0.0, 99999.0);
    _logs = await HealthStore.setValue(
        _day, h.id, ((next * 10).round() / 10));
    if (mounted) setState(() {});
  }

  Future<void> _input(HealthHabit h) async {
    final ctrl = TextEditingController(
      text: HealthPlanService.aggregate(_logs, _day, h).toStringAsFixed(
        h.step < 1 ? 1 : 0,
      ),
    );
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(h.title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Text(h.target,
                  style: const TextStyle(
                      fontSize: 12, color: CupertinoColors.systemGrey)),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                placeholder: '输入数值（${h.valueLabel}）',
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final v = double.tryParse(ctrl.text.trim());
    if (v == null) return;
    _logs = await HealthStore.setValue(_day, h.id, v);
    if (mounted) setState(() {});
  }

  Future<void> _advancePhase() async {
    final next = (_phaseIndex + 1).clamp(0, 3);
    await HealthStore.savePhase(next);
    await _reload();
    _toast('已进入${HealthPhases.at(next).title}');
  }

  Future<void> _applyDayTemplate() async {
    final tasks = HealthPlanService.buildDayTemplate(_day, phase: _phase);
    await PlannerStore.appendAll(tasks);
    _toast('已排入 ${tasks.length} 项作息任务，回到计划表即可执行');
  }

  Future<void> _applyMinimumDose() async {
    final d = _day;
    final rows = <(String, int, int, int)>[
      ('早躺 5 分钟（比昨天多睡 5 分钟）', 22, 55, 5),
      ('多动 1.9 分钟（爬楼/快走到微喘）', 18, 0, 2),
      ('加半份蔬菜（约 40g）', 12, 30, 5),
    ];
    await PlannerStore.appendAll([
      for (var i = 0; i < rows.length; i++)
        PlannerTask(
          id: 'min-dose-${d.year}${d.month}${d.day}-$i',
          title: '兜底 · ${rows[i].$1}',
          estimateMinutes: rows[i].$4,
          priority: TaskPriority.medium,
          start: DateTime(d.year, d.month, d.day, rows[i].$2, rows[i].$3),
        ),
    ]);
    _toast('已排入 3 项兜底微任务，忙到炸的一天做完就算没断');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  // ---------------- AI ----------------

  Future<void> _generatePlan() async {
    _toast('正在调用 AI 生成今日计划…');
    try {
      final res = await HealthApi.generatePlan('daily');
      // 后端实际返回 data = { plan: { content, summary, provider, ... } }，
      // 而 _assertOk 返回的是 data 本体，因此必须再取一层 'plan'。
      final planMap = (res['plan'] as Map<String, dynamic>?) ?? res;
      final rawContent = planMap['content'] as String?;
      final parsed = _safeJson(rawContent);
      final summary =
          (planMap['summary'] as String?) ?? (res['summary'] as String?);
      if (!mounted) return;
      await _showContentDialog(
          'AI 今日计划', _aiPlanWidget(parsed, summary, rawContent));
    } catch (e) {
      _toast('AI 生成失败：$e');
    }
  }

  /// 可滚动的大弹窗，用于展示 AI 产出内容。
  ///
  /// CupertinoAlertDialog 可用空间极小，AI 长文本（近千字的 focus + actions）
  /// 会被裁剪甚至溢出，表现为"生成内容不可见"。这里改用可滚动、占屏 78% 的弹窗。
  Future<void> _showContentDialog(String title, Widget content) {
    return showCupertinoModalPopup(
      context: context,
      builder: (ctx) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: CupertinoPopupSurface(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.78,
                  maxWidth: 520,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w600)),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(28, 28),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Icon(CupertinoIcons.xmark_circle_fill,
                                size: 24,
                                color: CupertinoColors.systemGrey),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: CupertinoColors.separator),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                        child: content,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                      child: SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('好的'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _safeJson(String? s) {
    if (s == null) return null;
    try {
      final start = s.indexOf('{');
      final end = s.lastIndexOf('}');
      if (start < 0 || end < 0) return null;
      return jsonDecode(s.substring(start, end + 1));
    } catch (_) {
      return null;
    }
  }

  Widget _aiPlanWidget(Map<String, dynamic>? parsed, String? summary,
      [String? rawContent]) {
    if (parsed == null) {
      // JSON 解析失败时退回原始文本，避免只显示"无内容"而看不到 AI 产出
      final fallback = (summary != null && summary.trim().isNotEmpty)
          ? summary
          : (rawContent?.trim().isNotEmpty == true ? rawContent! : '');
      return Text(fallback.isEmpty ? '（无内容）' : fallback,
          style: const TextStyle(fontSize: 13));
    }
    final actions = (parsed['actions'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parsed['focus'] != null)
          Text(parsed['focus'] as String,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final a in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '• ${a['title'] ?? ''}：${a['target_today'] ?? ''}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        if (parsed['coach_note'] != null) ...[
          const SizedBox(height: 6),
          Text(parsed['coach_note'] as String,
              style: const TextStyle(
                  fontSize: 12, color: CupertinoColors.systemGrey)),
        ],
      ],
    );
  }

  Future<void> _openCoach() async {
    final ctrl = TextEditingController();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('AI 健康教练'),
        content: CupertinoTextField(
          controller: ctrl,
          placeholder: '问点什么，例如：今天太累怎么安排运动？',
          maxLines: 3,
        ),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('发送')),
        ],
      ),
    );
    if (ok != true) return;
    final msg = ctrl.text.trim();
    if (msg.isEmpty) return;
    _toast('AI 思考中…');
    try {
      final res = await HealthApi.coach(msg);
      // 后端返回的是 JSON 字符串，需取出 response 字段；解析失败则退回原文
      final raw = (res['content'] as String?) ?? '';
      final parsedReply = _safeJson(raw);
      final reply =
          (parsedReply?['response'] as String?) ?? (raw.isEmpty ? '（无回复）' : raw);
      if (!mounted) return;
      await _showContentDialog('AI 教练',
          Text(reply, style: const TextStyle(fontSize: 14, height: 1.45)));
    } catch (e) {
      _toast('AI 对话失败：$e');
    }
  }

  Widget _buildCoachCard() {
    return _card(
      title: 'AI 健康教练',
      trailing: '实时',
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 8),
          onPressed: _openCoach,
          child: const Text('问问 AI：今天太累怎么安排？ / 这周怎么补社交？',
              style: TextStyle(fontSize: 14, color: _kIndigo)),
        ),
      ),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
            middle: Text('健康底座',
                style: TextStyle(fontWeight: FontWeight.w600))),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.exclamationmark_triangle,
                      size: 40, color: CupertinoColors.systemRed),
                  const SizedBox(height: 12),
                  const Text('健康后端连接失败',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: CupertinoColors.systemGrey)),
                  const SizedBox(height: 16),
                  CupertinoButton.filled(
                    onPressed: _reload,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_loading) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    final ev = _evaluation;
    final st = _status;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('健康底座',
            style: TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _generatePlan,
              child: const Icon(CupertinoIcons.bolt,
                  size: 22, color: _kIndigo),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _applyDayTemplate,
              child: const Icon(CupertinoIcons.calendar_badge_plus,
                  size: 22, color: _kIndigo),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            _buildPhaseCard(ev, st),
            const SizedBox(height: 10),
            _buildHabitsCard(st),
            const SizedBox(height: 10),
            _buildMinimumDoseCard(),
            const SizedBox(height: 10),
            _buildTemplateCard(),
            const SizedBox(height: 10),
            _buildWeeklyCard(),
            const SizedBox(height: 10),
            _buildLongTermCard(),
            const SizedBox(height: 10),
            _buildCoachCard(),
            const SizedBox(height: 10),
            _buildDisclaimer(),
          ],
        ),
      ),
    );
  }

  // ---- 阶段卡 ----

  Widget _buildPhaseCard(HealthPhaseEvaluation ev, HealthDayStatus st) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
              const Icon(CupertinoIcons.heart_fill, size: 16, color: _kGreen),
              const SizedBox(width: 6),
              Text(ev.phase.title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('连续 ${ev.streak} 天',
                  style: const TextStyle(
                      fontSize: 12, color: CupertinoColors.systemGrey)),
            ],
          ),
          const SizedBox(height: 6),
          Text(ev.phase.focus,
              style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('今日达标 ${st.met}/${st.total}',
                  style: const TextStyle(fontSize: 12)),
              const Spacer(),
              Text(ev.phase.unlockText,
                  style: const TextStyle(
                      fontSize: 11, color: CupertinoColors.systemGrey)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ev.progress,
              minHeight: 6,
              backgroundColor: CupertinoColors.systemGrey5,
              valueColor: const AlwaysStoppedAnimation(_kGreen),
            ),
          ),
          if (ev.canAdvance) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 8),
                onPressed: _advancePhase,
                child: const Text('解锁下一阶段',
                    style: TextStyle(fontSize: 14, color: CupertinoColors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---- 今日打卡 ----

  Widget _buildHabitsCard(HealthDayStatus st) {
    final activeIds = _phase.habitIds;
    final active = activeIds.map(HealthItems.byId).toList();
    final inactive =
        HealthItems.all.where((h) => !activeIds.contains(h.id)).toList();
    return _card(
      title: '今日打卡',
      trailing: '${st.met}/${st.total} 达标',
      child: Column(
        children: [
          for (final h in active) _habitRow(h, locked: false),
          const SizedBox(height: 4),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => setState(() => _showInactive = !_showInactive),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showInactive
                      ? '收起其余 ${inactive.length} 条（不在当前阶段）'
                      : '展开其余 ${inactive.length} 条（不在当前阶段，可提前记录）',
                  style: const TextStyle(fontSize: 12, color: _kIndigo),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showInactive
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 12,
                  color: _kIndigo,
                ),
              ],
            ),
          ),
          if (_showInactive)
            for (final h in inactive) _habitRow(h, locked: true),
        ],
      ),
    );
  }

  Widget _habitRow(HealthHabit h, {required bool locked}) {
    final v = HealthPlanService.aggregate(_logs, _day, h);
    final met = h.isMet(v);
    final color = met
        ? _kGreen
        : locked
            ? CupertinoColors.systemGrey3
            : CupertinoColors.systemGrey;
    final isBool = h.kind == HabitValueKind.boolean;
    final period = switch (h.cadence) {
      HabitCadence.daily => '',
      HabitCadence.weekly => '本周累计 ',
      HabitCadence.monthly => '本月记录 ',
      HabitCadence.quarterly => '本季记录 ',
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: CupertinoColors.systemGrey5, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _setMet(h, !met),
            child: Icon(
              met
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              size: 24,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (h.no > 0)
                      Text('${h.no}. ',
                          style: const TextStyle(
                              fontSize: 13, color: CupertinoColors.systemGrey)),
                    Expanded(
                      child: Text(h.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: locked
                                ? CupertinoColors.systemGrey
                                : CupertinoColors.label,
                          )),
                    ),
                    _levelChip(h),
                  ],
                ),
                const SizedBox(height: 3),
                Text(h.target,
                    style: const TextStyle(
                        fontSize: 11, color: CupertinoColors.systemGrey)),
                const SizedBox(height: 2),
                Text('$period${h.formatValue(v)}',
                    style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ),
          if (!isBool) ...[
            const SizedBox(width: 6),
            Column(
              children: [
                _stepBtn(CupertinoIcons.plus, () => _adjust(h, h.step)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _input(h),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('输入',
                        style: TextStyle(fontSize: 10, color: color)),
                  ),
                ),
                const SizedBox(height: 4),
                _stepBtn(CupertinoIcons.minus, () => _adjust(h, -h.step)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 22,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: CupertinoColors.systemGrey),
      ),
    );
  }

  Widget _levelChip(HealthHabit h) {
    final color = switch (h.level) {
      HabitLevel.a => _kGreen,
      HabitLevel.b => CupertinoColors.systemOrange,
      HabitLevel.c => CupertinoColors.systemBlue,
      HabitLevel.routine => _kIndigo,
    };
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('${h.level.short} · ${h.cadence.label}',
          style: TextStyle(fontSize: 10, color: color)),
    );
  }

  // ---- 崩盘兜底 ----

  Widget _buildMinimumDoseCard() {
    return _card(
      title: '崩盘兜底 · 最小剂量',
      trailing: '约 +1 年',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (title, detail) in MinimumDose.steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(CupertinoIcons.circle_fill,
                      size: 6, color: _kGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: CupertinoColors.label),
                        children: [
                          TextSpan(
                              text: '$title：',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          TextSpan(text: detail),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          const Text(MinimumDose.note,
              style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: CupertinoColors.systemGrey)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(vertical: 8),
              onPressed: _applyMinimumDose,
              child: const Text('今天只做这三件（排入计划表）',
                  style: TextStyle(fontSize: 14, color: CupertinoColors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 每日作息 ----

  Widget _buildTemplateCard() {
    final rows = HealthPlanService.buildDayTemplate(_day, phase: _phase);
    return _card(
      title: '每日时段表',
      trailing: '${rows.length} 项',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '上午认知峰值锁死 2×90 分钟深度工作，一天中最贵的时间只给最难的活；'
            '下午放协作、会议、交付；傍晚运动；晚上学习 + 纸质书（替代刷手机，'
            '同时护眼助眠）；22:30 断屏。每 50 分钟起身 3 分钟是硬约束。',
            style: TextStyle(fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 8),
          for (final t in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 46,
                    child: Text(
                      t.timeRange.split('-').first,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kIndigo),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(t.title,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  Text('${t.estimateMinutes}′',
                      style: const TextStyle(
                          fontSize: 11, color: CupertinoColors.systemGrey)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(vertical: 8),
              onPressed: _applyDayTemplate,
              child: const Text('排入今天的计划表',
                  style: TextStyle(fontSize: 14, color: CupertinoColors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 周节奏 ----

  Widget _buildWeeklyCard() {
    final today = HealthPlanService.weekdayAgenda(_day.weekday);
    return _card(
      title: '每周节奏',
      trailing: '',
      child: Column(
        children: [
          for (var w = 1; w <= 7; w++)
            () {
              final item = HealthPlanService.weekdayAgenda(w);
              if (item == null) return const SizedBox.shrink();
              final isToday = w == _day.weekday;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isToday
                      ? _kIndigo.withValues(alpha: 0.08)
                      : CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isToday ? _kIndigo : null,
                              )),
                        ),
                        Text('${item.minutes}′',
                            style: const TextStyle(
                                fontSize: 11,
                                color: CupertinoColors.systemGrey)),
                      ],
                    ),
                    if (isToday) ...[
                      const SizedBox(height: 4),
                      Text(item.detail,
                          style: const TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: CupertinoColors.systemGrey)),
                    ],
                  ],
                ),
              );
            }(),
          if (today != null) ...[
            const SizedBox(height: 8),
            Text('今天：${today.title}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kIndigo)),
          ],
        ],
      ),
    );
  }

  // ---- 月 / 季 ----

  Widget _buildLongTermCard() {
    return _card(
      title: '每月 / 每季',
      trailing: HealthPlanService.quarterLabel(_day),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('每月',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (final a in HealthPlanService.monthlyAgenda)
            _agendaRow(a, CupertinoColors.systemBlue),
          const SizedBox(height: 10),
          const Text('每季',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (final a in HealthPlanService.quarterlyAgenda)
            _agendaRow(a, CupertinoColors.systemOrange),
        ],
      ),
    );
  }

  Widget _agendaRow(AgendaItem a, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(a.detail,
                    style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: CupertinoColors.systemGrey)),
              ],
            ),
          ),
          if (a.minutes > 0)
            Text('${a.minutes}′',
                style: const TextStyle(
                    fontSize: 11, color: CupertinoColors.systemGrey)),
        ],
      ),
    );
  }

  // ---- 出处与免责 ----

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('出处纠正',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text(
            '网上流传的"柳叶刀 12 个延寿习惯"没有对应原文，是柳叶刀痴呆委员会'
            '（2020 年 12 项、2024 年更新为 14 项）、eClinicalMedicine 2026 的 '
            'SPAN 研究（UK Biobank 59,078 人，随访 8.1 年，只讲睡、动、吃三件事）'
            '被拼装后的产物，各版本条款互相矛盾。这里的 12 条是按证据强度重建的，'
            '不是照抄网传版本。',
            style: TextStyle(fontSize: 11, height: 1.5),
          ),
          SizedBox(height: 6),
          Text(
            '三条约束：① 别一次上 12 条，按 4 周阶段递进；'
            '② 崩盘日用最小剂量保住连续性；'
            '③ 9.35 年是观察性研究的组间差值（95% CI 6.67–11.63），不是因果，'
            '受试者中位年龄 64 岁，外推需打折。体检数值不能被"感觉良好"替代。',
            style: TextStyle(fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ---- 通用卡片 ----

  Widget _card({
    required String title,
    required String trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (trailing.isNotEmpty)
                Text(trailing,
                    style: const TextStyle(
                        fontSize: 12, color: CupertinoColors.systemGrey)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
