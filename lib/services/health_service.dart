// 健康综合评分：与首页仪表盘同源的算法，拆成可复用的明细结构
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/exercise_record.dart';
import '../models/weight_record.dart';
import '../models/habit.dart';
import '../models/sleep_record.dart';
import '../services/db_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';

class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  Future<HealthBreakdown> load() async {
    final now = DateTime.now();
    final ex = await DbService.instance.getExercises();
    final weights = await DbService.instance.getWeights();
    final habits = await DbService.instance.getHabits();
    final checks = await DbService.instance.getChecks();
    final weeklyGoal = await SettingsService.instance.exerciseWeeklyGoal;
    final weightGoal = await SettingsService.instance.weightGoal;
    final height = await SettingsService.instance.heightCm;
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final sleep = await DbService.instance.getSleepByDate(todayKey);

    // 近 7 天睡眠，用于趋势条
    final recent = <String>[];
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      recent.add(DateFormat('yyyy-MM-dd').format(d));
    }
    final sleepMap = <String, SleepRecord?>{};
    for (final d in recent) {
      sleepMap[d] = await DbService.instance.getSleepByDate(d);
    }

    // ---- 运动（25）----
    final weekDays = _weekDays(ex, now);
    final weekMinutes = _weekMinutes(ex, now);
    late double exerciseScore;
    late String exerciseDetail;
    if (weeklyGoal > 0) {
      exerciseScore = (weekDays / weeklyGoal * 25).clamp(0, 25);
      exerciseDetail = '本周运动 $weekDays/$weeklyGoal 天'
          '${weekMinutes > 0 ? '，$weekMinutes 分钟' : ''}';
    } else {
      exerciseScore = weekDays > 0 ? 25 : 0;
      exerciseDetail = weekDays > 0 ? '本周运动 $weekDays 天' : '本周还没运动';
    }

    // ---- 习惯（25）----
    final habitsToday = habits.where((h) => h.shouldCheckToday()).length;
    final checkedToday =
        checks.where((c) => c.date == todayKey).map((c) => c.habitId).toSet();
    late double habitScore;
    late String habitDetail;
    if (habitsToday > 0) {
      habitScore = (checkedToday.length / habitsToday * 25).clamp(0, 25);
      habitDetail = '今日 ${checkedToday.length}/$habitsToday 项习惯完成';
    } else {
      habitScore = 0;
      habitDetail = '今天没有待打卡习惯';
    }

    // ---- 睡眠（25）----
    late double sleepScore;
    late String sleepDetail;
    if (sleep == null) {
      sleepScore = 0;
      sleepDetail = '今天还没记录睡眠';
    } else if (sleep.durationHours >= 7) {
      sleepScore = 25;
      sleepDetail = '睡眠 ${sleep.durationHours.toStringAsFixed(1)}h，已达标';
    } else {
      sleepScore = (sleep.durationHours / 7 * 25).clamp(0, 25);
      sleepDetail = '睡眠 ${sleep.durationHours.toStringAsFixed(1)}h，不足 7h';
    }

    // ---- 体重趋势（25）----
    late double weightScore;
    late String weightDetail;
    if (weightGoal > 0 && weights.isNotEmpty) {
      final base = weights.first.weightKg;
      final latest = weights.last.weightKg;
      double progress;
      if ((base - weightGoal).abs() < 0.01) {
        progress = 1;
      } else {
        final total = base - weightGoal;
        final done = base - latest;
        progress = (done / total).clamp(0.0, 1.0);
      }
      weightScore = (progress * 25).clamp(0, 25);
      final diff = latest - weightGoal;
      weightDetail = '当前 ${latest.toStringAsFixed(1)}kg，距目标 '
          '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}kg，'
          '进度 ${(progress * 100).toStringAsFixed(0)}%';
    } else {
      weightScore = 0;
      weightDetail = weightGoal <= 0 ? '尚未设定体重目标' : '还没有体重记录';
    }

    final total = exerciseScore + habitScore + sleepScore + weightScore;

    return HealthBreakdown(
      total: total,
      dims: [
        HealthDim(
          key: 'exercise',
          name: '运动',
          icon: Icons.directions_run,
          color: Colors.orange,
          score: exerciseScore,
          detail: exerciseDetail,
          formula: '本周运动天数 ÷ 周目标天数 × 25（未设目标时，运动即满分 25）',
          advice: weeklyGoal <= 0
              ? '去设置页设定「每周运动目标天数」，评分才有抓手'
              : '保持每周至少 $weeklyGoal 天、累计约 150 分钟有氧运动',
        ),
        HealthDim(
          key: 'habit',
          name: '习惯',
          icon: Icons.repeat,
          color: AppTheme.accent,
          score: habitScore,
          detail: habitDetail,
          formula: '今日已完成习惯数 ÷ 今日应打卡习惯数 × 25',
          advice: habitsToday == 0
              ? '在习惯页添加每日习惯并开始打卡'
              : '把习惯固化成每天自动完成的动作，连续达标解锁 🏆',
        ),
        HealthDim(
          key: 'sleep',
          name: '睡眠',
          icon: Icons.bedtime,
          color: Colors.indigo,
          score: sleepScore,
          detail: sleepDetail,
          formula: '睡眠时长 ÷ 7h × 25（满 7h 即满分 25）',
          advice: sleep == null
              ? '睡前在「设备」页记录昨晚的睡眠'
              : '尽量 23 点前入睡，保证 7 小时以上睡眠',
        ),
        HealthDim(
          key: 'weight',
          name: '体重',
          icon: Icons.monitor_weight,
          color: Colors.purple,
          score: weightScore,
          detail: weightDetail,
          formula: '减重进度（已减重量 ÷ 目标差）× 25；需设目标且有记录',
          advice: weightGoal <= 0
              ? '在设置页设定体重目标，评分才有基准'
              : '保持热量缺口，每周称重 1–2 次看趋势而非单日波动',
        ),
      ],
      sleepTrend: recent.map((d) => sleepMap[d]?.durationHours ?? 0).toList(),
      sleepTrendDays: recent,
    );
  }

  int _weekDays(List<ExerciseRecord> ex, DateTime now) {
    final start = now.subtract(Duration(days: now.weekday - 1));
    final s = DateTime(start.year, start.month, start.day);
    final byDay = <String>{};
    for (final e in ex) {
      byDay.add(DateFormat('yyyy-MM-dd').format(e.performedAt));
    }
    int c = 0;
    for (int i = 0; i < 7; i++) {
      if (byDay.contains(DateFormat('yyyy-MM-dd').format(s.add(Duration(days: i))))) c++;
    }
    return c;
  }

  int _weekMinutes(List<ExerciseRecord> ex, DateTime now) {
    final start = now.subtract(Duration(days: now.weekday - 1));
    final s = DateTime(start.year, start.month, start.day);
    return ex
        .where((e) => !e.performedAt.isBefore(s))
        .fold<int>(0, (a, e) => a + e.durationMinutes);
  }
}

class HealthDim {
  final String key;
  final String name;
  final IconData icon;
  final Color color;
  final double score; // 0~25
  final String detail;
  final String formula;
  final String advice;
  const HealthDim({
    required this.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.score,
    required this.detail,
    required this.formula,
    required this.advice,
  });
}

class HealthBreakdown {
  final double total; // 0~100
  final List<HealthDim> dims;
  final List<double> sleepTrend; // 近 7 天睡眠小时
  final List<String> sleepTrendDays;
  HealthBreakdown({
    required this.total,
    required this.dims,
    required this.sleepTrend,
    required this.sleepTrendDays,
  });
}
