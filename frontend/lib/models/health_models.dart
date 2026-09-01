/// 健康底座数据模型
///
/// 设计立场：**健康不是工作的对立面，是认知产能的维护成本。**
///
/// 12 条证据项不是网传的"柳叶刀 12 条"（那份清单没有对应原文），
/// 而是按证据强度重建的：
/// - A 级 5 条：eClinicalMedicine 2026（SPAN，UK Biobank 59,078 人，随访 8.1 年）
///   与柳叶刀委员会给出明确阈值的项；
/// - B 级 5 条：柳叶刀痴呆委员会 2020/2024 的可改变风险因素，靠测量或体检确认；
/// - C 级 2 条：委员会"保持认知、身体、社交活跃"的推荐，无单一活动证据，但零风险。
/// 另有 1 条执行项（每 50 分钟起身），是硬约束而非证据条目。
library;

/// 证据等级
enum HabitLevel { a, b, c, routine }

extension HabitLevelX on HabitLevel {
  /// 短标签，用于列表徽章
  String get short => switch (this) {
        HabitLevel.a => 'A',
        HabitLevel.b => 'B',
        HabitLevel.c => 'C',
        HabitLevel.routine => '节奏',
      };

  /// 等级含义
  String get label => switch (this) {
        HabitLevel.a => 'A 级 · 研究给出明确阈值',
        HabitLevel.b => 'B 级 · 需测量或体检确认',
        HabitLevel.c => 'C 级 · 委员会推荐，无单一活动证据',
        HabitLevel.routine => '执行项 · 硬约束，不是证据条目',
      };
}

/// 打卡频率：决定达标值如何聚合
enum HabitCadence { daily, weekly, monthly, quarterly }

extension HabitCadenceX on HabitCadence {
  String get label => switch (this) {
        HabitCadence.daily => '每天',
        HabitCadence.weekly => '每周',
        HabitCadence.monthly => '每月',
        HabitCadence.quarterly => '每季',
      };
}

/// 数值类型：决定单位、步进与输入方式
enum HabitValueKind { boolean, hours, minutes, score, count, number }

extension HabitValueKindX on HabitValueKind {
  String get unit => switch (this) {
        HabitValueKind.boolean => '',
        HabitValueKind.hours => '小时',
        HabitValueKind.minutes => '分钟',
        HabitValueKind.score => '分',
        HabitValueKind.count => '次',
        HabitValueKind.number => '',
      };
}

/// 单条健康习惯
class HealthHabit {
  final String id;
  /// 编号：1~12 为证据项，0 为执行项
  final int no;
  final String title;
  final HabitLevel level;
  final HabitCadence cadence;
  final HabitValueKind kind;
  /// 阈值说明（展示用）
  final String target;
  /// 出处（展示用）
  final String source;
  /// 达标下限（含）
  final double? min;
  /// 达标上限
  final double? max;
  /// 上限是否取严格小于
  final bool maxExclusive;
  /// 步进
  final double step;
  /// 单位后缀（number 类型用，如 mmHg、mmol/L）
  final String suffix;
  /// 操作提示
  final String hint;

  const HealthHabit({
    required this.id,
    required this.no,
    required this.title,
    required this.level,
    required this.cadence,
    required this.kind,
    required this.target,
    required this.source,
    this.min,
    this.max,
    this.maxExclusive = false,
    this.step = 1,
    this.suffix = '',
    this.hint = '',
  });

  bool get isEvidence => level != HabitLevel.routine;

  /// 达标判定：布尔项看是否勾选；数值项看是否落在区间内
  bool isMet(double value) {
    if (kind == HabitValueKind.boolean) return value >= 1;
    if (min != null && value < min!) return false;
    if (max != null) {
      return maxExclusive ? value < max! : value <= max!;
    }
    return true;
  }

  /// 一键达标时的填充值（对齐步进后仍必须落在达标区间内）
  double get passValue {
    if (kind == HabitValueKind.boolean) return 1;
    final raw = _rawPassValue;
    if (step <= 0) return raw;
    var snapped = ((raw / step).round() * step * 10).round() / 10;
    // 吸附后掉到下限以下 → 向上取到下一个步进（如 42 分钟吸附成 40，需回到 45）
    if (min != null && snapped < min!) {
      snapped = (((min! / step).ceil() * step) * 10).round() / 10;
    }
    // 吸附后越过上限 → 向下取到上一个步进
    if (max != null) {
      if (maxExclusive && snapped >= max!) {
        snapped = ((max! - step) * 10).round() / 10;
      } else if (!maxExclusive && snapped > max!) {
        snapped = (max! * 10).round() / 10;
      }
    }
    return snapped;
  }

