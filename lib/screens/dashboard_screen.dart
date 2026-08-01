// 首页仪表盘：聚合待办/记账/运动/体重/习惯的今日概览
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../models/transaction.dart';
import '../models/exercise_record.dart';
import '../models/weight_record.dart';
import '../models/habit.dart';
import '../models/sleep_record.dart';
import '../models/saving_goal.dart';
import '../data/exercise_badges.dart';
import '../services/db_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/theme_toggle_button.dart';
import '../services/health_service.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<String>? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Todo> _todos = [];
  List<Transaction> _tx = [];
  List<ExerciseRecord> _ex = [];
  List<WeightRecord> _weights = [];
  List<Habit> _habits = [];
  List<HabitCheck> _checks = [];
  double _budget = 0;
  double _weeklyGoal = 0;
  double _weightGoal = 0;
  double _height = 0;
  SleepRecord? _todaySleep;
  double _healthScore = 0;
  List<SavingGoal> _goals = [];
  double _savedTotal = 0;
  double _savingTarget = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final todos = await DbService.instance.getTodos();
    final tx = await DbService.instance.getTransactions(from: monthStart);
    final ex = await DbService.instance.getExercises();
    final weights = await DbService.instance.getWeights();
    final habits = await DbService.instance.getHabits();
    final checks = await DbService.instance.getChecks();
    final budget = await SettingsService.instance.monthlyBudget;
    final weeklyGoal = await SettingsService.instance.exerciseWeeklyGoal;
    final weightGoal = await SettingsService.instance.weightGoal;
    final height = await SettingsService.instance.heightCm;
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final sleep = await DbService.instance.getSleepByDate(todayKey);
    final goals = await DbService.instance.getSavingGoals();
    final savedMap = await DbService.instance.getSavedAmounts();
    double saved = 0, target = 0;
    for (final g in goals) {
      saved += savedMap[g.id] ?? 0;
      target += g.targetAmount;
    }

    if (mounted) {
      setState(() {
        _todos = todos; _tx = tx; _ex = ex; _weights = weights;
        _habits = habits; _checks = checks;
        _budget = budget; _weeklyGoal = weeklyGoal; _weightGoal = weightGoal; _height = height;
        _todaySleep = sleep;
        _goals = goals; _savedTotal = saved; _savingTarget = target;
        _healthScore = _computeHealthScore();
      });
    }
  }

  double _computeHealthScore() {
    // 健康综合评分：运动 25 + 习惯 25 + 睡眠 25 + 体重趋势 25
    double score = 0;
    score += (_weeklyGoal > 0
        ? (_weekDays / _weeklyGoal * 25).clamp(0, 25)
        : (_weekDays > 0 ? 25 : 0));
    score += (_habitsToday > 0
        ? (_todayChecked.length / _habitsToday * 25).clamp(0, 25)
        : 0);
    score += (_todaySleep == null
        ? 0
        : (_todaySleep!.durationHours >= 7
            ? 25
            : (_todaySleep!.durationHours / 7 * 25).clamp(0, 25)));
    if (_weightGoal > 0 && _weights.isNotEmpty) {
      score += (_progressToGoal() * 25).clamp(0, 25);
    }
    return score;
  }

  // 减重进度 0~1（首次记录为基线，目标为终点）
  double _progressToGoal() {
    if (_weightGoal <= 0 || _weights.isEmpty) return 0;
    final base = _weights.first.weightKg;
    final latest = _weights.last.weightKg;
    if ((base - _weightGoal).abs() < 0.01) return 1;
    final total = base - _weightGoal;
    final done = base - latest;
    return (done / total).clamp(0.0, 1.0);
  }

  // ---- 派生指标 ----
  int get _todoDone => _todos.where((t) => t.done).length;
  int get _todoTotal => _todos.length;
  int get _overdue => _todos.where((t) => t.isOverdue).length;
  /// 今日要处理：逾期 + 今天到期 + 无截止但重要/紧急
  int get _todoToday => _todos.where((t) {
        if (t.done) return false;
        if (t.isOverdue || t.isToday) return true;
        return t.dueAt == null && (t.priority == 'urgent' || t.priority == 'important');
      }).length;
  int get _todoBiz => _todos.where((t) => !t.done && t.isBusiness).length;
  double get _monthSpend =>
      _tx.where((t) => !t.isIncome).fold(0.0, (a, t) => a + t.amount);
  double get _monthIncome =>
      _tx.where((t) => t.isIncome).fold(0.0, (a, t) => a + t.amount);
  double get _monthBalance => _monthIncome - _monthSpend;
  double get _savingPct =>
      _savingTarget <= 0 ? 0 : (_savedTotal / _savingTarget).clamp(0.0, 1.0);
  /// 预计存满天数：剩余金额 ÷（本月结余 / 30）
  String get _savingEta {
    if (_savingTarget <= 0) return '';
    if (_savedTotal >= _savingTarget) return '已存满 🎉';
    final remain = _savingTarget - _savedTotal;
    if (_monthBalance <= 0) return '本月结余为负，暂无法估算';
    final days = (remain / (_monthBalance / 30)).ceil();
    return '预计约 $days 天存满';
  }

  Map<DateTime, List<ExerciseRecord>> get _byDay {
    final m = <DateTime, List<ExerciseRecord>>{};
    for (final e in _ex) {
      final d = DateTime(e.performedAt.year, e.performedAt.month, e.performedAt.day);
      m.putIfAbsent(d, () => []).add(e);
    }
    return m;
  }
  int get _streak {
    int s = 0;
    var d = DateTime.now();
    d = DateTime(d.year, d.month, d.day);
    while (_byDay.containsKey(d)) { s++; d = d.subtract(const Duration(days: 1)); }
    return s;
  }
  int get _weekDays {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final s = DateTime(start.year, start.month, start.day);
    int c = 0;
    for (int i = 0; i < 7; i++) if (_byDay.containsKey(s.add(Duration(days: i)))) c++;
    return c;
  }
  /// 本周运动总时长（分钟）
  int get _weekMinutes {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final s = DateTime(start.year, start.month, start.day);
    return _ex
        .where((e) => !e.performedAt.isBefore(s))
        .fold<int>(0, (a, e) => a + e.durationMinutes);
  }
  /// 已解锁运动勋章数
  int get _badgeCount => unlockedBadges(
        ExerciseStats.from(_ex,
            bodyWeightKg: _latestWeight > 0 ? _latestWeight : 65,
            weeklyGoal: _weeklyGoal),
      ).length;
  double get _latestWeight => _weights.isEmpty ? 0 : _weights.last.weightKg;
  String get _bmiLabel {
    if (_height <= 0 || _weights.isEmpty) return '';
    final m = _height / 100;
    final bmi = _latestWeight / (m * m);
    if (bmi < 18.5) return '偏瘦';
    if (bmi < 24) return '正常';
    if (bmi < 28) return '超重';
    return '肥胖';
  }
  int get _habitsToday => _habits.where((h) => h.shouldCheckToday()).length;
  Set<String> get _todayChecked {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _checks.where((c) => c.date == today).map((c) => c.habitId).toSet();
  }
  int _streakForHabit(String habitId) {
    final dates = _checks.where((c) => c.habitId == habitId).map((c) => c.date).toSet();
    final today = DateTime.now();
    final tk = DateFormat('yyyy-MM-dd').format(today);
    final yk = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 1)));
    if (!dates.contains(tk) && !dates.contains(yk)) return 0;
    int s = 0;
    var d = today;
    while (dates.contains(DateFormat('yyyy-MM-dd').format(d))) {
      s++;
      d = d.subtract(const Duration(days: 1));
    }
    return s;
  }
  bool get _habitAchieved =>
      _habits.any((h) => h.targetStreak > 0 && _streakForHabit(h.id) >= h.targetStreak);

  Future<void> _showHealthSheet() async {
    final b = await HealthService.instance.load();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('健康综合评分拆解', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
              const Spacer(),
              Text(b.total.toStringAsFixed(0), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const Text(' / 100', style: TextStyle(color: AppTheme.textMuted)),
            ]),
            const SizedBox(height: 12),
            ...b.dims.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(d.icon, color: d.color, size: 16),
                  const SizedBox(width: 6),
                  Text(d.name, style: const TextStyle(fontSize: 13, color: AppTheme.textMain, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${d.score.toStringAsFixed(0)} / 25', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ]),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: (d.score / 25).clamp(0.0, 1.0),
                  backgroundColor: AppTheme.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(d.color),
                  minHeight: 5,
                ),
                const SizedBox(height: 3),
                Text(d.detail, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ]),
            )),
            const SizedBox(height: 4),
            const Text('总评分 = 运动 25 + 习惯 25 + 睡眠 25 + 体重 25，点击各模块继续优化',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('M月d日').format(DateTime.now());
    final overdueTint = AppTheme.isDark
        ? const Color(0xFF3D2424)
        : const Color(0xFFFDECEA);
    return Scaffold(
      appBar: AppBar(
        title: const Text('米工作台'),
        actions: const [
          ThemeToggleIconButton(),
          IconButton(icon: Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(today, style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('今日概览', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            const SizedBox(height: 12),
            // 健康综合评分：点击展开四维明细
            InkWell(
              onTap: _showHealthSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppTheme.sidebarGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Text('健康综合评分', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const Spacer(),
                  Text(_healthScore.toStringAsFixed(0),
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const Text(' / 100', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: Colors.white70, size: 18),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            // —— 生意工作数据 ——
            const _SectionTitle(label: '💼 生意工作数据', badge: '跨境'),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _Card(icon: Icons.check_box, color: AppTheme.primary, title: '待办',
                  value: _todoTotal == 0 ? '暂无' : '今日 $_todoToday 项',
                  sub: _overdue > 0
                      ? '⚠️ 逾期 $_overdue 项'
                      : (_todoBiz > 0
                          ? '生意 $_todoBiz · 完成 $_todoDone/$_todoTotal'
                          : '完成 $_todoDone/$_todoTotal'),
                  tint: _overdue > 0 ? overdueTint : null,
                  onTap: () => widget.onNavigate?.call('todo')),
                _Card(icon: Icons.account_balance_wallet, color: Colors.teal, title: '本月收支',
                  value: '¥${_monthBalance >= 0 ? '' : '-'}${_monthBalance.abs().toStringAsFixed(0)}',
                  sub: '收 ¥${_monthIncome.toStringAsFixed(0)} · 支 ¥${_monthSpend.toStringAsFixed(0)}',
                  onTap: () => widget.onNavigate?.call('bookkeeping')),
              ],
            ),
            const SizedBox(height: 20),
            // —— 个人管理数据 ——
            const _SectionTitle(label: '🌱 个人管理数据', badge: '日常'),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _Card(icon: Icons.savings, color: Colors.green.shade700, title: '存钱',
                  value: _goals.isEmpty ? '未设' : '¥${_savedTotal.toStringAsFixed(0)}',
                  sub: _goals.isEmpty
                      ? '点去定个目标'
                      : '目标 ¥${_savingTarget.toStringAsFixed(0)} · 还差 ¥${(_savingTarget - _savedTotal).clamp(0, double.infinity).toStringAsFixed(0)}',
                  progress: _savingTarget <= 0 ? null : _savingPct,
                  footer: _goals.isEmpty ? null : _savingEta,
                  onTap: () => widget.onNavigate?.call('bookkeeping')),
                _Card(icon: Icons.local_fire_department, color: Colors.orange, title: '运动',
                  value: '🔥$_streak 天',
                  sub: (_weeklyGoal > 0
                          ? '本周 $_weekDays/${_weeklyGoal.toStringAsFixed(0)}'
                          : '本周 $_weekDays 天') +
                      (_weekMinutes > 0 ? ' · $_weekMinutes 分' : '') +
                      (_badgeCount > 0 ? ' · 🏅$_badgeCount' : ''),
                  onTap: () => widget.onNavigate?.call('exercise')),
                _Card(icon: Icons.monitor_weight, color: Colors.purple, title: '体重',
                  value: _weights.isEmpty ? '--' : '${_latestWeight.toStringAsFixed(1)}kg',
                  sub: _weightGoal > 0 ? '距目标 ${(_latestWeight - _weightGoal >= 0 ? '+' : '')}${(_latestWeight - _weightGoal).toStringAsFixed(1)} kg' : (_height > 0 && _weights.isNotEmpty ? _bmiLabel : '点设置目标'),
                  onTap: () => widget.onNavigate?.call('weight')),
                _Card(icon: Icons.repeat, color: AppTheme.accent, title: '习惯',
                  value: '$_habitsToday 项',
                  sub: _habitAchieved ? '🏆 有习惯达标' : '今日完成 ${_todayChecked.length}',
                  onTap: () => widget.onNavigate?.call('habit')),
                _Card(icon: Icons.bedtime, color: Colors.indigo, title: '睡眠',
                  value: _todaySleep == null ? '未记' : '${_todaySleep!.durationHours.toStringAsFixed(1)}h',
                  sub: _todaySleep == null
                      ? '点设备页记录'
                      : (_todaySleep!.durationHours < 6 ? '⚠ 不足6h（脱发/发胖风险）' : '达标'),
                  onTap: () => widget.onNavigate?.call('device')),
              ],
            ),
            const SizedBox(height: 20),
            if (_habits.isNotEmpty) ...[
              const Text('今日习惯', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
              const SizedBox(height: 8),
              ..._habits.where((h) => h.shouldCheckToday()).map((h) {
                final done = _todayChecked.contains(h.id);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: done ? AppTheme.primary : Colors.grey.shade200, child: Icon(done ? Icons.check : Icons.circle_outlined, color: done ? Colors.white : Colors.grey)),
                  title: Text('${h.icon} ${h.name}', style: TextStyle(color: AppTheme.textMain)),
                  trailing: done ? const Text('已完成', style: TextStyle(color: AppTheme.primary, fontSize: 12)) : const Text('去打卡', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  onTap: () async {
                    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                    if (done) await DbService.instance.uncheckHabit(h.id, today);
                    else await DbService.instance.checkHabit(h.id, today);
                    await _load();
                  },
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final String? badge;
  const _SectionTitle({required this.label, this.badge});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
      if (badge != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: AppTheme.subtleBg, borderRadius: BorderRadius.circular(10)),
          child: Text(badge!, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ),
      ],
    ]),
  );
}

class _Card extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String sub;
  final double? progress; // 0~1 进度条
  final String? footer; // 底部附加文字（如预计存满天数）
  final Color? tint; // 整卡底色（逾期警示用浅红）
  final VoidCallback? onTap;
  const _Card({required this.icon, required this.color, required this.title, required this.value, required this.sub, this.progress, this.footer, this.tint, this.onTap});
  @override
  Widget build(BuildContext context) {
    final valueColor = tint != null ? Colors.red : AppTheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tint ?? AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const Spacer(),
            if (onTap != null) const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: valueColor)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 13, color: AppTheme.textMain)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: 4),
            Text(footer!, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ]),
      ),
    );
  }
}
