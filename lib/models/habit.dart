// 习惯打卡
class Habit {
  final String id;
  String name;
  String icon; // emoji
  String repeatDays; // 逗号分隔 1-7（周一..周日），空表示每天
  int targetStreak; // 目标连续天数，0 表示未设目标
  DateTime createdAt;

  Habit({
    required this.id,
    required this.name,
    this.icon = '⭐',
    this.repeatDays = '',
    this.targetStreak = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 需要打卡的星期（1=周一 .. 7=周日）；空列表表示每天
  List<int> get repeatDayList {
    if (repeatDays.trim().isEmpty) return [1, 2, 3, 4, 5, 6, 7];
    return repeatDays
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .where((e) => e != null)
        .cast<int>()
        .toList();
  }

  /// 今天是否需要打卡
  bool shouldCheckToday() {
    final wd = DateTime.now().weekday; // 1..7
    final list = repeatDayList;
    return list.contains(wd);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'repeat_days': repeatDays,
        'target_streak': targetStreak,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Habit.fromMap(Map<String, dynamic> m) => Habit(
        id: m['id'] as String,
        name: m['name'] as String,
        icon: (m['icon'] as String?) ?? '⭐',
        repeatDays: (m['repeat_days'] as String?) ?? '',
        targetStreak: (m['target_streak'] as int?) ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}

// 单次打卡记录
class HabitCheck {
  final String id;
  final String habitId;
  final String date; // yyyy-MM-dd
  final String? note;

  HabitCheck({
    required this.id,
    required this.habitId,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'habit_id': habitId,
        'checked_date': date,
        'note': note,
      };

  factory HabitCheck.fromMap(Map<String, dynamic> m) => HabitCheck(
        id: m['id'] as String,
        habitId: m['habit_id'] as String,
        date: m['checked_date'] as String,
        note: m['note'] as String?,
      );
}