  double get _rawPassValue {
    if (min != null && max != null) return (min! + max!) / 2;
    if (min != null) return min!;
    if (max != null) return maxExclusive ? max! - step : max!;
    return 1;
  }

  /// 展示用数值文本
  String formatValue(double v) {
    if (kind == HabitValueKind.boolean) return v >= 1 ? '已达标' : '未记录';
    if (kind == HabitValueKind.hours) return '${v.toStringAsFixed(1)} 小时';
    if (kind == HabitValueKind.score) return '${v.toStringAsFixed(0)} 分';
    if (kind == HabitValueKind.count) {
      return '${v.toStringAsFixed(0)} ${kind.unit}';
    }
    if (kind == HabitValueKind.minutes) {
      return '${v.toStringAsFixed(0)} 分钟';
    }
    final s = v.toStringAsFixed(step < 1 ? 1 : 0);
    return suffix.isEmpty ? s : '$s $suffix';
  }

  String get valueLabel =>
      kind == HabitValueKind.boolean ? '勾选' : (suffix.isEmpty ? kind.unit : suffix);
}

/// 12 条证据项 + 1 条执行项
abstract class HealthItems {
  static const HealthHabit sleep = HealthHabit(
    id: 'sleep',
    no: 1,
    title: '睡眠 7.2–8.0 小时，固定作息',
    level: HabitLevel.a,
    cadence: HabitCadence.daily,
    kind: HabitValueKind.hours,
    target: '7.2–8.0 小时／天，起床时间固定',
    source: 'SPAN（eClinicalMedicine 2026）最佳区间',
    min: 7.2,
    max: 8.0,
    step: 0.5,
    hint: '固定起床时间比固定入睡时间更有效；23:00 睡 → 07:00 起。',
  );

  static const HealthHabit exercise = HealthHabit(
    id: 'exercise',
    no: 2,
    title: '中高强度运动 >42 分钟',
    level: HabitLevel.a,
    cadence: HabitCadence.daily,
    kind: HabitValueKind.minutes,
    target: '≥42 分钟／天，微喘、心跳加快即可',
    source: 'SPAN（eClinicalMedicine 2026）',
    min: 42,
    step: 5,
    hint: '不需要健身房，快走坡度、爬楼、骑行都算，心率上到微喘即可。',
  );

  static const HealthHabit diet = HealthHabit(
    id: 'diet',
    no: 3,
    title: '膳食质量评分 57.5–72.5',
    level: HabitLevel.a,
    cadence: HabitCadence.daily,
    kind: HabitValueKind.score,
    target: '10 项各 10 分，得 60–70 分（原报告区间 57.5–72.5）',
    source: 'SPAN（eClinicalMedicine 2026）',
    min: 57.5,
    max: 72.5,
    step: 10,
    hint: '10 项：蔬果、全谷物、鱼、坚果、奶制品 / 少红肉、少加工肉、'
        '少精制谷物、少含糖饮料、少盐。吃到 6–7 项即达标。',
  );

  static const HealthHabit nosmoke = HealthHabit(
    id: 'nosmoke',
    no: 4,
    title: '零吸烟（含电子烟、二手烟）',
    level: HabitLevel.a,
    cadence: HabitCadence.daily,
    kind: HabitValueKind.boolean,
    target: '0 支，含电子烟，避开二手烟环境',
    source: '柳叶刀痴呆委员会 2020 / 2024',
    hint: '没有安全剂量，只有 0。',
  );

  static const HealthHabit alcohol = HealthHabit(
    id: 'alcohol',
    no: 5,
    title: '限酒 <21 单位／周',
    level: HabitLevel.a,
    cadence: HabitCadence.weekly,
    kind: HabitValueKind.count,
    target: '<21 单位／周（约 10 瓶啤酒），最好不喝',
    source: '柳叶刀痴呆委员会（>21 单位／周为风险因素）',
    max: 21,
    maxExclusive: true,
    step: 1,
    hint: '1 单位 ≈ 250ml 啤酒 / 125ml 葡萄酒 / 40ml 烈酒。按周累计。',
  );

