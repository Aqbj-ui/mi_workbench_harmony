// 存钱计划：目标 + 存入流水（解决"零存款"的核心模块）

class SavingGoal {
  final String id;
  String name; // 如：应急备用金 / 换电脑 / 旅游
  String icon; // emoji
  double targetAmount; // 目标金额
  DateTime? deadline; // 期望完成日期（可空）
  DateTime createdAt;
  bool archived; // 已完成/归档

  SavingGoal({
    required this.id,
    required this.name,
    this.icon = '🎯',
    required this.targetAmount,
    this.deadline,
    DateTime? createdAt,
    this.archived = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'target_amount': targetAmount,
        'deadline': deadline?.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'archived': archived ? 1 : 0,
      };

  factory SavingGoal.fromMap(Map<String, dynamic> m) => SavingGoal(
        id: m['id'] as String,
        name: m['name'] as String,
        icon: (m['icon'] as String?) ?? '🎯',
        targetAmount: (m['target_amount'] as num).toDouble(),
        deadline: m['deadline'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['deadline'] as int),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        archived: ((m['archived'] as int?) ?? 0) == 1,
      );

  /// 剩余天数（无截止日返回 null）
  int? get daysLeft {
    if (deadline == null) return null;
    final now = DateTime.now();
    final d = DateTime(deadline!.year, deadline!.month, deadline!.day);
    final t = DateTime(now.year, now.month, now.day);
    return d.difference(t).inDays;
  }
}

/// 存入/取出记录（amount 正=存入，负=取出）
class SavingDeposit {
  final String id;
  String goalId;
  double amount;
  DateTime occurredAt;
  String? note;

  SavingDeposit({
    required this.id,
    required this.goalId,
    required this.amount,
    DateTime? occurredAt,
    this.note,
  }) : occurredAt = occurredAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'goal_id': goalId,
        'amount': amount,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'note': note,
      };

  factory SavingDeposit.fromMap(Map<String, dynamic> m) => SavingDeposit(
        id: m['id'] as String,
        goalId: m['goal_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        occurredAt: DateTime.fromMillisecondsSinceEpoch(m['occurred_at'] as int),
        note: m['note'] as String?,
      );
}
