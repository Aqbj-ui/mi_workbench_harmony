// 模块联动引擎（v3 阶段 3）
//
// 把分散在各模块的"动作"串起来，做成可复用的纯逻辑：
//   · 记账↔存钱：生意回款入账后，建议把这笔钱划入存钱目标
//   · 减脂↔存钱：本周减重达到阈值，解锁"减脂奖励金"划拨到存钱目标
//   · 运动↔体重：本周运动达标，给体重模块一个正向标注
//   · 习惯↔每日汇总：每日汇总通知的文案来自习惯/待办状态
//
// 这里不碰 UI、不碰数据库，只算"该不该做、做多少、文案是什么"，
// 各页面/通知服务调用后自行决定怎么落地，避免跨模块直接耦合。
import '../models/transaction.dart';

class InterconnectService {
  static final InterconnectService instance = InterconnectService._();
  InterconnectService._();

  /// 记账↔存钱：生意回款入账后，建议划入存钱目标的金额。
  /// 默认全额建议，老板在弹窗里可改成部分。
  double proposeSavingTransfer(Transaction tx) {
    if (tx.ledger != Ledger.business || !tx.isIncome) return 0;
    return tx.amount;
  }

  /// 减脂↔存钱：本周减重（kg）达阈值时，解锁奖励金。
  /// 奖励 = 减重 kg × 单价（默认每 kg 100 元），封顶 [maxReward]。
  double fatLossReward(double weekLossKg, {double perKg = 100, double maxReward = 500}) {
    if (weekLossKg <= 0) return 0;
    final r = weekLossKg * perKg;
    return r > maxReward ? maxReward : r;
  }

  /// 运动↔体重：本周运动达标（天数 >= 周目标）返回正向标注文案。
  String? exerciseAnnotation(int weekDays, double weeklyGoal) {
    if (weeklyGoal <= 0) return null;
    if (weekDays >= weeklyGoal) return '本周运动达标，热量缺口助力减重 💪';
    return null;
  }

  /// 习惯↔每日汇总：根据今日状态生成汇总文案（供通知使用）。
  String dailySummaryLine({required int pendingHabits, required int overdueTodos}) {
    final parts = <String>[];
    if (pendingHabits > 0) parts.add('$pendingHabits 个习惯待打卡');
    if (overdueTodos > 0) parts.add('$overdueTodos 条待办已逾期');
    return parts.isEmpty ? '今天一切都安排妥当，继续保持 💪' : parts.join('，');
  }
}