  static const HealthHabit bp = HealthHabit(
    id: 'bp',
    no: 6,
    title: '血压 <130 mmHg',
    level: HabitLevel.b,
    cadence: HabitCadence.quarterly,
    kind: HabitValueKind.number,
    target: '收缩压 <130 mmHg（中年期起干预收益最大）',
    source: '柳叶刀痴呆委员会 2020',
    max: 130,
    maxExclusive: true,
    step: 1,
    suffix: 'mmHg',
    hint: '填收缩压（高压）。家庭自测取晨起静坐 5 分钟后读数。',
  );

  static const HealthHabit ldl = HealthHabit(
    id: 'ldl',
    no: 7,
    title: 'LDL 胆固醇达标',
    level: HabitLevel.b,
    cadence: HabitCadence.quarterly,
    kind: HabitValueKind.number,
    target: 'LDL-C <3.4 mmol/L（高危人群目标更严，遵医嘱）',
    source: '柳叶刀痴呆委员会 2024 更新（新增，约 7%）',
    max: 3.4,
    maxExclusive: true,
    step: 0.1,
    suffix: 'mmol/L',
    hint: '目标值按个人心血管风险分层，由医生定，不要自己调药。',
  );

  static const HealthHabit vision = HealthHabit(
    id: 'vision',
    no: 8,
    title: '视力受损及时矫正',
    level: HabitLevel.b,
    cadence: HabitCadence.quarterly,
    kind: HabitValueKind.boolean,
    target: '本季度已检查，受损已矫正（含老花、白内障）',
    source: '柳叶刀痴呆委员会 2024 更新（新增，约 2%）',
    hint: '这是 2024 年新增的两项之一，成本极低、收益明确。',
  );

  static const HealthHabit hearing = HealthHabit(
    id: 'hearing',
    no: 9,
    title: '听力受损及时干预',
    level: HabitLevel.b,
    cadence: HabitCadence.quarterly,
    kind: HabitValueKind.boolean,
    target: '本季度已检查，受损已配助听器',
    source: '柳叶刀痴呆委员会（听力损失为最大单项可改变因素）',
    hint: '助听器是性价比最高的一项干预，别拖。',
  );

  static const HealthHabit metabolic = HealthHabit(
    id: 'metabolic',
    no: 10,
    title: '体重与血糖达标',
    level: HabitLevel.b,
    cadence: HabitCadence.monthly,
    kind: HabitValueKind.number,
    target: 'BMI 18.5–24，腰围 <90（男）/<85（女），HbA1c <5.7%',
    source: '柳叶刀痴呆委员会（肥胖、糖尿病）',
    min: 18.5,
    max: 24,
    step: 0.1,
    suffix: 'BMI',
    hint: '每月记体重腰围与静息心率，HbA1c 随季度体检走。',
  );

  static const HealthHabit cognition = HealthHabit(
    id: 'cognition',
    no: 11,
    title: '持续认知活跃',
    level: HabitLevel.c,
    cadence: HabitCadence.daily,
    kind: HabitValueKind.minutes,
    target: '学习 45 分钟 + 纸质书 30 分钟（合计 ≥75 分钟）',
    source: '柳叶刀委员会：推荐保持认知活跃，但无单一活动证据',
    min: 75,
    step: 5,
    hint: '委员会原话是"没有证据表明任何单一活动有保护作用"，'
        '所以形式自由——你的学习 + 看书正好挂在这一条。',
  );

  static const HealthHabit social = HealthHabit(
    id: 'social',
    no: 12,
    title: '线下社交 + 减压',
    level: HabitLevel.c,
    cadence: HabitCadence.weekly,
    kind: HabitValueKind.minutes,
    target: '线下见面 ≥60 分钟／周（线上不算）',
    source: '柳叶刀委员会（社交隔离、抑郁）',
    min: 60,
    step: 5,
    hint: '周三固定线下社交 ≥1 小时，线上聊天不计入。',
  );

