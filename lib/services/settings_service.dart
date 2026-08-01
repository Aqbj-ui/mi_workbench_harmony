// 全局设置（预算、目标、身高）—— 用 shared_preferences 本地存储
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<double> _getDouble(String key, [double def = 0]) async {
    final p = await prefs;
    return p.getDouble(key) ?? def;
  }

  Future<void> _setDouble(String key, double v) async {
    final p = await prefs;
    await p.setDouble(key, v);
  }

  Future<bool> _getBool(String key, [bool def = false]) async {
    final p = await prefs;
    return p.getBool(key) ?? def;
  }

  Future<void> _setBool(String key, bool v) async {
    final p = await prefs;
    await p.setBool(key, v);
  }

  Future<int> _getInt(String key, [int def = 0]) async {
    final p = await prefs;
    return p.getInt(key) ?? def;
  }

  Future<void> _setInt(String key, int v) async {
    final p = await prefs;
    await p.setInt(key, v);
  }

  Future<String> _getString(String key, [String def = '']) async {
    final p = await prefs;
    return p.getString(key) ?? def;
  }

  Future<void> _setString(String key, String v) async {
    final p = await prefs;
    await p.setString(key, v);
  }

  // 月度预算（记账）
  Future<double> get monthlyBudget => _getDouble('monthly_budget', 0);
  Future<void> setMonthlyBudget(double v) => _setDouble('monthly_budget', v);

  // 运动周目标（每周打卡天数）
  Future<double> get exerciseWeeklyGoal => _getDouble('exercise_weekly_goal', 0);
  Future<void> setExerciseWeeklyGoal(double v) => _setDouble('exercise_weekly_goal', v);

  // 体重目标（kg）
  Future<double> get weightGoal => _getDouble('weight_goal', 0);
  Future<void> setWeightGoal(double v) => _setDouble('weight_goal', v);

  // 身高（cm，用于 BMI）
  Future<double> get heightCm => _getDouble('height_cm', 0);
  Future<void> setHeightCm(double v) => _setDouble('height_cm', v);

  // ======================= 本地通知提醒 =======================
  // 时间统一用 'HH:mm' 字符串存，避免时区/序列化坑

  /// 是否已经向系统申请过通知权限（用于首启引导）
  Future<bool> get notifyAsked => _getBool('notify_asked', false);
  Future<void> setNotifyAsked(bool v) => _setBool('notify_asked', v);

  /// 待办到期提醒
  Future<bool> get notifyTodo => _getBool('notify_todo', true);
  Future<void> setNotifyTodo(bool v) => _setBool('notify_todo', v);

  /// 待办提前多少分钟提醒（默认提前 30 分钟）
  Future<int> get notifyTodoLead => _getInt('notify_todo_lead', 30);
  Future<void> setNotifyTodoLead(int v) => _setInt('notify_todo_lead', v);

  /// 习惯打卡提醒
  Future<bool> get notifyHabit => _getBool('notify_habit', false);
  Future<void> setNotifyHabit(bool v) => _setBool('notify_habit', v);
  Future<String> get notifyHabitTime => _getString('notify_habit_time', '21:00');
  Future<void> setNotifyHabitTime(String v) => _setString('notify_habit_time', v);

  /// 运动提醒
  Future<bool> get notifyExercise => _getBool('notify_exercise', false);
  Future<void> setNotifyExercise(bool v) => _setBool('notify_exercise', v);
  Future<String> get notifyExerciseTime =>
      _getString('notify_exercise_time', '19:00');
  Future<void> setNotifyExerciseTime(String v) =>
      _setString('notify_exercise_time', v);

  /// 称重提醒（每周固定一天）
  Future<bool> get notifyWeigh => _getBool('notify_weigh', false);
  Future<void> setNotifyWeigh(bool v) => _setBool('notify_weigh', v);
  Future<String> get notifyWeighTime => _getString('notify_weigh_time', '07:30');
  Future<void> setNotifyWeighTime(String v) => _setString('notify_weigh_time', v);

  /// 称重提醒的星期几（1=周一 … 7=周日）
  Future<int> get notifyWeighWeekday => _getInt('notify_weigh_weekday', 1);
  Future<void> setNotifyWeighWeekday(int v) => _setInt('notify_weigh_weekday', v);

  /// 每日简报（早上提示今天有几件事）
  Future<bool> get notifyBrief => _getBool('notify_brief', false);
  Future<void> setNotifyBrief(bool v) => _setBool('notify_brief', v);
  Future<String> get notifyBriefTime => _getString('notify_brief_time', '08:00');
  Future<void> setNotifyBriefTime(String v) =>
      _setString('notify_brief_time', v);

  /// 每日汇总（早 9 点推送昨日/今日概览）—— 习惯↔每日汇总联动（v3 阶段 3）
  Future<bool> get notifyDailySummary =>
      _getBool('notify_daily_summary', false);
  Future<void> setNotifyDailySummary(bool v) =>
      _setBool('notify_daily_summary', v);
  Future<String> get notifyDailySummaryTime =>
      _getString('notify_daily_summary_time', '09:00');
  Future<void> setNotifyDailySummaryTime(String v) =>
      _setString('notify_daily_summary_time', v);

  // ======================= 外观 =======================

  /// 主题模式：system / light / dark
  Future<String> get themeMode => _getString('theme_mode', 'system');
  Future<void> setThemeMode(String v) => _setString('theme_mode', v);
}
