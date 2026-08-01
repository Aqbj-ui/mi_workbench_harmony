// 睡眠数据源
// - 手动录入：当前可用（就寝/起床时间 -> 时长），存本地 SQLite。
// - 手表/手环自动同步：iPhone 上需经 Apple HealthKit 聚合，而 HealthKit 能力要求
//   付费 Apple 开发者账号($99)才能在描述文件启用；当前免费 AltStore 侧载无法授权。
//   connectWearable() 已留接口，切到付费签名后接入 health 包（SLEEP_ASLEEP 等）即可。
import '../models/sleep_record.dart';
import '../services/db_service.dart';

class SleepService {
  // 手动保存睡眠（就寝/起床时间 -> 自动算时长，支持跨午夜）
  Future<void> saveManual({
    required DateTime date,
    DateTime? bedtime,
    DateTime? wakeTime,
    String? note,
  }) async {
    double hours = 0;
    if (bedtime != null && wakeTime != null) {
      var diff = wakeTime.difference(bedtime).inMinutes;
      if (diff < 0) diff += 24 * 60; // 跨午夜
      hours = diff / 60.0;
    }
    final rec = SleepRecord(
      id: '${date.year}-${date.month.toString().padLeft(2, '0')}'
          '-${date.day.toString().padLeft(2, '0')}',
      date: date,
      bedtime: bedtime,
      wakeTime: wakeTime,
      durationHours: hours,
      source: 'manual',
      note: note,
    );
    await DbService.instance.saveSleep(rec);
  }

  // 连接手表/手环（自动同步睡眠）。
  // 当前免费侧载不支持 -> 返回 false，UI 提示走手动录入。
  Future<bool> connectWearable() async {
    // TODO(付费账号): 接入 health 包 -> Health().configure()
    //   -> requestAuthorization([SLEEP_ASLEEP, SLEEP_IN_BED, SLEEP_DEEP])
    //   -> getHealthDataFromTypes(当天0点, now, types) 累加分钟/60
    return false;
  }
}
