import 'dart:async';

import 'package:flutter/foundation.dart';

/// 番茄钟阶段
enum PomodoroPhase { idle, work, resting }

/// 番茄钟引擎：专注 25 分钟 → 休息 5 分钟，可暂停/提前完成/放弃。
/// 页面通过 [onWorkCompleted]/[onRestCompleted] 回调接入进度与提醒。
class PomodoroEngine extends ChangeNotifier {
  PomodoroPhase phase = PomodoroPhase.idle;
  int remainingSeconds = 0;
  int totalSeconds = 0;
  String? taskId;
  String? taskTitle;
  bool paused = false;

  static const int workMinutes = 25;
  static const int restMinutes = 5;

  Timer? _timer;

  bool get running => phase != PomodoroPhase.idle;
  double get sessionProgress =>
      totalSeconds == 0 ? 0 : 1 - remainingSeconds / totalSeconds;

  /// 一个工作番茄正常走完或被"提前完成"时回调（计入进度）
  void Function(String taskId)? onWorkCompleted;
  /// 休息结束时回调
  void Function()? onRestCompleted;

  /// 开始某任务的专注番茄
  void startWork({
    required String taskId,
    required String title,
    int minutes = workMinutes,
  }) {
    _timer?.cancel();
    this.taskId = taskId;
    taskTitle = title;
    phase = PomodoroPhase.work;
    paused = false;
    totalSeconds = remainingSeconds = minutes * 60;
    _tick();
  }

  /// 开始休息
  void startRest({int minutes = restMinutes}) {
    _timer?.cancel();
    phase = PomodoroPhase.resting;
    paused = false;
    totalSeconds = remainingSeconds = minutes * 60;
    _tick();
  }

  void pause() {
    if (!running || paused) return;
    paused = true;
    _timer?.cancel();
    notifyListeners();
  }

  void resume() {
    if (!running || !paused) return;
    paused = false;
    _tick();
  }

  /// 提前完成当前专注番茄（正常计入一个番茄进度）
  void finishWorkEarly() {
    if (phase != PomodoroPhase.work) return;
    _completeWork();
  }

  /// 跳过休息
  void skipRest() {
    if (phase != PomodoroPhase.resting) return;
    _completeRest();
  }

  /// 放弃当前阶段（不计进度）
  void stop() {
    _timer?.cancel();
    phase = PomodoroPhase.idle;
    taskId = null;
    taskTitle = null;
    paused = false;
    notifyListeners();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
        notifyListeners();
      }
      if (remainingSeconds == 0) {
        phase == PomodoroPhase.work ? _completeWork() : _completeRest();
      }
    });
    notifyListeners();
  }

  void _completeWork() {
    final tid = taskId;
    _timer?.cancel();
    phase = PomodoroPhase.idle;
    paused = false;
    notifyListeners();
    if (tid != null) onWorkCompleted?.call(tid);
  }

  void _completeRest() {
    _timer?.cancel();
    phase = PomodoroPhase.idle;
    paused = false;
    notifyListeners();
    onRestCompleted?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
