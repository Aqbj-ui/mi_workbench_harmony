// 运动勋章体系：统计汇总 + 勋章定义与进度判定
import '../models/exercise_record.dart';

/// 运动统计汇总（勋章判定与统计页共用）
class ExerciseStats {
  final int totalCount; // 总次数
  final int totalMinutes; // 总时长（分钟）
  final int totalCalories; // 总消耗（千卡）
  final double totalDistanceKm; // 总距离
  final int activeDays; // 有运动的天数
  final int currentStreak; // 当前连续天数
  final int bestStreak; // 历史最佳连续天数
  final int longestSessionMin; // 单次最长时长
  final int distinctTypes; // 玩过的项目种类
  final int earlyBirdCount; // 早鸟：8 点前完成
  final int nightOwlCount; // 夜练：20 点后完成
  final int goalWeeks; // 达成周目标的周数
  final int highIntensityCount; // 高强度次数

  const ExerciseStats({
    this.totalCount = 0,
    this.totalMinutes = 0,
    this.totalCalories = 0,
    this.totalDistanceKm = 0,
    this.activeDays = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.longestSessionMin = 0,
    this.distinctTypes = 0,
    this.earlyBirdCount = 0,
    this.nightOwlCount = 0,
    this.goalWeeks = 0,
    this.highIntensityCount = 0,
  });

