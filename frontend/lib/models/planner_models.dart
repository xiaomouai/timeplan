/// timePlan 计划表数据模型
library;

/// 任务优先级
enum TaskPriority { high, medium, low }

extension TaskPriorityX on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.high:
        return '高';
      case TaskPriority.medium:
        return '中';
      case TaskPriority.low:
        return '低';
    }
  }

  static TaskPriority fromName(String? name) {
    switch (name) {
      case 'high':
        return TaskPriority.high;
      case 'low':
        return TaskPriority.low;
      default:
        return TaskPriority.medium;
    }
  }
}

/// 任务执行状态（按当前时间自动判定）
enum TaskExecStatus { notStarted, inProgress, done, overdue }

extension TaskExecStatusX on TaskExecStatus {
  String get label {
    switch (this) {
      case TaskExecStatus.notStarted:
        return '未开始';
      case TaskExecStatus.inProgress:
        return '进行中';
      case TaskExecStatus.done:
        return '已完成';
      case TaskExecStatus.overdue:
        return '已逾期';
    }
  }
}

/// 番茄时长约定（分钟），模型与引擎共用
class PomodoroLength {
  static const int minutes = 25;
}

/// 单条计划任务
class PlannerTask {
  final String id;
  String title;
  int estimateMinutes;
  TaskPriority priority;
  DateTime start;
  bool done;
  int donePomodoros; // 已完成的专注番茄数
  DateTime? completedAt; // 实际完成时间点（执行情况核对）

  PlannerTask({
    required this.id,
    required this.title,
    required this.estimateMinutes,
    required this.priority,
    required this.start,
    this.done = false,
    this.donePomodoros = 0,
    this.completedAt,
  });

  /// 预计需要的番茄数（每番茄 25 分钟）
  int get plannedPomodoros =>
      (estimateMinutes / PomodoroLength.minutes).ceil().clamp(1, 12);

  /// 任务进度 0~1：按已完成番茄折算，完成即 100%
  double get progress => done
      ? 1.0
      : (donePomodoros * PomodoroLength.minutes / estimateMinutes)
          .clamp(0.0, 1.0);

  /// 已投入的实际专注分钟数
  int get focusMinutes => donePomodoros * PomodoroLength.minutes;

  /// 执行状态：已完成 > 进行中（有番茄）> 已逾期（结束时间过）> 未开始
  TaskExecStatus statusAt(DateTime now) {
    if (done) return TaskExecStatus.done;
    if (donePomodoros > 0) return TaskExecStatus.inProgress;
    if (end.isBefore(now)) return TaskExecStatus.overdue;
    return TaskExecStatus.notStarted;
  }

  DateTime get end => start.add(Duration(minutes: estimateMinutes));

  String get timeRange {
    final hh = start.hour.toString().padLeft(2, '0');
    final mm = start.minute.toString().padLeft(2, '0');
    final eh = end.hour.toString().padLeft(2, '0');
    final em = end.minute.toString().padLeft(2, '0');
    return '$hh:$mm-$eh:$em';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'estimateMinutes': estimateMinutes,
        'priority': priority.name,
        'start': start.toIso8601String(),
        'done': done,
        'donePomodoros': donePomodoros,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory PlannerTask.fromJson(Map<String, dynamic> json) => PlannerTask(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '未命名任务',
        estimateMinutes: (json['estimateMinutes'] as num?)?.toInt() ?? 30,
        priority: TaskPriorityX.fromName(json['priority'] as String?),
        start:
            DateTime.tryParse(json['start'] as String? ?? '') ?? DateTime.now(),
        done: (json['done'] as bool?) ?? false,
        donePomodoros: (json['donePomodoros'] as num?)?.toInt() ?? 0,
        completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      );
}

/// 一次"语音/文本 → 分解 → 排程"的结果
class PlannerPlan {
  final List<PlannerTask> tasks;
  final String source; // 'ai' 或 'local'
  final String note; // 降级原因等说明

  const PlannerPlan({
    required this.tasks,
    required this.source,
    this.note = '',
  });
}
