// 待办事项：支持双账本（个人 / 跨境生意）+ 备注 + 四象限
import 'transaction.dart' show Ledger;

class Todo {
  final String id;
  String title;
  bool done;
  String priority; // urgent / important / normal
  int sortOrder;
  DateTime createdAt;
  DateTime? doneAt;
  DateTime? dueAt; // 截止日期
  String? tags; // 标签，逗号分隔
  String repeat; // none / daily / weekly / monthly
  String ledger; // personal / business（跨境生意）
  String? note; // 备注（细节、链接、SKU 等）

  Todo({
    required this.id,
    required this.title,
    this.done = false,
    this.priority = 'normal',
    this.sortOrder = 0,
    DateTime? createdAt,
    this.doneAt,
    this.dueAt,
    this.tags,
    this.repeat = 'none',
    this.ledger = Ledger.personal,
    this.note,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isBusiness => ledger == Ledger.business;

  /// 是否今天到期（含逾期未做）
  bool get isToday {
    if (dueAt == null) return false;
    final now = DateTime.now();
    final d = dueAt!;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  /// 距离截止还有几天（负数=已逾期，null=无截止）
  int? get daysLeft {
    if (dueAt == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueAt!.year, dueAt!.month, dueAt!.day);
    return due.difference(today).inDays;
  }

  /// 四象限：1=重要且紧急 2=重要不紧急 3=紧急不重要 4=不重要不紧急
  /// 重要 = priority 为 important/urgent；紧急 = 3 天内到期或已逾期
  int get quadrant {
    final important = priority == 'urgent' || priority == 'important';
    final dl = daysLeft;
    final urgent = dl != null && dl <= 3;
    if (important && urgent) return 1;
    if (important && !urgent) return 2;
    if (!important && urgent) return 3;
    return 4;
  }

  /// 标签解析为列表
  List<String> get tagList =>
      (tags ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  /// 是否逾期（未做完且已过截止时间）
  bool get isOverdue {
    if (done || dueAt == null) return false;
    final due = DateTime(dueAt!.year, dueAt!.month, dueAt!.day, 23, 59, 59);
    return due.isBefore(DateTime.now());
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'done': done ? 1 : 0,
        'priority': priority,
        'sort_order': sortOrder,
        'created_at': createdAt.millisecondsSinceEpoch,
        'done_at': doneAt?.millisecondsSinceEpoch,
        'due_at': dueAt?.millisecondsSinceEpoch,
        'tags': tags,
        'repeat': repeat,
        'ledger': ledger,
        'note': note,
      };

  factory Todo.fromMap(Map<String, dynamic> m) => Todo(
        id: m['id'] as String,
        title: m['title'] as String,
        done: (m['done'] as int) == 1,
        priority: m['priority'] as String,
        sortOrder: m['sort_order'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        doneAt: m['done_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['done_at'] as int)
            : null,
        dueAt: m['due_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['due_at'] as int)
            : null,
        tags: m['tags'] as String?,
        repeat: (m['repeat'] as String?) ?? 'none',
        ledger: (m['ledger'] as String?) ?? Ledger.personal,
        note: m['note'] as String?,
      );

  Todo copyWith({
    String? title,
    bool? done,
    String? priority,
    int? sortOrder,
    DateTime? doneAt,
    DateTime? dueAt,
    String? tags,
    String? repeat,
    String? ledger,
    String? note,
    bool clearDue = false,
  }) =>
      Todo(
        id: id,
        title: title ?? this.title,
        done: done ?? this.done,
        priority: priority ?? this.priority,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
        doneAt: doneAt ?? this.doneAt,
        dueAt: clearDue ? null : (dueAt ?? this.dueAt),
        tags: tags ?? this.tags,
        repeat: repeat ?? this.repeat,
        ledger: ledger ?? this.ledger,
        note: note ?? this.note,
      );

  /// 计算下一次重复日期
  DateTime? nextDue() {
    if (repeat == 'none' || dueAt == null) return null;
    switch (repeat) {
      case 'daily':
        return dueAt!.add(const Duration(days: 1));
      case 'weekly':
        return dueAt!.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(dueAt!.year, dueAt!.month + 1, dueAt!.day);
      default:
        return null;
    }
  }
}
