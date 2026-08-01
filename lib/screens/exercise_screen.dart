// 运动：打卡日历 + 周月统计复盘 + 勋章激励
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/exercise_record.dart';
import '../data/exercise_badges.dart';
import '../services/db_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});
  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  List<ExerciseRecord> _all = [];
  Map<DateTime, List<ExerciseRecord>> _byDay = {};
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  List<ExerciseRecord> _dayList = [];
  double _weeklyGoal = 0;
  double _bodyWeight = 65;
  ExerciseStats _stats = const ExerciseStats();
  String _range = 'week'; // week / month

  static const _presets = [
    '跑步', '快走', '散步', '骑行', '游泳', '健身', '跳绳', '瑜伽', '拉伸', '爬山', '篮球', '羽毛球'
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _selected = DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await DbService.instance.getExercises();
    final goal = await SettingsService.instance.exerciseWeeklyGoal;
    final weights = await DbService.instance.getWeights();
    final bw = weights.isEmpty ? 65.0 : weights.last.weightKg;

    final map = <DateTime, List<ExerciseRecord>>{};
    for (final e in list) {
      final d =
          DateTime(e.performedAt.year, e.performedAt.month, e.performedAt.day);
      map.putIfAbsent(d, () => []).add(e);
    }
    if (!mounted) return;
    setState(() {
      _all = list;
      _byDay = map;
      _weeklyGoal = goal;
      _bodyWeight = bw;
      _stats =
          ExerciseStats.from(list, bodyWeightKg: bw, weeklyGoal: goal);
      final sel = _selected;
      _dayList = sel == null
          ? []
          : (map[DateTime(sel.year, sel.month, sel.day)] ?? []);
    });
    // 首次加载建立勋章基线，之后新解锁才弹提示
    if (!_badgeBaselineReady) {
      _knownBadgeIds = unlockedBadges(_stats).map((b) => b.id).toList();
      _badgeBaselineReady = true;
    }
  }

  // ---- 派生 ----
  int _weekDays() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final s = DateTime(start.year, start.month, start.day);
    int cnt = 0;
    for (int i = 0; i < 7; i++) {
      if (_byDay.containsKey(s.add(Duration(days: i)))) cnt++;
    }
    return cnt;
  }

  DateTime get _rangeStart {
    final now = DateTime.now();
    if (_range == 'week') {
      final s = now.subtract(Duration(days: now.weekday - 1));
      return DateTime(s.year, s.month, s.day);
    }
    return DateTime(now.year, now.month, 1);
  }

  List<ExerciseRecord> get _rangeRecords {
    final start = _rangeStart;
    return _all.where((e) => !e.performedAt.isBefore(start)).toList();
  }

  Future<void> _setGoal() async {
    final ctrl = TextEditingController(
        text: _weeklyGoal > 0 ? _weeklyGoal.toStringAsFixed(0) : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('每周运动目标'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(suffixText: '天/周', hintText: '如 4'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) {
      final v = double.tryParse(ctrl.text) ?? 0;
      await SettingsService.instance.setExerciseWeeklyGoal(v);
      await _load();
    }
  }

  Future<void> _edit({ExerciseRecord? rec}) async {
    String name = rec?.name ?? _presets.first;
    int minutes = rec?.durationMinutes ?? 30;
    String intensity = rec?.intensity ?? Intensity.medium;
    final distCtrl = TextEditingController(
        text: (rec != null && rec.distanceKm > 0)
            ? rec.distanceKm.toStringAsFixed(1)
            : '');
    final noteCtrl = TextEditingController(text: rec?.note ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        final met = kExerciseMet[name] ?? 5.0;
        final estKcal = (met *
                (_bodyWeight > 0 ? _bodyWeight : 65) *
                (minutes / 60.0) *
                Intensity.factorOf(intensity))
            .round();
        return AlertDialog(
          title: Text(rec == null ? '记录运动' : '编辑运动'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _presets.map((p) {
                    final on = p == name;
                    return ChoiceChip(
                      label: Text('${kExerciseIcon[p] ?? '🏃'} $p',
                          style: const TextStyle(fontSize: 12)),
                      selected: on,
                      onSelected: (_) => setS(() => name = p),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('时长', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: minutes.toDouble(),
                      min: 5,
                      max: 180,
                      divisions: 35,
                      label: '$minutes 分钟',
                      onChanged: (v) => setS(() => minutes = v.round()),
                    ),
                  ),
                  Text('$minutes 分',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                Wrap(
                  spacing: 6,
                  children: [15, 30, 45, 60, 90].map((m) {
                    return ActionChip(
                      label: Text('$m', style: const TextStyle(fontSize: 12)),
                      onPressed: () => setS(() => minutes = m),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('强度', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  children: [Intensity.low, Intensity.medium, Intensity.high]
                      .map((lv) {
                    final on = lv == intensity;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(Intensity.labelOf(lv),
                            style: const TextStyle(fontSize: 12)),
                        selected: on,
                        onSelected: (_) => setS(() => intensity = lv),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: distCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: '距离（可选）', suffixText: 'km', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                      labelText: '备注（可选）', isDense: true),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.local_fire_department,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 6),
                    Text('预计消耗 $estKcal 千卡',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('保存')),
          ],
        );
      }),
    );

    if (saved != true) return;
    final dist = double.tryParse(distCtrl.text.trim()) ?? 0.0;
    final note = noteCtrl.text.trim();
    if (rec == null) {
      final base = _selected ?? DateTime.now();
      final now = DateTime.now();
      final when = DateTime(
          base.year, base.month, base.day, now.hour, now.minute);
      await DbService.instance.insertExercise(ExerciseRecord(
        id: const Uuid().v4(),
        name: name,
        durationMinutes: minutes,
        performedAt: when,
        intensity: intensity,
        distanceKm: dist,
        note: note.isEmpty ? null : note,
      ));
    } else {
      await DbService.instance.updateExercise(rec.copyWith(
        name: name,
        durationMinutes: minutes,
        intensity: intensity,
        distanceKm: dist,
        note: note.isEmpty ? null : note,
      ));
    }
    await _load();
    if (mounted) _checkNewBadge();
  }

  // 保存后若刚好解锁新勋章，弹个提示
  List<String> _knownBadgeIds = [];
  bool _badgeBaselineReady = false;
  void _checkNewBadge() {
    final now = unlockedBadges(_stats).map((b) => b.id).toList();
    if (!_badgeBaselineReady) {
      _knownBadgeIds = now;
      _badgeBaselineReady = true;
      return;
    }
    final fresh = now.where((id) => !_knownBadgeIds.contains(id)).toList();
    _knownBadgeIds = now;
    if (fresh.isEmpty) return;
    final b = kExerciseBadges.firstWhere((x) => x.id == fresh.first);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppTheme.primaryDark,
      duration: const Duration(seconds: 4),
      content: Text('${b.emoji} 解锁新勋章：${b.name}！${b.desc}'),
    ));
  }

  Future<void> _delete(ExerciseRecord e) async {
    await DbService.instance.deleteExercise(e.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('运动'),
        actions: [IconButton(onPressed: () => _edit(), icon: const Icon(Icons.add))],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '打卡'),
            Tab(text: '统计'),
            Tab(text: '勋章'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_buildCheckin(), _buildStats(), _buildBadges()],
      ),
    );
  }

  // ================= Tab1 打卡 =================
  Widget _buildCheckin() {
    final weekDays = _weekDays();
    final goalPct =
        _weeklyGoal > 0 ? (weekDays / _weeklyGoal).clamp(0.0, 1.0) : 0.0;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
                child: _MiniStat(
                    icon: Icons.local_fire_department,
                    color: Colors.orange,
                    value: '${_stats.currentStreak}',
                    label: '连续打卡(天)')),
            const SizedBox(width: 12),
            Expanded(
                child: _MiniStat(
                    icon: Icons.flag,
                    color: AppTheme.primary,
                    value: _weeklyGoal > 0
                        ? '$weekDays/${_weeklyGoal.toStringAsFixed(0)}'
                        : '未设',
                    label: '本周目标',
                    onTap: _setGoal)),
          ]),
        ),
        if (_weeklyGoal > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(
                value: goalPct,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primary),
          ),
        const SizedBox(height: 8),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: _focused,
            selectedDayPredicate: (d) =>
                _selected != null && isSameDay(d, _selected),
            onDaySelected: (sel, foc) => setState(() {
              _selected = sel;
              _focused = foc;
              _dayList = _byDay[DateTime(sel.year, sel.month, sel.day)] ?? [];
            }),
            eventLoader: (d) => _byDay[DateTime(d.year, d.month, d.day)] ?? [],
            calendarStyle: const CalendarStyle(
              markerDecoration:
                  BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
              todayDecoration:
                  BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(
                  color: AppTheme.primaryDark, shape: BoxShape.circle),
            ),
            headerStyle: const HeaderStyle(
                formatButtonVisible: false, titleCentered: true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Text(
                _selected == null
                    ? ''
                    : DateFormat('yyyy-MM-dd').format(_selected!),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
                _dayList.isEmpty
                    ? '未运动'
                    : '${_dayList.length} 项 · ${_dayList.fold<int>(0, (a, e) => a + e.durationMinutes)} 分钟',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
        if (_dayList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: Text('这天还没运动，点右上 + 记录',
                    style: TextStyle(color: Colors.grey))),
          )
        else
          ..._dayList.map((e) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary.withOpacity(0.12),
                  child: Text(e.icon, style: const TextStyle(fontSize: 18)),
                ),
                title: Row(children: [
                  Text(e.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  _IntensityTag(level: e.intensity),
                ]),
                subtitle: Text([
                  '${e.durationMinutes} 分钟',
                  '${e.caloriesWith(_bodyWeight)} 千卡',
                  if (e.distanceKm > 0) '${e.distanceKm.toStringAsFixed(1)} km',
                  DateFormat('HH:mm').format(e.performedAt),
                  if ((e.note ?? '').isNotEmpty) e.note!,
                ].join(' · ')),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _edit(rec: e);
                    if (v == 'del') _delete(e);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'del', child: Text('删除')),
                  ],
                ),
              )),
      ],
    );
  }

  // ================= Tab2 统计 =================
  Widget _buildStats() {
    final rs = _rangeRecords;
    final count = rs.length;
    final minutes = rs.fold<int>(0, (a, e) => a + e.durationMinutes);
    final kcal =
        rs.fold<int>(0, (a, e) => a + e.caloriesWith(_bodyWeight));
    final dist = rs.fold<double>(0.0, (a, e) => a + e.distanceKm);
    final days = rs
        .map((e) => DateTime(
            e.performedAt.year, e.performedAt.month, e.performedAt.day))
        .toSet()
        .length;

    // 项目分布
    final byType = <String, int>{};
    for (final e in rs) {
      byType[e.name] = (byType[e.name] ?? 0) + e.durationMinutes;
    }
    final typeList = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxType = typeList.isEmpty ? 1 : typeList.first.value;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(children: [
          _RangeChip(
              label: '本周',
              on: _range == 'week',
              onTap: () => setState(() => _range = 'week')),
          const SizedBox(width: 8),
          _RangeChip(
              label: '本月',
              on: _range == 'month',
              onTap: () => setState(() => _range = 'month')),
          const Spacer(),
          Text('活跃 $days 天',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BigStat(value: '$count', label: '次数'),
              _BigStat(value: '$minutes', label: '分钟'),
              _BigStat(value: '$kcal', label: '千卡'),
              if (dist > 0)
                _BigStat(value: dist.toStringAsFixed(1), label: '公里'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('项目分布（按时长）',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (typeList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
                child: Text('这个周期还没有运动记录',
                    style: TextStyle(color: Colors.grey))),
          )
        else
          ...typeList.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(
                      width: 74,
                      child: Text(
                          '${kExerciseIcon[e.key] ?? '🏃'} ${e.key}',
                          style: const TextStyle(fontSize: 12))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: e.value / maxType,
                        minHeight: 14,
                        backgroundColor: Colors.grey.shade200,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  SizedBox(
                      width: 54,
                      child: Text('  ${e.value} 分',
                          style: const TextStyle(fontSize: 12))),
                ]),
              )),
        const SizedBox(height: 20),
        const Text('近 8 周时长趋势', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(height: 140, child: _WeekTrend(records: _all)),
        const SizedBox(height: 20),
        _SummaryCard(stats: _stats),
      ],
    );
  }

  // ================= Tab3 勋章 =================
  Widget _buildBadges() {
    final unlocked = unlockedBadges(_stats);
    final next = nextBadge(_stats);
    final groups = [
      BadgeGroup.persist,
      BadgeGroup.volume,
      BadgeGroup.challenge,
      BadgeGroup.fun
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.amber.shade600, Colors.orange.shade800]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Text('🏅', style: TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${unlocked.length} / ${kExerciseBadges.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
              const Text('已解锁勋章',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
            const Spacer(),
            if (next != null)
              Flexible(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('下一枚',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11)),
                      Text('${next.emoji} ${next.name}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      Text('${next.progress(_stats)}/${next.target}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        ...groups.expand((g) {
          final list = kExerciseBadges.where((b) => b.group == g).toList();
          return [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(g,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.82,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: list.map((b) => _BadgeTile(badge: b, stats: _stats)).toList(),
            ),
          ];
        }),
      ],
    );
  }
}

// ================= 组件 =================
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback? onTap;
  const _MiniStat(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor)),
        child: Row(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary)),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          if (onTap != null) const Spacer(),
          if (onTap != null)
            const Icon(Icons.edit, size: 16, color: Colors.grey),
        ]),
      ),
    );
  }
}