  /// 执行项：不是证据条目，是保护上面 12 条能长期执行的节奏约束
  static const HealthHabit breakMove = HealthHabit(
    id: 'break',
    no: 0,
    title: '每 50 分钟起身 3 分钟',
    level: HabitLevel.routine,
    cadence: HabitCadence.daily,
    kind: HabitValueKind.count,
    target: '≥6 次／天（一个完整工作日约 6–8 次）',
    source: '执行项 · 硬约束',
    min: 6,
    step: 1,
    hint: '这一条没有独立证据，但它决定了你能否连续坐住 2×90 分钟而不崩。',
  );

  static const List<HealthHabit> all = [
    sleep,
    exercise,
    diet,
    nosmoke,
    alcohol,
    bp,
    ldl,
    vision,
    hearing,
    metabolic,
    cognition,
    social,
    breakMove,
  ];

  static HealthHabit byId(String id) =>
      all.firstWhere((h) => h.id == id, orElse: () => sleep);

  static List<HealthHabit> byLevel(HabitLevel level) =>
      all.where((h) => h.level == level).toList();
}

/// 4 周落地阶段
///
/// 核心约束：**别一次上 12 条。** 每阶段只加 1 条，连续达标达标后再进下一阶段。
class HealthPhase {
  final int index;
  final String title;
  final String focus;
  final List<String> habitIds;
  /// 解锁下一阶段所需的连续达标天数
  final int unlockDays;

  const HealthPhase({
    required this.index,
    required this.title,
    required this.focus,
    required this.habitIds,
    required this.unlockDays,
  });

  String get unlockText => unlockDays == 0
      ? '已是最终阶段，长期保持'
      : '连续 $unlockDays 天达标 → 解锁下一阶段';

  List<HealthHabit> get habits =>
      habitIds.map(HealthItems.byId).toList();
}

abstract class HealthPhases {
  static const HealthPhase base = HealthPhase(
    index: 0,
    title: '第 1–2 周 · 打底',
    focus: '固定睡眠 + 每 50 分钟起身 + 蔬菜 300g',
    habitIds: ['sleep', 'break', 'diet'],
    unlockDays: 10,
  );

  static const HealthPhase move = HealthPhase(
    index: 1,
    title: '第 3 周 · 动起来',
    focus: '加入中高强度运动 ≥42 分钟／天',
    habitIds: ['sleep', 'break', 'diet', 'exercise'],
    unlockDays: 7,
  );

  static const HealthPhase mind = HealthPhase(
    index: 2,
    title: '第 4 周 · 认知产能',
    focus: '加入学习 45 分钟 + 纸质书 30 分钟',
    habitIds: ['sleep', 'break', 'diet', 'exercise', 'cognition'],
    unlockDays: 7,
  );

  static const HealthPhase full = HealthPhase(
    index: 3,
    title: '第 5 周起 · 全量',
    focus: '12 条证据项全量打卡，测量项按周期核对',
    habitIds: [
      'sleep',
      'exercise',
      'diet',
      'nosmoke',
      'alcohol',
      'bp',
      'ldl',
      'vision',
      'hearing',
      'metabolic',
      'cognition',
      'social',
      'break',
    ],
    unlockDays: 0,
  );

  static const List<HealthPhase> all = [base, move, mind, full];

  static HealthPhase at(int index) => all[index.clamp(0, all.length - 1)];
}

/// 崩盘兜底：SPAN 最小有效剂量
///
/// 忙到炸的一天，只做这三件也不算断：
/// 多睡 5 分钟 + 多动 1.9 分钟 + 多半份蔬菜 → 约 +1 年预期寿命。
abstract class MinimumDose {
  static const List<(String, String)> steps = [
    ('多睡 5 分钟', '今晚比昨天早躺 5 分钟，别小看，剂量效应是连续的'),
    ('多动 1.9 分钟', '爬两层楼、快走一段，微喘即可'),
    ('多半份蔬菜', '任何一餐加半份蔬菜，约 40g'),
  ];

  static const String note =
      '9.35 年是观察性研究的组间差值（95% CI 6.67–11.63），不是因果；'
      '受试者中位年龄 64 岁，外推到你身上要打折看。'
      '体检数值是唯一不能靠"感觉良好"替代的东西。';
}
