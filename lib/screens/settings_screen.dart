// 设置页：外观（深色模式）/ 目标与预算 / 数据备份 / 关于
import 'package:flutter/material.dart';

import '../main.dart' show appThemeMode, themeModeToString;
import '../theme.dart';
import '../services/backup_service.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _s = SettingsService.instance;
  final _b = BackupService.instance;

  bool _loading = true;
  bool _busy = false;

  double _budget = 0;
  double _weeklyGoal = 0;
  double _weightGoal = 0;
  double _height = 0;

  List<BackupFile> _backups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final budget = await _s.monthlyBudget;
    final weekly = await _s.exerciseWeeklyGoal;
    final wGoal = await _s.weightGoal;
    final h = await _s.heightCm;
    List<BackupFile> list = [];
    try {
      list = await _b.listBackups();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _budget = budget;
      _weeklyGoal = weekly;
      _weightGoal = wGoal;
      _height = h;
      _backups = list;
      _loading = false;
    });
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade600 : AppTheme.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ===================== 外观 =====================

  Future<void> _setTheme(ThemeMode m) async {
    appThemeMode.value = m;
    await _s.setThemeMode(themeModeToString(m));
    setState(() {});
  }

  Widget _appearanceCard() {
    final mode = appThemeMode.value;
    final items = <(ThemeMode, String, IconData, String)>[
      (ThemeMode.system, '跟随系统', Icons.brightness_auto, '手机切深色它就跟着切'),
      (ThemeMode.light, '浅色', Icons.light_mode, '白天看着清爽'),
      (ThemeMode.dark, '深色', Icons.dark_mode, '晚上不刺眼，省电'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: AppTheme.borderColor, indent: 52),
            InkWell(
              onTap: () => _setTheme(items[i].$1),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(items[i].$3,
                        size: 22,
                        color: mode == items[i].$1
                            ? AppTheme.brandOn
                            : AppTheme.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i].$2,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: mode == items[i].$1
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: AppTheme.textMain)),
                          const SizedBox(height: 2),
                          Text(items[i].$4,
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    if (mode == items[i].$1)
                      Icon(Icons.check_circle,
                          size: 20, color: AppTheme.brandOn),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===================== 目标与预算 =====================

  Future<void> _editNumber({
    required String title,
    required String unit,
    required double current,
    required String hint,
    required Future<void> Function(double) onSave,
  }) async {
    final ctrl = TextEditingController(
        text: current > 0 ? _trimNum(current) : '');
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: unit,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0.0),
            child: const Text('清除'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final d = double.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, d ?? current);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (v == null) return;
    await onSave(v);
    await _load();
    _toast('已保存');
  }

  String _trimNum(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  Widget _goalsCard() {
    final rows = <(String, String, String, VoidCallback)>[
      (
        '💰',
        '月度预算',
        _budget > 0 ? '¥${_trimNum(_budget)}' : '未设置',
        () => _editNumber(
              title: '月度预算',
              unit: '元',
              current: _budget,
              hint: '例如 5000',
              onSave: _s.setMonthlyBudget,
            )
      ),
      (
        '💪',
        '运动周目标',
        _weeklyGoal > 0 ? '每周 ${_trimNum(_weeklyGoal)} 天' : '未设置',
        () => _editNumber(
              title: '运动周目标',
              unit: '天/周',
              current: _weeklyGoal,
              hint: '例如 4',
              onSave: _s.setExerciseWeeklyGoal,
            )
      ),
      (
        '⚖️',
        '体重目标',
        _weightGoal > 0 ? '${_trimNum(_weightGoal)} kg' : '未设置',
        () => _editNumber(
              title: '体重目标',
              unit: 'kg',
              current: _weightGoal,
              hint: '例如 70',
              onSave: _s.setWeightGoal,
            )
      ),
      (
        '📏',
        '身高',
        _height > 0 ? '${_trimNum(_height)} cm' : '未设置（BMI 需要）',
        () => _editNumber(
              title: '身高',
              unit: 'cm',
              current: _height,
              hint: '例如 175',
              onSave: _s.setHeightCm,
            )
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: AppTheme.borderColor, indent: 50),
            InkWell(
              onTap: rows[i].$4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Text(rows[i].$1, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(rows[i].$2,
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.textMain)),
                    ),
                    Text(rows[i].$3,
                        style:
                            TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 18, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===================== 数据备份 =====================

  Future<void> _doExport() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final f = await _b.export();
      await _load();
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('备份完成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('大小 ${f.sizeLabel}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 12),
              Text(
                '怎么取出来：打开 iPhone 自带的「文件」App → 我的 iPhone → 米工作台 → backups，'
                '就能看到这个文件，可以发微信、传网盘、拷到电脑。\n\n'
                '换手机恢复：把备份文件放回同一个位置，回到这里点它就能还原。',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('知道了'))
          ],
        ),
      );
    } catch (e) {
      _toast('备份失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doRestore(BackupFile f, bool replace) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(replace ? '完整还原？' : '合并恢复？'),
        content: Text(
          replace
              ? '会先清空当前 App 里的全部数据，再用这个备份的内容覆盖。\n\n'
                  '适合：换了手机、或想回到某个时间点。\n\n'
                  '⚠️ 现在的数据会没掉，建议先点一次「立即备份」再操作。'
              : '只把备份里「当前没有」的记录补进来，现有数据一条都不动。\n\n'
                  '适合：不小心删了东西想找回来。',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: replace
                ? ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600)
                : null,
            child: Text(replace ? '确认覆盖' : '确认合并'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final res = await _b.restore(f.path, replace: replace);
    if (mounted) setState(() => _busy = false);
    if (!res.ok) {
      _toast(res.message, error: true);
      return;
    }
    // 数据变了，提醒也要跟着重排
    try {
      await NotificationService.instance.rescheduleAll();
    } catch (_) {}
    await _load();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复完成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(res.message),
            const SizedBox(height: 8),
            Text('共写入 ${res.total} 条记录',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 8),
            Text('回到各个页面会自动刷新；如果哪页没变，切走再切回来即可。',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('好'))
        ],
      ),
    );
  }

  Future<void> _doDelete(BackupFile f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个备份？'),
        content: Text(f.name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _b.delete(f.path);
      await _load();
      _toast('已删除');
    } catch (e) {
      _toast('删除失败：$e', error: true);
    }
  }

  String _fmtTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  Widget _backupCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
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
                  const Text('☁️', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('把待办、账目、存钱、运动、体重、习惯全部打包成一个文件',
                        style: TextStyle(
                            fontSize: 12.5, color: AppTheme.textMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _doExport,
                  icon: const Icon(Icons.backup, size: 18),
                  label: Text(_busy ? '处理中…' : '立即备份'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_backups.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.subtleBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('还没有备份，点上面的按钮做第一个',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          )
        else
          ..._backups.map((f) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file_outlined,
                        size: 20, color: AppTheme.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textMain)),
                          const SizedBox(height: 2),
                          Text('${_fmtTime(f.modified)} · ${f.sizeLabel}',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          size: 18, color: AppTheme.textMuted),
                      onSelected: (v) {
                        if (v == 'replace') _doRestore(f, true);
                        if (v == 'merge') _doRestore(f, false);
                        if (v == 'delete') _doDelete(f);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'merge', child: Text('合并恢复（只补缺失）')),
                        PopupMenuItem(
                            value: 'replace', child: Text('完整还原（覆盖现有）')),
                        PopupMenuItem(value: 'delete', child: Text('删除备份')),
                      ],
                    ),
                  ],
                ),
              )),
        const SizedBox(height: 6),
        Text(
          '说明：iCloud 自动同步需要付费开发者账号才能开，免费安装用不了。'
          '所以这里用「导出文件」的办法，效果一样可靠，只是要手动点一下。'
          '建议每月做一次，顺手把文件发到微信收藏。',
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.5),
        ),
      ],
    );
  }

  // ===================== 关于 =====================

  Widget _aboutCard() {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppTheme.sidebarGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('米',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('米工作台',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMain)),
                  const SizedBox(height: 2),
                  Text('v2.0 · 待办 / 记账 / 运动 / 体重 / 习惯',
                      style:
                          TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.borderColor),
          const SizedBox(height: 10),
          Text(
            '数据全部存在手机本地，不上传任何服务器。卸载 App 会连数据一起删掉，'
            '所以重要节点记得来这里备份一下。',
            style:
                TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ===================== 页面 =====================

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
        child: Text(t,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('外观'),
                _appearanceCard(),
                const SizedBox(height: 16),
                _sectionTitle('目标与预算'),
                _goalsCard(),
                const SizedBox(height: 16),
                _sectionTitle('数据备份'),
                _backupCard(),
                const SizedBox(height: 16),
                _sectionTitle('关于'),
                _aboutCard(),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