class _IntensityTag extends StatelessWidget {
  final String level;
  const _IntensityTag({required this.level});
  @override
  Widget build(BuildContext context) {
    Color c;
    if (level == Intensity.high) {
      c = Colors.red;
    } else if (level == Intensity.low) {
      c = Colors.blueGrey;
    } else {
      c = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
          color: c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4)),
      child: Text(Intensity.labelOf(level),
          style: TextStyle(fontSize: 10, color: c)),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _RangeChip(
      {required this.label, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: on ? AppTheme.primary : AppTheme.subtleBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: on ? Colors.white : AppTheme.textMain,
                fontWeight: on ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  const _BigStat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }
}

/// 近 8 周时长柱状趋势（自绘，不依赖图表库）
class _WeekTrend extends StatelessWidget {
  final List<ExerciseRecord> records;
  const _WeekTrend({required this.records});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final buckets = <int>[];
    final labels = <String>[];
    for (int i = 7; i >= 0; i--) {
      final start = thisMonday.subtract(Duration(days: 7 * i));
      final end = start.add(const Duration(days: 7));
      int m = 0;
      for (final e in records) {
        if (!e.performedAt.isBefore(start) && e.performedAt.isBefore(end)) {
          m += e.durationMinutes;
        }
      }
      buckets.add(m);
      labels.add(DateFormat('M/d').format(start));
    }
    final maxV = buckets.fold<int>(0, (a, b) => b > a ? b : a);
    if (maxV == 0) {
      return const Center(
          child: Text('还没有足够数据', style: TextStyle(color: Colors.grey)));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(buckets.length, (i) {
        final v = buckets[i];
        final h = maxV == 0 ? 0.0 : (v / maxV) * 96.0;
        final isCurrent = i == buckets.length - 1;
        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(v > 0 ? '$v' : '',
                  style: const TextStyle(fontSize: 9, color: Colors.grey)),
              const SizedBox(height: 2),
              Container(
                height: (h < 3.0 && v > 0) ? 3.0 : h,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppTheme.primary
                      : AppTheme.primary.withOpacity(0.45),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[i],
                  style: const TextStyle(fontSize: 8, color: Colors.grey)),
            ],
          ),
        );
      }),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ExerciseStats stats;
  const _SummaryCard({required this.stats});
  @override
  Widget build(BuildContext context) {
    final rows = [
      ('累计次数', '${stats.totalCount} 次'),
      ('累计时长', '${stats.totalMinutes} 分钟（${(stats.totalMinutes / 60).toStringAsFixed(1)} 小时）'),
      ('累计消耗', '${stats.totalCalories} 千卡'),
      if (stats.totalDistanceKm > 0)
        ('累计距离', '${stats.totalDistanceKm.toStringAsFixed(1)} 公里'),
      ('活跃天数', '${stats.activeDays} 天'),
      ('最佳连续', '${stats.bestStreak} 天'),
      ('单次最长', '${stats.longestSessionMin} 分钟'),
      ('项目种类', '${stats.distinctTypes} 种'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.subtleBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('生涯总览',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Text(r.$1,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 13)),
                  const Spacer(),
                  Text(r.$2,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              )),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final ExerciseBadge badge;
  final ExerciseStats stats;
  const _BadgeTile({required this.badge, required this.stats});

  @override
  Widget build(BuildContext context) {
    final got = badge.unlocked(stats);
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Row(children: [
              Text(badge.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Expanded(child: Text(badge.name)),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(badge.desc),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: badge.ratio(stats),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  color: got ? Colors.amber.shade700 : AppTheme.primary,
                ),
                const SizedBox(height: 6),
                Text(
                    got
                        ? '已解锁 🎉'
                        : '进度 ${badge.progress(stats)} / ${badge.target}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('知道了')),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: got ? Colors.amber.withOpacity(0.10) : AppTheme.subtleBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: got ? Colors.amber.shade400 : Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: got ? 1.0 : 0.3,
              child: Text(badge.emoji, style: const TextStyle(fontSize: 30)),
            ),
            const SizedBox(height: 4),
            Text(badge.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: got ? AppTheme.textMain : Colors.grey)),
            const SizedBox(height: 4),
            if (!got)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: badge.ratio(stats),
                    minHeight: 4,
                    backgroundColor: Colors.grey.shade300,
                    color: AppTheme.primary,
                  ),
                ),
              )
            else
              const Text('已解锁',
                  style: TextStyle(fontSize: 9, color: Colors.orange)),
          ],
        ),
      ),
    );
  }
}
