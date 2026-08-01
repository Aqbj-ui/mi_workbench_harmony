// 记账流水：支持双账本（个人 / 生意）+ 收支类型（收入 / 支出）

/// 账本类型
class Ledger {
  static const String personal = 'personal';
  static const String business = 'business';

  static const Map<String, String> labels = {
    personal: '个人',
    business: '生意',
  };

  static String label(String v) => labels[v] ?? '个人';
}

/// 收支类型
class TxType {
  static const String expense = 'expense';
  static const String income = 'income';

  static const Map<String, String> labels = {
    expense: '支出',
    income: '收入',
  };

  static String label(String v) => labels[v] ?? '支出';
}

class Transaction {
  final String id;
  String rawText; // 原始输入："今天买了个榴莲120块"
  double amount; // 恒为正数，方向由 type 决定
  String category; // 水果 / 餐饮 / 广告推广 / 店铺收入 …
  DateTime occurredAt;
  String? note;
  String ledger; // personal | business
  String type; // expense | income

  Transaction({
    required this.id,
    required this.rawText,
    required this.amount,
    required this.category,
    DateTime? occurredAt,
    this.note,
    this.ledger = Ledger.personal,
    this.type = TxType.expense,
  }) : occurredAt = occurredAt ?? DateTime.now();

  bool get isIncome => type == TxType.income;

  /// 带符号金额：收入为正，支出为负（用于算结余）
  double get signedAmount => isIncome ? amount : -amount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'raw_text': rawText,
        'amount': amount,
        'category': category,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'note': note,
        'ledger': ledger,
        'type': type,
      };

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
        id: m['id'] as String,
        rawText: m['raw_text'] as String,
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String,
        occurredAt: DateTime.fromMillisecondsSinceEpoch(m['occurred_at'] as int),
        note: m['note'] as String?,
        // 兼容 v3 之前的老数据（无这两列时按个人支出处理）
        ledger: (m['ledger'] as String?) ?? Ledger.personal,
        type: (m['type'] as String?) ?? TxType.expense,
      );
}
