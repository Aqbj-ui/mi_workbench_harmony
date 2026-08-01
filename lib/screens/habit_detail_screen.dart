// 习惯详情：补卡（任意历史日期）/ 备注 / 复盘统计
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/habit.dart';
import '../services/db_service.dart';
import '../theme.dart';

String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

class HabitDetailScreen extends StatefulWidget {
  final Habit habit;
  const HabitDetailScreen({super.key, required this.habit});
  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  List<HabitCheck> _checks = [];
  Set<String> _checkedSet = {};
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    final list = await DbService.instance.getChecks(habitId: widget.habit.id);
    setState(() {
      _checks = list;
      _checkedSet = list.map((c) => c.date).toSet();
    });
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

  int _streak() {
    final dates = _checkedSet.toSet();
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

  int _bestStreak() {
    final set = _checks.map((c) => DateTime.parse(c.date)).toList();
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

  double _completionRate() {
    final h = widget.habit;
    final start = DateTime(h.createdAt.year, h.createdAt.month, h.createdAt.day);
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final should = _shouldDaysInRange(start, end, h);
    if (should == 0) return 0.0;
    final sk = _dateKey(start);
    final ek = _dateKey(end);
    final done = _checks.where((c) => c.date.compareTo(sk) >= 0 && c.date.compareTo(ek) <= 0).length;
    return (done / should).clamp(0.0, 1.0);
  }

  Future<String?> _askNote(DateTime day) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('打卡 ${_dateKey(day)}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '备注（可留空）'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('打卡')),
        ],
      ),
    );
    return res;
  }

  Future<void> _onDaySelected(DateTime day) async {
    final key = _dateKey(day);
    if (_checkedSet.contains(key)) {
      await DbService.instance.uncheckHabit(widget.habit.id, key);
    } else {
      final note = await _askNote(day);
      if (note == null) return;
      await DbService.instance.checkHabit(widget.habit.id, key, note.isEmpty ? null : note);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.habit;
    final streak = _streak();
    final best = _bestStreak();
    final rate = (_completionRate() * 100).toStringAsFixed(0);
    final reached = h.targetStreak > 0 && streak >= h.targetStreak;
    return Scaffold(
      appBar: AppBar(title: Text('${h.icon} ${h.name}')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (h.targetStreak > 0)
            Card(
              color: reached ? AppTheme.primary.withOpacity(0.12) : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(reached ? Icons.emoji_events : Icons.flag,
                      color: reached ? AppTheme.primary : Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      reached
                          ? '🏆 已达成目标：连续 $streak 天（目标 ${h.targetStreak} 天）'
                          : '目标：连续 ${h.targetStreak} 天 · 当前 $streak 天',
                      style: TextStyle(
                          color: reached ? AppTheme.primary : AppTheme.textMain,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                _Stat(label: '连续', value: '$streak 天', color: AppTheme.primary),
                _Stat(label: '最佳', value: '$best 天', color: AppTheme.accent),
                _Stat(label: '完成率', value: '$rate%', color: Colors.indigo),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2035, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (d) => _checkedSet.contains(_dateKey(d)),
              onDaySelected: (sel, foc) {
                _focusedDay = foc;
                _onDaySelected(sel);
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.3), shape: BoxShape.circle),
                selectedDecoration:
                    BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                outsideDaysVisible: false,
              ),
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
            ),
          ),
          const SizedBox(height: 8),
          const Text('点日历上的日期即可补卡 / 取消；打卡时可写备注。',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          if (_checks.any((c) => c.note != null && c.note!.isNotEmpty))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('打卡备注', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._checks
                      .where((c) => c.note != null && c.note!.isNotEmpty)
                      .map((c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${c.date}：', style: const TextStyle(color: Colors.grey)),
                              Expanded(child: Text(c.note!)),
                            ]),
                          )),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      );
}
