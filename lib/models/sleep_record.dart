// 睡眠记录（手动录入 / 手表手环同步）
// 与体重记录解耦：按日期(date_key)唯一，方便体重页顺带录入、首页健康评分直接读取
class SleepRecord {
  final String id;
  final DateTime date; // 记录日期（当地零点）
  final DateTime? bedtime; // 就寝时间
  final DateTime? wakeTime; // 起床时间
  final double durationHours; // 睡眠时长（小时）
  final String source; // 'manual' 手动 | 'healthkit' 手表/手环同步
  final String? note; // 多梦/质量备注

  SleepRecord({
    required this.id,
    required this.date,
    this.bedtime,
    this.wakeTime,
    required this.durationHours,
    this.source = 'manual',
    this.note,
  });

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        'id': id,
        'date_key': dateKey,
        'bedtime': bedtime?.millisecondsSinceEpoch,
        'wake_time': wakeTime?.millisecondsSinceEpoch,
        'duration_hours': durationHours,
        'source': source,
        'note': note,
      };

  factory SleepRecord.fromMap(Map<String, dynamic> m) => SleepRecord(
        id: m['id'] as String,
        date: DateTime.parse(m['date_key'] as String),
        bedtime: m['bedtime'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['bedtime'] as int),
        wakeTime: m['wake_time'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['wake_time'] as int),
        durationHours: (m['duration_hours'] as num).toDouble(),
        source: m['source'] as String? ?? 'manual',
        note: m['note'] as String?,
      );
}
