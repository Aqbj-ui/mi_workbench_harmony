// 本地通知提醒服务
//
// 说明：这里用的是「本地通知」(UNNotificationRequest)，不是 APNs 远程推送。
// 本地通知不需要 Apple 推送证书、也不需要 aps-environment entitlement，
// 所以免费 Apple ID 侧载（AltStore 重签）也能正常用。
//
// iOS 硬限制：系统同一时间最多保留 64 条「待触发」通知，超出的会被丢弃。
// 因此这里做了额度管理：重复类提醒固定占 4 条，剩下的额度留给待办到期提醒，
// 按触发时间由近到远排，只排前 _kTodoQuota 条。
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:intl/intl.dart';

import '../models/todo.dart';
import '../models/habit.dart';
import 'db_service.dart';
import 'settings_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _granted = false;

  /// 是否已拿到系统通知授权（初始化/请求后才准）
  bool get granted => _granted;

  // ---------------- 通知 ID 分段 ----------------
  // 待办：10000 ~ 10049（动态重排，会整段清空重建）
  static const int _kTodoBase = 10000;
  static const int _kTodoQuota = 50;
  // 重复类：固定 ID，改设置时单条覆盖
  static const int _kHabitDaily = 20001;
  static const int _kExerciseDaily = 20002;
  static const int _kWeighWeekly = 20003;
  static const int _kDailyBrief = 20004;
  // 每日汇总（早 9 点）
  static const int _kDailySummary = 20005;
  // 测试通知
  static const int _kTest = 29999;

  NotificationDetails get _details {
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const android = AndroidNotificationDetails(
      'mi_workbench_reminder',
      '米工作台提醒',
      channelDescription: '待办到期、习惯打卡、运动与称重提醒',
      importance: Importance.high,
      priority: Priority.high,
    );
    // 鸿蒙版插件提供 OHOSNotificationDetails；非 ohos 平台该字段被忽略。
    return const NotificationDetails(
      iOS: darwin,
      macOS: darwin,
      android: android,
      ohos: OHOSNotificationDetails(),
    );
  }

  /// App 启动时调用一次
  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      // 老板在国内，直接锁上海时区，省掉一个原生插件依赖
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    } catch (e) {
      debugPrint('timezone init fallback: $e');
    }

    const darwinInit = DarwinInitializationSettings(
      // 不在启动瞬间弹权限框，交给「提醒」页由用户主动开启，体验更好
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // 鸿蒙版插件提供 OHOSInitializationSettings（资源名指向 module.json5 的 string）。
    const ohosInit = OHOSInitializationSettings('@string/app_name');

    try {
      await _plugin.initialize(const InitializationSettings(
        iOS: darwinInit,
        macOS: darwinInit,
        android: androidInit,
        ohos: ohosInit,
      ));
      _ready = true;
    } catch (e) {
      debugPrint('notification init failed: $e');
    }

    // 之前授过权的话，静默刷新一次授权状态。
    // iOS 上重复调用 requestAuthorization 不会再弹系统框，只会返回当前状态。
    // 鸿蒙版插件无 IOSFlutterLocalNotificationsPlugin 实现，跳过该分支。
    if (!Platform.isOhos && await SettingsService.instance.notifyAsked) {
      try {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        if (ios != null) {
          final ok = await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          _granted = ok ?? false;
        } else {
          _granted = true;
        }
      } catch (e) {
        debugPrint('refresh permission failed: $e');
      }
    }
  }

  /// 主动向系统申请通知权限（iOS 只会弹一次系统框）
  Future<bool> requestPermission() async {
    await init();
    // 鸿蒙版插件无 IOSFlutterLocalNotificationsPlugin 实现，直接走系统授权。
    if (Platform.isOhos) {
      _granted = true;
      await SettingsService.instance.setNotifyAsked(true);
      return _granted;
    }
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final ok = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _granted = ok ?? false;
      } else {
        // 非 iOS 平台（本机调试）直接放行
        _granted = true;
      }
    } catch (e) {
      debugPrint('requestPermission failed: $e');
      _granted = false;
    }
    await SettingsService.instance.setNotifyAsked(true);
    return _granted;
  }

  /// 待触发通知数量（提醒页用来展示"已排 N 条"）
  Future<List<PendingNotificationRequest>> pending() async {
    await init();
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('pending failed: $e');
      return [];
    }
  }

  /// 取消单条，吞掉插件未就绪时的异常，避免打断整条重排链
  Future<void> _safeCancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('cancel #$id failed: $e');
    }
  }

  Future<void> cancelAll() async {
    await init();
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('cancelAll failed: $e');
    }
  }

  /// 立即发一条测试通知（3 秒后弹，方便老板确认权限是否真的开了）
  Future<void> sendTest() async {
    await init();
    final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 3));
    try {
      await _plugin.zonedSchedule(
        _kTest,
        '米工作台 · 测试提醒',
        '能看到这条就说明通知已经开好了 👍',
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('sendTest failed: $e');
    }
  }

  // ---------------- 时间计算 ----------------

  /// 解析 'HH:mm'，坏值退回默认
  static (int, int) parseHm(String s, {int defH = 8, int defM = 0}) {
    final parts = s.split(':');
    if (parts.length != 2) return (defH, defM);
    final h = int.tryParse(parts[0]) ?? defH;
    final m = int.tryParse(parts[1]) ?? defM;
    if (h < 0 || h > 23 || m < 0 || m > 59) return (defH, defM);
    return (h, m);
  }

  static String formatHm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    var next = _nextInstanceOfTime(hour, minute);
    // weekday: 1=周一 … 7=周日，与 DateTime.weekday 一致
    int guard = 0;
    while (next.weekday != weekday && guard < 8) {
      next = next.add(const Duration(days: 1));
      guard++;
    }
    return next;
  }

  Future<void> _scheduleRepeating({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required DateTimeComponents match,
  }) async {
    try {
      await _plugin.cancel(id);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: match,
      );
    } catch (e) {
      debugPrint('schedule repeating #$id failed: $e');
    }
  }

  // ---------------- 各类提醒 ----------------

  /// 习惯打卡提醒（每天固定时间）
  Future<void> syncHabitReminder() async {
    await init();
    final s = SettingsService.instance;
    if (!await s.notifyHabit) {
      await _safeCancel(_kHabitDaily);
      return;
    }
    final (h, m) = parseHm(await s.notifyHabitTime, defH: 21, defM: 0);
    await _scheduleRepeating(
      id: _kHabitDaily,
      title: '🔥 该给今天的习惯打卡了',
      body: '别断了连续记录，打开米工作台勾一下',
      when: _nextInstanceOfTime(h, m),
      match: DateTimeComponents.time,
    );
  }

  /// 运动提醒（每天固定时间）
  Future<void> syncExerciseReminder() async {
    await init();
    final s = SettingsService.instance;
    if (!await s.notifyExercise) {
      await _safeCancel(_kExerciseDaily);
      return;
    }
    final (h, m) = parseHm(await s.notifyExerciseTime, defH: 19, defM: 0);
    await _scheduleRepeating(
      id: _kExerciseDaily,
      title: '💪 动一动吧',
      body: '今天还没记录运动，30 分钟也行',
      when: _nextInstanceOfTime(h, m),
      match: DateTimeComponents.time,
    );
  }

  /// 称重提醒（每周固定一天）
  Future<void> syncWeighReminder() async {
    await init();
    final s = SettingsService.instance;
    if (!await s.notifyWeigh) {
      await _safeCancel(_kWeighWeekly);
      return;
    }
    final (h, m) = parseHm(await s.notifyWeighTime, defH: 7, defM: 30);
    final wd = await s.notifyWeighWeekday;
    await _scheduleRepeating(
      id: _kWeighWeekly,
      title: '⚖️ 该称体重了',
      body: '空腹称一次，数据才有对比意义',
      when: _nextInstanceOfWeekday(wd, h, m),
      match: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// 每日简报（早上提醒今天有事要做）
  Future<void> syncBriefReminder() async {
    await init();
    final s = SettingsService.instance;
    if (!await s.notifyBrief) {
      await _safeCancel(_kDailyBrief);
      return;
    }
    final (h, m) = parseHm(await s.notifyBriefTime, defH: 8, defM: 0);
    await _scheduleRepeating(
      id: _kDailyBrief,
      title: '☀️ 早上好，今天的安排',
      body: '打开米工作台看看今日聚焦有几件事',
      when: _nextInstanceOfTime(h, m),
      match: DateTimeComponents.time,
    );
  }

  /// 待办到期提醒：整段清空后按最近到期重排
  /// 返回实际排上的条数
  Future<int> syncTodoReminders() async {
    await init();
    // 先清掉整个待办 ID 段
    for (int i = 0; i < _kTodoQuota; i++) {
      try {
        await _plugin.cancel(_kTodoBase + i);
      } catch (_) {}
    }

    final s = SettingsService.instance;
    if (!await s.notifyTodo) return 0;

    final lead = await s.notifyTodoLead;
    final todos = await DbService.instance.getTodos();
    final now = DateTime.now();

    final items = <_Fire>[];
    for (final t in todos) {
      if (t.done) continue;
      final due = t.dueAt;
      if (due == null) continue;
      final fire = due.subtract(Duration(minutes: lead));
      if (fire.isAfter(now)) items.add(_Fire(fire, t));
    }
    items.sort((a, b) => a.at.compareTo(b.at));

    int n = 0;
    for (final it in items) {
      if (n >= _kTodoQuota) break;
      final t = it.todo;
      final flag = t.ledger == 'business' ? '🌍' : '🏠';
      final due = t.dueAt!;
      final hhmm = formatHm(due.hour, due.minute);
      final leadText = lead <= 0 ? '现在到期' : '$lead 分钟后到期';
      try {
        await _plugin.zonedSchedule(
          _kTodoBase + n,
          '$flag ${t.title}',
          '$leadText（$hhmm）',
          tz.TZDateTime.from(it.at, tz.local),
          _details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'todo:${t.id}',
        );
        n++;
      } catch (e) {
        debugPrint('schedule todo failed: $e');
      }
    }
    return n;
  }

  /// 每日汇总（早 9 点推送今日概览）—— 习惯↔每日汇总联动（v3 阶段 3）
  /// 汇总今日待打卡习惯数与逾期待办数，自动组文案。
  Future<void> syncDailySummary() async {
    await init();
    final s = SettingsService.instance;
    if (!await s.notifyDailySummary) {
      await _safeCancel(_kDailySummary);
      return;
    }
    final (h, m) = parseHm(await s.notifyDailySummaryTime, defH: 9, defM: 0);
    String body;
    try {
      final habits = await DbService.instance.getHabits();
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final checks = await DbService.instance.getChecks(date: todayKey);
      final checked = checks.map((c) => c.habitId).toSet();
      final due = (await DbService.instance.getTodos())
          .where((t) => !t.done && t.isOverdue)
          .length;
      final pendingHabits = habits
          .where((hb) => hb.shouldCheckToday() && !checked.contains(hb.id))
          .length;
      final parts = <String>[];
      if (pendingHabits > 0) parts.add('$pendingHabits 个习惯待打卡');
      if (due > 0) parts.add('$due 条待办已逾期');
      body = parts.isEmpty ? '今天一切都安排妥当，继续保持 💪' : parts.join('，');
    } catch (e) {
      debugPrint('daily summary build failed: $e');
      body = '打开米工作台看看今日安排';
    }
    await _scheduleRepeating(
      id: _kDailySummary,
      title: '📊 每日汇总',
      body: body,
      when: _nextInstanceOfTime(h, m),
      match: DateTimeComponents.time,
    );
  }

  /// 全量重排（启动时 + 改设置后调用）
  Future<void> rescheduleAll() async {
    await init();
    await syncHabitReminder();
    await syncExerciseReminder();
    await syncWeighReminder();
    await syncBriefReminder();
    await syncDailySummary();
    await syncTodoReminders();
  }
}

class _Fire {
  final DateTime at;
  final Todo todo;
  _Fire(this.at, this.todo);
}