  /// 从记录列表计算全部统计
  factory ExerciseStats.from(
    List<ExerciseRecord> records, {
    double bodyWeightKg = 65,
    double weeklyGoal = 0,
  }) {
    if (records.isEmpty) return const ExerciseStats();

    int minutes = 0;
    int calories = 0;
    double distance = 0;
    int longest = 0;
    int early = 0;
    int night = 0;
    int high = 0;
    final types = <String>{};
    final days = <DateTime>{};

    for (final e in records) {
      minutes += e.durationMinutes;
      calories += e.caloriesWith(bodyWeightKg);
      distance += e.distanceKm;
      if (e.durationMinutes > longest) longest = e.durationMinutes;
      if (e.performedAt.hour < 8) early++;
      if (e.performedAt.hour >= 20) night++;
      if (e.intensity == Intensity.high) high++;
      types.add(e.name);
      days.add(DateTime(
          e.performedAt.year, e.performedAt.month, e.performedAt.day));
    }

    // 连续天数
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    int current = 0;
    // 今天没练不立刻断，从昨天起算
    if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
    while (days.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // 最佳连续
    final sorted = days.toList()..sort();
    int best = 0;
    int run = 0;
    DateTime? prev;
    for (final d in sorted) {
      if (prev != null && d.difference(prev).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      prev = d;
    }

    // 达成周目标的周数
    int goalWeeks = 0;
    if (weeklyGoal > 0) {
      final byWeek = <String, int>{};
      for (final d in days) {
        final monday = d.subtract(Duration(days: d.weekday - 1));
        final key = '${monday.year}-${monday.month}-${monday.day}';
        byWeek[key] = (byWeek[key] ?? 0) + 1;
      }
      for (final v in byWeek.values) {
        if (v >= weeklyGoal) goalWeeks++;
      }
    }

    return ExerciseStats(
      totalCount: records.length,
      totalMinutes: minutes,
      totalCalories: calories,
      totalDistanceKm: distance,
      activeDays: days.length,
      currentStreak: current,
      bestStreak: best,
      longestSessionMin: longest,
      distinctTypes: types.length,
      earlyBirdCount: early,
      nightOwlCount: night,
      goalWeeks: goalWeeks,
      highIntensityCount: high,
    );
  }
}

/// 勋章分组
class BadgeGroup {
  static const persist = '坚持';
  static const volume = '累积';
  static const challenge = '挑战';
  static const fun = '趣味';
}

class ExerciseBadge {
  final String id;
  final String emoji;
  final String name;
  final String desc;
  final String group;
  final int target;
  final int Function(ExerciseStats) progressOf;

  const ExerciseBadge({
    required this.id,
    required this.emoji,
    required this.name,
    required this.desc,
    required this.group,
    required this.target,
    required this.progressOf,
  });

  int progress(ExerciseStats s) {
    final p = progressOf(s);
    return p > target ? target : p;
  }

  bool unlocked(ExerciseStats s) => progressOf(s) >= target;

  double ratio(ExerciseStats s) {
    if (target <= 0) return 0;
    final r = progress(s) / target;
    return r > 1.0 ? 1.0 : r;
  }
}

/// 全部勋章（按分组排列）
const List<ExerciseBadge> kExerciseBadges = [
  // ---- 坚持 ----
  ExerciseBadge(
    id: 'first',
    emoji: '🌱',
    name: '迈出第一步',
    desc: '完成第 1 次运动记录',
    group: BadgeGroup.persist,
    target: 1,
    progressOf: _count,
  ),
  ExerciseBadge(
    id: 'streak3',
    emoji: '🔥',
    name: '三日不断',
    desc: '连续运动 3 天',
    group: BadgeGroup.persist,
    target: 3,
    progressOf: _bestStreak,
  ),
  ExerciseBadge(
    id: 'streak7',
    emoji: '⚡',
    name: '一周不倒',
    desc: '连续运动 7 天',
    group: BadgeGroup.persist,
    target: 7,
    progressOf: _bestStreak,
  ),
  ExerciseBadge(
    id: 'streak21',
    emoji: '💎',
    name: '习惯成型',
    desc: '连续运动 21 天，行为学上的习惯线',
    group: BadgeGroup.persist,
    target: 21,
    progressOf: _bestStreak,
  ),
  ExerciseBadge(
    id: 'streak66',
    emoji: '👑',
    name: '铁人意志',
    desc: '连续运动 66 天，习惯彻底固化',
    group: BadgeGroup.persist,
    target: 66,
    progressOf: _bestStreak,
  ),
  ExerciseBadge(
    id: 'goal4',
    emoji: '🎯',
    name: '目标达人',
    desc: '累计 4 周达成每周运动目标',
    group: BadgeGroup.persist,
    target: 4,
    progressOf: _goalWeeks,
  ),

  // ---- 累积 ----
  ExerciseBadge(
    id: 'count10',
    emoji: '🥉',
    name: '小试牛刀',
    desc: '累计运动 10 次',
    group: BadgeGroup.volume,
    target: 10,
    progressOf: _count,
  ),
  ExerciseBadge(
    id: 'count50',
    emoji: '🥈',
    name: '渐入佳境',
    desc: '累计运动 50 次',
    group: BadgeGroup.volume,
    target: 50,
    progressOf: _count,
  ),
  ExerciseBadge(
    id: 'count100',
    emoji: '🥇',
    name: '百炼成钢',
    desc: '累计运动 100 次',
    group: BadgeGroup.volume,
    target: 100,
    progressOf: _count,
  ),
  ExerciseBadge(
    id: 'min600',
    emoji: '⏱️',
    name: '十小时俱乐部',
    desc: '累计运动 600 分钟',
    group: BadgeGroup.volume,
    target: 600,
    progressOf: _minutes,
  ),
  ExerciseBadge(
    id: 'min3000',
    emoji: '🕰️',
    name: '五十小时',
    desc: '累计运动 3000 分钟',
    group: BadgeGroup.volume,
    target: 3000,
    progressOf: _minutes,
  ),
  ExerciseBadge(
    id: 'cal10000',
    emoji: '🍔',
    name: '烧掉一万卡',
    desc: '累计消耗 10000 千卡，约等于 20 个汉堡',
    group: BadgeGroup.volume,
    target: 10000,
    progressOf: _calories,
  ),

  // ---- 挑战 ----
  ExerciseBadge(
    id: 'long60',
    emoji: '💪',
    name: '一小时挑战',
    desc: '单次运动达到 60 分钟',
    group: BadgeGroup.challenge,
    target: 60,
    progressOf: _longest,
  ),
  ExerciseBadge(
    id: 'long120',
    emoji: '🦾',
    name: '两小时耐力',
    desc: '单次运动达到 120 分钟',
    group: BadgeGroup.challenge,
    target: 120,
    progressOf: _longest,
  ),
  ExerciseBadge(
    id: 'high20',
    emoji: '🌋',
    name: '高强度玩家',
    desc: '完成 20 次高强度运动',
    group: BadgeGroup.challenge,
    target: 20,
    progressOf: _highIntensity,
  ),
  ExerciseBadge(
    id: 'dist100',
    emoji: '🛣️',
    name: '百公里',
    desc: '累计运动距离达到 100 公里',
    group: BadgeGroup.challenge,
    target: 100,
    progressOf: _distanceKm,
  ),

  // ---- 趣味 ----
  ExerciseBadge(
    id: 'types5',
    emoji: '🎪',
    name: '全能选手',
    desc: '尝试过 5 种不同的运动项目',
    group: BadgeGroup.fun,
    target: 5,
    progressOf: _types,
  ),
  ExerciseBadge(
    id: 'early10',
    emoji: '🌅',
    name: '早鸟',
    desc: '10 次在早上 8 点前完成运动',
    group: BadgeGroup.fun,
    target: 10,
    progressOf: _early,
  ),
  ExerciseBadge(
    id: 'night10',
    emoji: '🌙',
    name: '夜练党',
    desc: '10 次在晚上 8 点后完成运动',
    group: BadgeGroup.fun,
    target: 10,
    progressOf: _night,
  ),
  ExerciseBadge(
    id: 'days100',
    emoji: '📅',
    name: '百日运动',
    desc: '累计 100 天有运动记录',
    group: BadgeGroup.fun,
    target: 100,
    progressOf: _activeDays,
  ),
];

// 顶层函数（const 列表里只能引用顶层/静态函数）
int _count(ExerciseStats s) => s.totalCount;
int _minutes(ExerciseStats s) => s.totalMinutes;
int _calories(ExerciseStats s) => s.totalCalories;
int _bestStreak(ExerciseStats s) => s.bestStreak;
int _longest(ExerciseStats s) => s.longestSessionMin;
int _types(ExerciseStats s) => s.distinctTypes;
int _early(ExerciseStats s) => s.earlyBirdCount;
int _night(ExerciseStats s) => s.nightOwlCount;
int _activeDays(ExerciseStats s) => s.activeDays;
int _goalWeeks(ExerciseStats s) => s.goalWeeks;
int _highIntensity(ExerciseStats s) => s.highIntensityCount;
int _distanceKm(ExerciseStats s) => s.totalDistanceKm.floor();

/// 已解锁勋章
List<ExerciseBadge> unlockedBadges(ExerciseStats s) =>
    kExerciseBadges.where((b) => b.unlocked(s)).toList();

/// 距离解锁最近的一枚（用于首页/激励提示）
ExerciseBadge? nextBadge(ExerciseStats s) {
  ExerciseBadge? best;
  double bestRatio = -1;
  for (final b in kExerciseBadges) {
    if (b.unlocked(s)) continue;
    final r = b.ratio(s);
    if (r > bestRatio) {
      bestRatio = r;
      best = b;
    }
  }
  return best;
}
