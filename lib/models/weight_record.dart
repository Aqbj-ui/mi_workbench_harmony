// 体重记录
class WeightRecord {
  final String id;
  double weightKg;
  DateTime measuredAt;
  String? note;
  double? bodyFat; // 体脂率 %（新增，可选）

  WeightRecord({
    required this.id,
    required this.weightKg,
    DateTime? measuredAt,
    this.note,
    this.bodyFat,
  }) : measuredAt = measuredAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'weight_kg': weightKg,
        'measured_at': measuredAt.millisecondsSinceEpoch,
        'note': note,
        'body_fat': bodyFat,
      };

  factory WeightRecord.fromMap(Map<String, dynamic> m) => WeightRecord(
        id: m['id'] as String,
        weightKg: (m['weight_kg'] as num).toDouble(),
        measuredAt: DateTime.fromMillisecondsSinceEpoch(m['measured_at'] as int),
        note: m['note'] as String?,
        bodyFat: m['body_fat'] != null ? (m['body_fat'] as num).toDouble() : null,
      );
}
