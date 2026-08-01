// 习惯打卡：今日勾选 + 连续天数 + 目标 + 复盘统计 + 补卡
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/habit.dart';
import '../services/db_service.dart';
import '../theme.dart';
import 'habit_detail_screen.dart';

String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});
  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  List<Habit> _habits = [];
  List<HabitCheck> _checks = [];
  Set<String> _todayChecked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final habits = await DbService.instance.getHabits();
    final checks = await DbService.instance.getChecks();
    final today = _dateKey(DateTime.now());
    setState(() {
      _habits = habits;
      _checks = checks;
      _todayChecked = checks.where((c) => c.date == today).map((c) => c.habitId).toSet();
    });
  }

  Map<DateTime, List<HabitCheck>> get _byDay {
    final map = <DateTime, List<HabitCheck>>{};
    for (final c in _checks) {
      final d = DateTime.parse(c.date);
      map.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(c);
    }
    return map;
  }

  int _streakFor(String habitId) {
    final dates = _checks.where((c) => c.habitId == habitId).map((c) => c.date).toSet();
    final today = DateTime.now();
    final tk = _dateKey(today);
    final yk = _dateKey(today.subtract(const Duration(days: 1)));
    if (!dates.contains(tk) && !dates.contains(yk)) return 0;
    int s = 0;
    var d = today;
    while (dates.contains(_dateKey(d))) {
      s++;
      d = d.subtract(const Duration(days: 1));
    }
    return s;
  }

  int _shouldDaysInRange(DateTime start, DateTime end, Habit h) {
    int n = 0;
    var d = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(last)) {
      if (h.repeatDayList.contains(d.weekday)) n++;
      d = d.add(const Duration(days: 1));
    }
    return n;
  }

  double _completionRate(Habit h) {
    final start = DateTime(h.createdAt.year, h.createdAt.month, h.createdAt.day);
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final should = _shouldDaysInRange(start, end, h);
    if (should == 0) return 0.0;
    final sk = _dateKey(start);
    final ek = _dateKey(end);
    final done = _checks
        .where((c) => c.habitId == h.id && c.date.compareTo(sk) >= 0 && c.date.compareTo(ek) <= 0)
        .length;
    return (done / should).clamp(0.0, 1.0);
  }

  int _bestStreak(String habitId) {
    final set = _checks
        .where((c) => c.habitId == habitId)
        .map((c) => DateTime.parse(c.date))
        .toList();
    if (set.isEmpty) return 0;
    set.sort();
    int best = 1;
    int cur = 1;
    for (int i = 1; i < set.length; i++) {
      if (set[i].difference(set[i - 1]).inDays == 1) {
        cur++;
        if (cur > best) best = cur;
      } else {
        cur = 1;
      }
    }
    return best;
  }

  ({double rate, int should, int done}) _weekly() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final mk = _dateKey(monday);
    final sk = _dateKey(sunday);
    int should = 0;
    for (final h in _habits) should += _shouldDaysInRange(monday, sunday, h);
    final done = _checks.where((c) => c.date.compareTo(mk) >= 0 && c.date.compareTo(sk) <= 0).length;
    final rate = should > 0 ? (done / should).clamp(0.0, 1.0) : 0.0;
    return (rate: rate, should: should, done: done);
  }

  Future<void> _toggle(Habit h) async {
    final today = _dateKey(DateTime.now());
    if (_todayChecked.contains(h.id)) {
      await DbService.instance.uncheckHabit(h.id, today);
    } else {
      await DbService.instance.checkHabit(h.id, today);
    }
    await _load();
  }

  String _subtitle(Habit h) {
    final s = _streakFor(h.id);
    final rate = (_completionRate(h) * 100).toStringAsFixed(0);
    final best = _bestStreak(h.id);
    String t = '🔥连续 $s 天 · 完成率 $rate% · 最佳 $best 天';
    if (h.targetStreak > 0) {
      final reached = s >= h.targetStreak;
      t += ' · 目标 $s/${h.targetStreak}${reached ? ' 🏆' : ''}';
    }
    return t;
  }

  Future<void> _add() async {
    final result = await showDialog<dynamic>(
        context: context, builder: (_) => const _HabitDialog());
    if (result is _HabitInput) {
      final h = Habit(
        id: const Uuid().v4(),
        name: result.name,
        icon: result.icon,
        repeatDays: result.repeatDays,
        targetStreak: result.targetStreak,
      );
      await DbService.instance.insertHabit(h);
      await _load();
    }
  }

  Future<void> _edit(Habit h) async {
    final result = await showDialog<dynamic>(
        context: context, builder: (_) => _HabitDialog(habit: h));
    if (result is _DeleteMarker) {
      await DbService.instance.deleteHabit(h.id);
      await _load();
      return;
    }
    if (result is _HabitInput) {
      h.name = result.name;
      h.icon = result.icon;
      h.repeatDays = result.repeatDays;
      h.targetStreak = result.targetStreak;
      await DbService.instance.updateHabit(h);
      await _load();
    }
  }

  Future<void> _openDetail(Habit h) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => HabitDetailScreen(habit: h)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final wk = _weekly();
    return Scaffold(
      appBar: AppBar(
          title: const Text('习惯打卡'),
          actions: [IconButton(onPressed: _add, icon: const Icon(Icons.add))]),
      body: Column(children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('本周概览', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('完成率 ${(wk.rate * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: wk.rate,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text('应打卡 ${wk.should} 次', style: const TextStyle(color: Colors.grey)),
                const Spacer(),
                Text('已完成 ${wk.done} 次', style: const TextStyle(color: AppTheme.primary)),
              ]),
            ]),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: DateTime.now(),
            selectedDayPredicate: (_) => false,
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (ctx, day, _) {
                final list = _byDay[DateTime(day.year, day.month, day.day)] ?? [];
                return Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: list.isNotEmpty ? AppTheme.primary.withOpacity(0.15) : null,
                      shape: BoxShape.circle),
                  child: Center(
                      child: Text('${day.day}',
                          style: TextStyle(
                              color: list.isNotEmpty ? AppTheme.primary : AppTheme.textMain))),
                );
              },
            ),
            calendarStyle: const CalendarStyle(outsideDaysVisible: false),
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Text('今日待打卡 ${_habits.where((h) => h.shouldCheckToday()).length} 项',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('已完成 ${_todayChecked.length}', style: const TextStyle(color: AppTheme.primary)),
            const SizedBox(width: 12),
            const Text('点卡片看复盘/补卡', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
        Expanded(
          child: _habits.isEmpty
              ? const Center(child: Text('还没有习惯，点右上 + 添加一个', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _habits.length,
                  itemBuilder: (_, i) {
                    final h = _habits[i];
                    final done = _todayChecked.contains(h.id);
                    final reached = h.targetStreak > 0 && _streakFor(h.id) >= h.targetStreak;
                    return ListTile(
                      leading: GestureDetector(
                        onTap: () => _toggle(h),
                        child: CircleAvatar(
                          backgroundColor: done ? AppTheme.primary : Colors.grey.shade200,
                          child: Icon(done ? Icons.check : Icons.circle_outlined,
                              color: done ? Colors.white : Colors.grey),
                        ),
                      ),
                      title: Text('${h.icon}  ${h.name}${reached ? '  🏆' : ''}'),
                      subtitle: Text(_subtitle(h)),
                      trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _edit(h)),
                      onTap: () => _openDetail(h),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _HabitInput {
  final String name;
  final String icon;
  final String repeatDays;
  final int targetStreak;
  _HabitInput(
      {required this.name,
      required this.icon,
      required this.repeatDays,
      this.targetStreak = 0});
}

class _DeleteMarker {
  const _DeleteMarker();
}

class _HabitDialog extends StatefulWidget {
  final Habit? habit;
  const _HabitDialog({this.habit});
  @override
  State<_HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<_HabitDialog> {
  final _ctrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  String _icon = '⭐';
  final Set<int> _days = {1, 2, 3, 4, 5, 6, 7};
  final _labels = ['一', '二', '三', '四', '五', '六', '日'];
  final _emojis = ['⭐', '🏃', '📚', '💧', '🧘', '🛌', '🥗', '✍️', '🎯', '💊', '🌅', '🚭'];

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    if (h != null) {
      _ctrl.text = h.name;
      _icon = h.icon;
      _days.clear();
      _days.addAll(h.repeatDayList);
      _targetCtrl.text = h.targetStreak > 0 ? h.targetStreak.toString() : '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.habit != null;
    return AlertDialog(
      title: Text(isEdit ? '编辑习惯' : '新增习惯'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
                controller: _ctrl,
                autofocus: !isEdit,
                decoration: const InputDecoration(hintText: '如：早起 / 读书 / 喝水')),
            const SizedBox(height: 12),
            const Text('图标', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: _emojis.map((e) {
                final sel = e == _icon;
                return GestureDetector(
                  onTap: () => setState(() => _icon = e),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: sel ? AppTheme.primary.withOpacity(0.2) : null,
                        border: Border.all(
                            color: sel ? AppTheme.primary : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(e, style: const TextStyle(fontSize: 18)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text('每周打卡日', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final wd = i + 1;
                final sel = _days.contains(wd);
                return FilterChip(
                  label: Text(_labels[i]),
                  selected: sel,
                  selectedColor: AppTheme.accent,
                  onSelected: (v) => setState(() => v ? _days.add(wd) : _days.remove(wd)),
                );
              }),
            ),
            const SizedBox(height: 12),
            const Text('目标连续天数（可选）', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: _targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '如 21，留空表示不设目标', suffixText: '天'),
            ),
          ],
        ),
      ),
      actions: [
        if (isEdit)
          TextButton(
            onPressed: () => Navigator.pop(context, const _DeleteMarker()),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            if (_ctrl.text.trim().isEmpty) return;
            final days = _days.toList()..sort();
            final t = int.tryParse(_targetCtrl.text.trim()) ?? 0;
            Navigator.pop(
              context,
              _HabitInput(
                name: _ctrl.text.trim(),
                icon: _icon,
                repeatDays: days.join(','),
                targetStreak: t < 0 ? 0 : t,
              ),
            );
          },
          child: Text(isEdit ? '保存' : '确定'),
        ),
      ],
    );
  }
}
