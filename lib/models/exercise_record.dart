// 运动记录：项目 / 时长 / 强度 / 距离 / 卡路里
class Intensity {
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';

  static const labels = {
    low: '轻松',
    medium: '适中',
    high: '强烈',
  };

  /// 强度系数（用于 MET 修正）
  static const factors = {
    low: 0.8,
    medium: 1.0,
    high: 1.3,
  };

  static String labelOf(String v) => labels[v] ?? '适中';
  static double factorOf(String v) => factors[v] ?? 1.0;
}

/// 常见运动项目的 MET 值（中等强度参考）
const Map<String, double> kExerciseMet = {
  '跑步': 9.0,
  '游泳': 8.0,
  '瑜伽': 3.0,
  '骑行': 7.5,
  '健身': 6.0,
  '跳绳': 11.0,
  '散步': 3.5,
  '篮球': 8.0,
  '羽毛球': 5.5,
  '爬山': 7.0,
  '拉伸': 2.5,
  '快走': 4.5,
};

/// 项目对应图标（emoji）
const Map<String, String> kExerciseIcon = {
  '跑步': '🏃',
  '游泳': '🏊',
  '瑜伽': '🧘',
  '骑行': '🚴',
  '健身': '🏋️',
  '跳绳': '🤸',
  '散步': '🚶',
  '篮球': '🏀',
  '羽毛球': '🏸',
  '爬山': '⛰️',
  '拉伸': '🤾',
  '快走': '🚶',
};

class ExerciseRecord {
  final String id;
  String name; // 跑步 / 游泳 / 瑜伽 ...
  int durationMinutes;
  DateTime performedAt;
  String? note;
  String intensity; // low / medium / high
  double distanceKm; // 0 表示未记录
  int calories; // 0 表示未手填，读取时按 MET 估算

  ExerciseRecord({
    required this.id,
    required this.name,
    required this.durationMinutes,
    DateTime? performedAt,
    this.note,
    this.intensity = Intensity.medium,
    this.distanceKm = 0,
    this.calories = 0,
  }) : performedAt = performedAt ?? DateTime.now();

  String get icon => kExerciseIcon[name] ?? '🏃';
  String get intensityLabel => Intensity.labelOf(intensity);

  /// 卡路里：手填优先，否则用 MET × 体重(kg) × 小时 × 强度系数 估算
  int caloriesWith(double bodyWeightKg) {
    if (calories > 0) return calories;
    final met = kExerciseMet[name] ?? 5.0;
    final w = bodyWeightKg > 0 ? bodyWeightKg : 65.0;
    final hours = durationMinutes / 60.0;
    return (met * w * hours * Intensity.factorOf(intensity)).round();
  }

  ExerciseRecord copyWith({
    String? name,
    int? durationMinutes,
    DateTime? performedAt,
    String? note,
    String? intensity,
    double? distanceKm,
    int? calories,
  }) =>
      ExerciseRecord(
        id: id,
        name: name ?? this.name,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        performedAt: performedAt ?? this.performedAt,
        note: note ?? this.note,
        intensity: intensity ?? this.intensity,
        distanceKm: distanceKm ?? this.distanceKm,
        calories: calories ?? this.calories,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'duration_minutes': durationMinutes,
        'performed_at': performedAt.millisecondsSinceEpoch,
        'note': note,
        'intensity': intensity,
        'distance_km': distanceKm,
        'calories': calories,
      };

  factory ExerciseRecord.fromMap(Map<String, dynamic> m) => ExerciseRecord(
        id: m['id'] as String,
        name: m['name'] as String,
        durationMinutes: m['duration_minutes'] as int,
        performedAt:
            DateTime.fromMillisecondsSinceEpoch(m['performed_at'] as int),
        note: m['note'] as String?,
        intensity: (m['intensity'] as String?) ?? Intensity.medium,
        distanceKm: (m['distance_km'] as num?)?.toDouble() ?? 0.0,
        calories: (m['calories'] as num?)?.toInt() ?? 0,
      );
}
