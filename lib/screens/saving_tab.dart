// 存钱计划：目标 + 存入流水 + 进度 + 达标建议（记账页的一个 Tab）
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/saving_goal.dart';
import '../services/db_service.dart';
import '../theme.dart';

class SavingTab extends StatefulWidget {
  final VoidCallback? onChanged;
  const SavingTab({super.key, this.onChanged});
  @override
  State<SavingTab> createState() => SavingTabState();
}

class SavingTabState extends State<SavingTab> with AutomaticKeepAliveClientMixin {
  List<SavingGoal> _goals = [];
  Map<String, double> _saved = {};
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final goals = await DbService.instance.getSavingGoals();
    final saved = await DbService.instance.getSavedAmounts();
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _saved = saved;
      _loading = false;
    });
    widget.onChanged?.call();
  }

  double _savedOf(SavingGoal g) => _saved[g.id] ?? 0;

  double get _totalSaved =>
      _goals.fold(0.0, (a, g) => a + _savedOf(g));
  double get _totalTarget =>
      _goals.fold(0.0, (a, g) => a + g.targetAmount);

  // ---------- 新建 / 编辑目标 ----------
  Future<void> addGoal({SavingGoal? edit}) async {
    final nameCtrl = TextEditingController(text: edit?.name ?? '');
    final amountCtrl =
        TextEditingController(text: edit == null ? '' : edit.targetAmount.toStringAsFixed(0));
    String icon = edit?.icon ?? '🎯';
    DateTime? deadline = edit?.deadline;
    const icons = ['🎯', '🛟', '💻', '✈️', '🏠', '🚗', '📚', '💍', '🎁', '🏦'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(edit == null ? '新建存钱目标' : '编辑目标'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: '目标名称', hintText: '如：应急备用金 / 换电脑'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '目标金额', prefixText: '¥ '),
                ),
                const SizedBox(height: 12),
                const Text('图标', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: icons
                      .map((e) => GestureDetector(
                            onTap: () => setLocal(() => icon = e),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: icon == e
                                    ? AppTheme.primary.withOpacity(0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: icon == e ? AppTheme.primary : Colors.grey.shade300),
                              ),
                              child: Text(e, style: const TextStyle(fontSize: 18)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('截止日期', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: deadline ?? now.add(const Duration(days: 90)),
                          firstDate: now,
                          lastDate: DateTime(now.year + 10),
                        );
                        if (picked != null) setLocal(() => deadline = picked);
                      },
                      child: Text(deadline == null
                          ? '不设置'
                          : DateFormat('yyyy-MM-dd').format(deadline!)),
                    ),
                    if (deadline != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setLocal(() => deadline = null),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final target = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (name.isEmpty || target <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写目标名称和金额')));
      return;
    }
    if (edit == null) {
      await DbService.instance.insertSavingGoal(SavingGoal(
        id: const Uuid().v4(),
        name: name,
        icon: icon,
        targetAmount: target,
        deadline: deadline,
      ));
    } else {
      edit.name = name;
      edit.icon = icon;
      edit.targetAmount = target;
      edit.deadline = deadline;
      await DbService.instance.updateSavingGoal(edit);
    }
    await load();
  }

  // ---------- 存入 / 取出 ----------
  Future<void> _deposit(SavingGoal g, {bool withdraw = false}) async {
    final ctrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(withdraw ? '从「${g.name}」取出' : '存入「${g.name}」'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '金额', prefixText: '¥ '),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: '备注（可选）'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;
    final v = double.tryParse(ctrl.text.trim()) ?? 0;
    if (v <= 0) return;
    await DbService.instance.insertDeposit(SavingDeposit(
      id: const Uuid().v4(),
      goalId: g.id,
      amount: withdraw ? -v : v,
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    ));
    await load();
    if (!mounted) return;
    final saved = _savedOf(g);
    if (!withdraw && saved >= g.targetAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🎉 恭喜！「${g.name}」已达成目标 ¥${g.targetAmount.toStringAsFixed(0)}')),
      );
    }
  }

  Future<void> _confirmDelete(SavingGoal g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除目标'),
        content: Text('确定删除「${g.name}」？该目标下的存入记录也会一并删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DbService.instance.deleteSavingGoal(g.id);
      await load();
    }
  }

  Future<void> _showHistory(SavingGoal g) async {
    final list = await DbService.instance.getDeposits(goalId: g.id);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: list.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Text('还没有存入记录', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('${g.icon} ${g.name} · 存取记录',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  ...list.map((s) => ListTile(
                        dense: true,
                        leading: Icon(
                          s.amount >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                          color: s.amount >= 0 ? AppTheme.primary : Colors.orange,
                          size: 18,
                        ),
                        title: Text('${s.amount >= 0 ? '+' : ''}¥${s.amount.toStringAsFixed(2)}'),
                        subtitle: Text(
                          '${DateFormat('MM-dd HH:mm').format(s.occurredAt)}${s.note == null ? '' : ' · ${s.note}'}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () async {
                            await DbService.instance.deleteDeposit(s.id);
                            if (ctx.mounted) Navigator.pop(ctx);
                            await load();
                          },
                        ),
                      )),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏦', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              const Text('还没有存钱计划',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('先定一个小目标：比如 3 个月存 5000 元应急金',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => addGoal(),
                icon: const Icon(Icons.add),
                label: const Text('新建存钱目标'),
              ),
            ],
          ),
        ),
      );
    }

    final totalPct = _totalTarget <= 0 ? 0.0 : (_totalSaved / _totalTarget).clamp(0.0, 1.0);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 总览
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppTheme.sidebarGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('累计已存', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('¥${_totalSaved.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('/ ¥${_totalTarget.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalPct,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text('总进度 ${(totalPct * 100).toStringAsFixed(1)}% · 共 ${_goals.length} 个目标',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 16),
          ..._goals.map(_goalCard),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => addGoal(),
            icon: const Icon(Icons.add),
            label: const Text('新建存钱目标'),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(SavingGoal g) {
    final saved = _savedOf(g);
    final pct = g.targetAmount <= 0 ? 0.0 : (saved / g.targetAmount).clamp(0.0, 1.0);
    final remain = (g.targetAmount - saved).clamp(0.0, double.infinity).toDouble();
    final done = saved >= g.targetAmount;
    final days = g.daysLeft;

    String hint;
    Color hintColor = Colors.grey;
    if (done) {
      hint = '🎉 目标已达成！';
      hintColor = AppTheme.primary;
    } else if (days == null) {
      hint = '还差 ¥${remain.toStringAsFixed(0)}';
    } else if (days <= 0) {
      hint = '⚠️ 已过期，还差 ¥${remain.toStringAsFixed(0)}';
      hintColor = Colors.red;
    } else {
      final perDay = remain / days;
      final perMonth = perDay * 30;
      hint = '剩 $days 天 · 每天存 ¥${perDay.toStringAsFixed(0)}（约每月 ¥${perMonth.toStringAsFixed(0)}）';
      hintColor = perMonth > 5000 ? Colors.orange : Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: done ? AppTheme.primary : Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(g.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(g.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 20, color: Colors.grey),
            onSelected: (v) {
              if (v == 'edit') addGoal(edit: g);
              if (v == 'history') _showHistory(g);
              if (v == 'withdraw') _deposit(g, withdraw: true);
              if (v == 'delete') _confirmDelete(g);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'history', child: Text('存取记录')),
              PopupMenuItem(value: 'withdraw', child: Text('取出')),
              PopupMenuItem(value: 'edit', child: Text('编辑目标')),
              PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
            ],
          ),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('¥${saved.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: done ? AppTheme.primary : AppTheme.textMain)),
          const SizedBox(width: 6),
          Text('/ ¥${g.targetAmount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const Spacer(),
          Text('${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: done ? AppTheme.primary : Colors.grey)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: done ? AppTheme.primary : AppTheme.accent,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(hint, style: TextStyle(fontSize: 12, color: hintColor))),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () => _deposit(g),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14)),
              child: const Text('存入', style: TextStyle(fontSize: 13)),
            ),
          ),
        ]),
      ]),
    );
  }
}
