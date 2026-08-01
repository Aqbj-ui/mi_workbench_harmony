// 提醒设置页：待办到期 / 习惯打卡 / 运动 / 称重 / 每日简报
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});
  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final _s = SettingsService.instance;
  final _n = NotificationService.instance;

  bool _loading = true;
  bool _asked = false;
  bool _granted = false;
  int _pendingCount = 0;

  bool _todo = true;
  int _lead = 30;
  bool _habit = false;
  String _habitTime = '21:00';
  bool _exercise = false;
  String _exerciseTime = '19:00';
  bool _weigh = false;
  String _weighTime = '07:30';
  int _weighWd = 1;
  bool _brief = false;
  String _briefTime = '08:00';

  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final todo = await _s.notifyTodo;
    final lead = await _s.notifyTodoLead;
    final habit = await _s.notifyHabit;
    final habitTime = await _s.notifyHabitTime;
    final exercise = await _s.notifyExercise;
    final exerciseTime = await _s.notifyExerciseTime;
    final weigh = await _s.notifyWeigh;
    final weighTime = await _s.notifyWeighTime;
    final weighWd = await _s.notifyWeighWeekday;
    final brief = await _s.notifyBrief;
    final briefTime = await _s.notifyBriefTime;
    final asked = await _s.notifyAsked;
    final pend = await _n.pending();
    if (!mounted) return;
    setState(() {
      _todo = todo;
      _lead = lead;
      _habit = habit;
      _habitTime = habitTime;
      _exercise = exercise;
      _exerciseTime = exerciseTime;
      _weigh = weigh;
      _weighTime = weighTime;
      _weighWd = weighWd;
      _brief = brief;
      _briefTime = briefTime;
      _asked = asked;
      _granted = _n.granted;
      _pendingCount = pend.length;
      _loading = false;
    });
  }

  Future<void> _refreshPending() async {
    final pend = await _n.pending();
    if (!mounted) return;
    setState(() => _pendingCount = pend.length);
  }

  Future<void> _apply() async {
    await _n.rescheduleAll();
    await _refreshPending();
  }

  Future<void> _askPermission() async {
    final ok = await _n.requestPermission();
    if (!mounted) return;
    setState(() {
      _granted = ok;
      _asked = true;
    });
    if (ok) {
      await _apply();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通知已开启，提醒已排好')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('系统拒绝了通知权限，请到 iPhone「设置 → 米工作台 → 通知」里手动打开'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _pickTime(String cur, Future<void> Function(String) onOk) async {
    final hm = NotificationService.parseHm(cur);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hm.$1, minute: hm.$2),
    );
    if (picked == null) return;
    await onOk(NotificationService.formatHm(picked.hour, picked.minute));
    await _apply();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('提醒')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('提醒'),
        actions: [
          IconButton(
            tooltip: '发送测试通知',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () async {
              await _n.sendTest();
              await _refreshPending();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('3 秒后会收到一条测试通知')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _permissionCard(),
          const SizedBox(height: 12),
          _sectionTitle('任务提醒'),
          _switchCard(
            emoji: '📋',
            title: '待办到期提醒',
            subtitle: '给设了截止时间的待办，提前 $_lead 分钟提醒一次',
            value: _todo,
            onChanged: (v) async {
              setState(() => _todo = v);
              await _s.setNotifyTodo(v);
              await _apply();
            },
            extra: _todo ? _leadPicker() : null,
          ),
          _switchCard(
            emoji: '☀️',
            title: '每日简报',
            subtitle: '每天早上提醒你看一眼「今日聚焦」',
            value: _brief,
            trailingText: _briefTime,
            onTapTrailing: () => _pickTime(_briefTime, (v) async {
              setState(() => _briefTime = v);
              await _s.setNotifyBriefTime(v);
            }),
            onChanged: (v) async {
              setState(() => _brief = v);
              await _s.setNotifyBrief(v);
              await _apply();
            },
          ),
          const SizedBox(height: 12),
          _sectionTitle('健康提醒'),
          _switchCard(
            emoji: '🔥',
            title: '习惯打卡提醒',
            subtitle: '每天固定时间提醒，别断了连续记录',
            value: _habit,
            trailingText: _habitTime,
            onTapTrailing: () => _pickTime(_habitTime, (v) async {
              setState(() => _habitTime = v);
              await _s.setNotifyHabitTime(v);
            }),
            onChanged: (v) async {
              setState(() => _habit = v);
              await _s.setNotifyHabit(v);
              await _apply();
            },
          ),
          _switchCard(
            emoji: '💪',
            title: '运动提醒',
            subtitle: '每天固定时间催你动一动',
            value: _exercise,
            trailingText: _exerciseTime,
            onTapTrailing: () => _pickTime(_exerciseTime, (v) async {
              setState(() => _exerciseTime = v);
              await _s.setNotifyExerciseTime(v);
            }),
            onChanged: (v) async {
              setState(() => _exercise = v);
              await _s.setNotifyExercise(v);
              await _apply();
            },
          ),
          _switchCard(
            emoji: '⚖️',
            title: '称重提醒',
            subtitle: '每周固定一天早上提醒，空腹称更准',
            value: _weigh,
            trailingText: _weighTime,
            onTapTrailing: () => _pickTime(_weighTime, (v) async {
              setState(() => _weighTime = v);
              await _s.setNotifyWeighTime(v);
            }),
            onChanged: (v) async {
              setState(() => _weigh = v);
              await _s.setNotifyWeigh(v);
              await _apply();
            },
            extra: _weigh ? _weekdayPicker() : null,
          ),
          const SizedBox(height: 16),
          _statusCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
      );

  Widget _permissionCard() {
    final ok = _granted;
    final color = ok ? AppTheme.primary : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.notifications_active : Icons.notifications_off,
              color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ok ? '通知已开启' : (_asked ? '通知被关闭了' : '还没开启通知权限'),
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: color, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  ok
                      ? '提醒会准时弹到锁屏和通知中心'
                      : (_asked
                          ? '请到 iPhone「设置 → 米工作台 → 通知」里打开'
                          : '点右边按钮授权，之后提醒才会真的弹出来'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          if (!ok)
            ElevatedButton(
              onPressed: _askPermission,
              style: ElevatedButton.styleFrom(
                  backgroundColor: color, foregroundColor: Colors.white),
              child: const Text('去开启'),
            ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.subtleBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text('已排入系统的提醒：$_pendingCount 条',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(onPressed: _apply, child: const Text('重新排程')),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'iOS 系统对每个 App 最多保留 64 条待触发提醒。待办按「最近到期」优先排，'
            '最多占 50 条，超出的等前面的通知触发后会自动补上。',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await _n.cancelAll();
                await _refreshPending();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已清空全部待触发提醒')),
                );
              },
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('清空全部', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leadPicker() {
    const options = [0, 10, 30, 60, 120, 1440];
    String label(int m) {
      if (m == 0) return '准点';
      if (m < 60) return '$m 分钟';
      if (m == 1440) return '1 天';
      return '${m ~/ 60} 小时';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: options.map((m) {
          final sel = m == _lead;
          return ChoiceChip(
            label: Text('提前${label(m)}', style: const TextStyle(fontSize: 12)),
            selected: sel,
            onSelected: (_) async {
              setState(() => _lead = m);
              await _s.setNotifyTodoLead(m);
              await _apply();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _weekdayPicker() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 6,
        children: List.generate(7, (i) {
          final wd = i + 1;
          final sel = wd == _weighWd;
          return ChoiceChip(
            label: Text('周${_weekLabels[i]}', style: const TextStyle(fontSize: 12)),
            selected: sel,
            onSelected: (_) async {
              setState(() => _weighWd = wd);
              await _s.setNotifyWeighWeekday(wd);
              await _apply();
            },
          );
        }),
      ),
    );
  }

  Widget _switchCard({
    required String emoji,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? trailingText,
    VoidCallback? onTapTrailing,
    Widget? extra,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (trailingText != null && value)
                TextButton(
                  onPressed: onTapTrailing,
                  child: Text(trailingText,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              Switch(
                value: value,
                activeColor: AppTheme.primary,
                onChanged: onChanged,
              ),
            ],
          ),
          if (extra != null) extra,
        ],
      ),
    );
  }
}
