// 待办（跨境版）：今日聚焦 / 全部清单 / 四象限 + 双账本 + 流程模板 + 备注
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../models/transaction.dart' show Ledger;
import '../data/todo_templates.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});
  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Todo> _todos = [];
  String? _activeTag; // 标签筛选
  String _ledgerFilter = 'all'; // all / personal / business

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await DbService.instance.getTodos();
    if (!mounted) return;
    setState(() => _todos = list);
    // 待办有增删改（含勾选完成、改截止日）就重排到期提醒。
    // 不 await，避免刷新列表时卡一下。
    unawaited(NotificationService.instance.syncTodoReminders());
  }

  // ---------- 过滤 ----------
  List<Todo> get _scoped {
    return _todos.where((t) {
      if (_ledgerFilter != 'all' && t.ledger != _ledgerFilter) return false;
      if (_activeTag != null && !t.tagList.contains(_activeTag)) return false;
      return true;
    }).toList();
  }

  List<String> get _allTags {
    final set = <String>{};
    for (final t in _todos) {
      if (_ledgerFilter != 'all' && t.ledger != _ledgerFilter) continue;
      set.addAll(t.tagList);
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  /// 今日聚焦：逾期 + 今天到期 + 无截止但重要/紧急
  List<Todo> get _todayFocus {
    final list = _scoped.where((t) {
      if (t.done) return false;
      if (t.isOverdue) return true;
      if (t.isToday) return true;
      if (t.dueAt == null && (t.priority == 'urgent' || t.priority == 'important')) return true;
      return false;
    }).toList();
    list.sort((a, b) {
      final rank = {'urgent': 0, 'important': 1, 'normal': 2};
      final byOverdue = (b.isOverdue ? 1 : 0) - (a.isOverdue ? 1 : 0);
      if (byOverdue != 0) return byOverdue;
      return (rank[a.priority] ?? 2).compareTo(rank[b.priority] ?? 2);
    });
    return list;
  }

  List<Todo> _quadrant(int q) =>
      _scoped.where((t) => !t.done && t.quadrant == q).toList();

  // ---------- 操作 ----------
  Future<void> _add({Todo? edit}) async {
    final result = await showDialog<_TodoInput>(
      context: context,
      builder: (_) => _AddTodoDialog(initial: edit),
    );
    if (result == null) return;
    if (edit != null) {
      final updated = edit.copyWith(
        title: result.title,
        priority: result.priority,
        tags: result.tags,
        repeat: result.repeat,
        dueAt: result.dueAt,
        ledger: result.ledger,
        note: result.note,
        clearDue: result.dueAt == null,
      );
      await DbService.instance.updateTodo(updated);
    } else {
      final t = Todo(
        id: const Uuid().v4(),
        title: result.title,
        priority: result.priority,
        tags: result.tags,
        repeat: result.repeat,
        dueAt: result.dueAt,
        ledger: result.ledger,
        note: result.note,
        sortOrder: _todos.length,
      );
      await DbService.instance.insertTodo(t);
    }
    await _load();
  }

  Future<void> _toggle(Todo t) async {
    final wasDone = t.done;
    final updated = t.copyWith(done: !t.done, doneAt: !t.done ? DateTime.now() : null);
    await DbService.instance.updateTodo(updated);
    // 重复任务：完成后自动排下一次
    if (!wasDone && t.repeat != 'none' && t.nextDue() != null) {
      final next = Todo(
        id: const Uuid().v4(),
        title: t.title,
        priority: t.priority,
        tags: t.tags,
        repeat: t.repeat,
        dueAt: t.nextDue(),
        ledger: t.ledger,
        note: t.note,
        sortOrder: 999,
      );
      await DbService.instance.insertTodo(next);
    }
    await _load();
  }

  Future<void> _delete(Todo t) async {
    await DbService.instance.deleteTodo(t.id);
    await _load();
  }

  Future<void> _changePriority(Todo t) async {
    final next = {'normal': 'important', 'important': 'urgent', 'urgent': 'normal'}[t.priority]!;
    await DbService.instance.updateTodo(t.copyWith(priority: next));
    await _load();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _todos.removeAt(oldIndex);
      _todos.insert(newIndex, item);
    });
    for (var i = 0; i < _todos.length; i++) {
      _todos[i] = _todos[i].copyWith(sortOrder: i);
    }
    await DbService.instance.reorderTodos(_todos);
  }

  // ---------- 模板 ----------
  Future<void> _openTemplates() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('流程模板', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('挑一个流程，一键铺成带截止日的清单', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: kTemplatePacks.length,
                  itemBuilder: (_, i) {
                    final p = kTemplatePacks[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: ListTile(
                        leading: Text(p.icon, style: const TextStyle(fontSize: 26)),
                        title: Row(
                          children: [
                            Flexible(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: p.ledger == Ledger.business ? AppTheme.primaryLight : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(Ledger.label(p.ledger),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: p.ledger == Ledger.business ? AppTheme.primaryDark : Colors.grey.shade700)),
                            ),
                          ],
                        ),
                        subtitle: Text('${p.desc} · ${p.count} 项', style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _previewPack(p);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _previewPack(TemplatePack p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${p.icon} ${p.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('将添加 ${p.count} 项待办，截止日期按流程自动错开：',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 10),
                ...p.items.map((it) {
                  final d = DateTime.now().add(Duration(days: it.offsetDays));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6, height: 6,
                          margin: const EdgeInsets.only(top: 6, right: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.priorityColors[it.priority] ?? Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(child: Text(it.title, style: const TextStyle(fontSize: 13))),
                        const SizedBox(width: 6),
                        Text(DateFormat('MM-dd').format(d),
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('全部添加')),
        ],
      ),
    );
    if (ok != true) return;
    await _applyPack(p);
  }

  Future<void> _applyPack(TemplatePack p) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final base = _todos.length;
    final list = <Todo>[];
    for (var i = 0; i < p.items.length; i++) {
      final it = p.items[i];
      list.add(Todo(
        id: const Uuid().v4(),
        title: it.title,
        priority: it.priority,
        tags: it.tags.isEmpty ? null : it.tags,
        dueAt: today.add(Duration(days: it.offsetDays)),
        ledger: p.ledger,
        note: it.note,
        sortOrder: base + i,
      ));
    }
    await DbService.instance.insertTodos(list);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加 ${p.count} 项「${p.name}」待办'), backgroundColor: AppTheme.primary),
    );
  }

  // ---------- 详情 ----------
  void _showDetail(Todo t) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _pill(Ledger.label(t.ledger), t.isBusiness ? AppTheme.primaryDark : Colors.grey.shade700),
              _pill({'urgent': '紧急', 'important': '重要', 'normal': '普通'}[t.priority] ?? '普通',
                  AppTheme.priorityColors[t.priority] ?? Colors.grey),
              if (t.dueAt != null)
                _pill('截止 ${DateFormat('MM-dd').format(t.dueAt!)}', t.isOverdue ? Colors.red : Colors.grey.shade700),
              ...t.tagList.map((tg) => _pill('#$tg', AppTheme.primaryDark)),
            ]),
            if ((t.note ?? '').isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('备注', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(t.note!, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _add(edit: t); },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('编辑'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _toggle(t); },
                  icon: Icon(t.done ? Icons.undo : Icons.check, size: 18),
                  label: Text(t.done ? '标为未完成' : '标记完成'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 11, color: color)),
      );

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final scoped = _scoped;
    final done = scoped.where((t) => t.done).length;
    final total = scoped.length;
    final rate = total == 0 ? 0 : (done / total * 100).round();
    final overdue = scoped.where((t) => t.isOverdue).length;
    final todayCount = _todayFocus.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办'),
        actions: [
          IconButton(
            tooltip: '流程模板',
            onPressed: _openTemplates,
            icon: const Icon(Icons.auto_awesome_motion),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: '今日聚焦${todayCount > 0 ? ' $todayCount' : ''}'),
            const Tab(text: '全部清单'),
            const Tab(text: '四象限'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 账本切换
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('全部')),
                ButtonSegment(value: Ledger.personal, label: Text('个人')),
                ButtonSegment(value: Ledger.business, label: Text('生意')),
              ],
              selected: {_ledgerFilter},
              onSelectionChanged: (s) => setState(() {
                _ledgerFilter = s.first;
                _activeTag = null;
              }),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 10),
            // 统计条
            Row(children: [
              Expanded(child: _MiniStat(label: '今日待办', value: '$todayCount', color: AppTheme.primary)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: '逾期', value: '$overdue', color: overdue > 0 ? Colors.red : Colors.grey)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: '完成率', value: '$rate%', color: AppTheme.primaryDark)),
            ]),
            const SizedBox(height: 10),
            // 标签筛选
            if (_allTags.isNotEmpty)
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _TagChip(label: '全部', selected: _activeTag == null, onTap: () => setState(() => _activeTag = null)),
                    ..._allTags.map((tg) => _TagChip(
                          label: '#$tg',
                          selected: _activeTag == tg,
                          onTap: () => setState(() => _activeTag = _activeTag == tg ? null : tg),
                        )),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildFocus(),
                  _buildAll(scoped),
                  _buildMatrix(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocus() {
    final list = _todayFocus;
    if (list.isEmpty) {
      return const _Empty(text: '今天没有紧要的事 🎉\n点右上角模板可以一键铺流程');
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: list.length,
      itemBuilder: (_, i) => _todoTile(list[i]),
    );
  }

  Widget _buildAll(List<Todo> scoped) {
    if (scoped.isEmpty) {
      return const _Empty(text: '还没有待办\n点右下角 + 添加，或用右上角流程模板');
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: scoped.length,
      onReorder: (o, n) {
        final oldIdx = _todos.indexOf(scoped[o]);
        final newIdx = _todos.indexOf(scoped[n]);
        if (oldIdx < 0 || newIdx < 0) return;
        _reorder(oldIdx, newIdx);
      },
      itemBuilder: (_, i) => _todoTile(scoped[i], dragIndex: i),
    );
  }

  Widget _buildMatrix() {
    const titles = {1: '重要 且 紧急', 2: '重要 不紧急', 3: '紧急 不重要', 4: '不重要 不紧急'};
    const hints = {1: '马上做', 2: '排计划', 3: '能授权就授权', 4: '有空再说'};
    const colors = {1: Color(0xFFE53935), 2: Color(0xFF2E7D32), 3: Color(0xFFF57C00), 4: Color(0xFF9E9E9E)};
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [1, 2, 3, 4].map((q) {
        final items = _quadrant(q);
        final c = colors[q]!;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(children: [
                  Text(titles[q]!, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 13)),
                  const SizedBox(width: 8),
                  Text(hints[q]!, style: TextStyle(fontSize: 11, color: c.withOpacity(0.8))),
                  const Spacer(),
                  Text('${items.length}', style: TextStyle(fontWeight: FontWeight.bold, color: c)),
                ]),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('暂无', style: TextStyle(color: Colors.grey, fontSize: 12)),
                )
              else
                ...items.map((t) => ListTile(
                      dense: true,
                      leading: GestureDetector(
                        onTap: () => _toggle(t),
                        child: const Icon(Icons.radio_button_unchecked, size: 20),
                      ),
                      title: Text(t.title, style: const TextStyle(fontSize: 13)),
                      subtitle: t.dueAt == null
                          ? null
                          : Text(
                              t.isOverdue ? '逾期 ${DateFormat('MM-dd').format(t.dueAt!)}' : '截止 ${DateFormat('MM-dd').format(t.dueAt!)}',
                              style: TextStyle(fontSize: 11, color: t.isOverdue ? Colors.red : Colors.grey),
                            ),
                      trailing: t.isBusiness
                          ? const Icon(Icons.storefront, size: 16, color: AppTheme.primary)
                          : const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                      onTap: () => _showDetail(t),
                    )),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _todoTile(Todo t, {int? dragIndex}) {
    return Container(
      key: ValueKey(t.id),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.isOverdue ? Colors.red.shade200 : Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _showDetail(t),
        leading: GestureDetector(
          onTap: () => _toggle(t),
          child: Icon(
            t.done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: t.done ? Colors.grey : (t.isOverdue ? Colors.red : AppTheme.primary),
          ),
        ),
        title: Row(
          children: [
            if (t.isBusiness)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.storefront, size: 14, color: AppTheme.primary),
              ),
            Expanded(
              child: Text(
                t.title,
                style: TextStyle(
                  decoration: t.done ? TextDecoration.lineThrough : null,
                  color: t.done ? Colors.grey : AppTheme.textMain,
                ),
              ),
            ),
            if ((t.note ?? '').isNotEmpty)
              const Icon(Icons.sticky_note_2_outlined, size: 14, color: Colors.grey),
          ],
        ),
        subtitle: _TodoSubtitle(t: t),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _changePriority(t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.priorityColors[t.priority]!.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  {'urgent': '紧急', 'important': '重要', 'normal': '普通'}[t.priority]!,
                  style: TextStyle(color: AppTheme.priorityColors[t.priority], fontSize: 12),
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _delete(t)),
            if (dragIndex != null)
              ReorderableDragStartListener(index: dragIndex, child: const Icon(Icons.drag_handle)),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});
  @override
  Widget build(BuildContext context) => Center(
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
      );
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }
}

class _TodoSubtitle extends StatelessWidget {
  final Todo t;
  const _TodoSubtitle({required this.t});
  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    if (t.dueAt != null) {
      final due = t.dueAt!;
      final txt = DateFormat('MM-dd').format(due);
      final dl = t.daysLeft;
      String label;
      if (t.isOverdue) {
        label = '逾期 $txt';
      } else if (dl == 0) {
        label = '今天截止';
      } else if (dl == 1) {
        label = '明天截止';
      } else {
        label = '截止 $txt';
      }
      parts.add(Text(
        label,
        style: TextStyle(color: t.isOverdue ? Colors.red : Colors.grey.shade600, fontSize: 12),
      ));
      if (t.repeat != 'none') {
        parts.add(Text('🔁${_repeatLabel(t.repeat)}', style: const TextStyle(color: Colors.grey, fontSize: 12)));
      }
    }
    for (final tag in t.tagList) {
      parts.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(8)),
        child: Text('#$tag', style: const TextStyle(color: AppTheme.primaryDark, fontSize: 11)),
      ));
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 2, children: parts);
  }

  String _repeatLabel(String r) => {'daily': '每天', 'weekly': '每周', 'monthly': '每月'}[r] ?? '';
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TagChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppTheme.primary,
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.grey.shade700, fontSize: 12),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _TodoInput {
  final String title;
  final String priority;
  final String? tags;
  final String repeat;
  final DateTime? dueAt;
  final String ledger;
  final String? note;
  _TodoInput({
    required this.title,
    required this.priority,
    this.tags,
    this.repeat = 'none',
    this.dueAt,
    this.ledger = Ledger.personal,
    this.note,
  });
}

class _AddTodoDialog extends StatefulWidget {
  final Todo? initial;
  const _AddTodoDialog({this.initial});
  @override
  State<_AddTodoDialog> createState() => _AddTodoDialogState();
}

class _AddTodoDialogState extends State<_AddTodoDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _tagCtrl;
  late final TextEditingController _noteCtrl;
  late String _priority;
  late String _repeat;
  late String _ledger;
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _tagCtrl = TextEditingController(text: t?.tags ?? '');
    _noteCtrl = TextEditingController(text: t?.note ?? '');
    _priority = t?.priority ?? 'normal';
    _repeat = t?.repeat ?? 'none';
    _ledger = t?.ledger ?? Ledger.personal;
    _dueAt = t?.dueAt;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => _dueAt = d);
  }

  void _quickDue(int days) {
    final now = DateTime.now();
    setState(() => _dueAt = DateTime(now.year, now.month, now.day).add(Duration(days: days)));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return AlertDialog(
      title: Text(isEdit ? '编辑待办' : '新增待办'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _titleCtrl, autofocus: !isEdit, decoration: const InputDecoration(hintText: '要做啥？')),
            const SizedBox(height: 12),
            const Text('归属', style: TextStyle(fontSize: 13, color: Colors.grey)),
            Wrap(spacing: 8, children: [
              _ledgerChip(Ledger.personal, '🏠 个人'),
              _ledgerChip(Ledger.business, '🌍 跨境生意'),
            ]),
            const SizedBox(height: 12),
            const Text('优先级', style: TextStyle(fontSize: 13, color: Colors.grey)),
            Wrap(spacing: 8, children: [
              _priorityChip('normal', '普通'),
              _priorityChip('important', '重要'),
              _priorityChip('urgent', '紧急'),
            ]),
            const SizedBox(height: 12),
            const Text('截止日期（可选）', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: [
              ActionChip(label: const Text('今天', style: TextStyle(fontSize: 12)), onPressed: () => _quickDue(0)),
              ActionChip(label: const Text('明天', style: TextStyle(fontSize: 12)), onPressed: () => _quickDue(1)),
              ActionChip(label: const Text('3天后', style: TextStyle(fontSize: 12)), onPressed: () => _quickDue(3)),
              ActionChip(label: const Text('一周后', style: TextStyle(fontSize: 12)), onPressed: () => _quickDue(7)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              ElevatedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_dueAt == null ? '选择日期' : DateFormat('yyyy-MM-dd').format(_dueAt!)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight, foregroundColor: AppTheme.primaryDark),
              ),
              if (_dueAt != null)
                IconButton(onPressed: () => setState(() => _dueAt = null), icon: const Icon(Icons.clear, size: 18)),
            ]),
            const SizedBox(height: 12),
            const Text('重复（可选）', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              _repeatChip('none', '不重复'),
              _repeatChip('daily', '每天'),
              _repeatChip('weekly', '每周'),
              _repeatChip('monthly', '每月'),
            ]),
            const SizedBox(height: 12),
            const Text('标签（逗号分隔，可选）', style: TextStyle(fontSize: 13, color: Colors.grey)),
            TextField(controller: _tagCtrl, decoration: const InputDecoration(hintText: '如：运营,广告')),
            const SizedBox(height: 12),
            const Text('备注（可选）', style: TextStyle(fontSize: 13, color: Colors.grey)),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'SKU、链接、细节…'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            if (_titleCtrl.text.trim().isEmpty) return;
            Navigator.pop(context, _TodoInput(
              title: _titleCtrl.text.trim(),
              priority: _priority,
              tags: _tagCtrl.text.trim().isEmpty ? null : _tagCtrl.text.trim(),
              repeat: _repeat,
              dueAt: _dueAt,
              ledger: _ledger,
              note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            ));
          },
          child: Text(isEdit ? '保存' : '确定'),
        ),
      ],
    );
  }

  Widget _ledgerChip(String k, String label) {
    final sel = _ledger == k;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: sel,
      selectedColor: AppTheme.primary,
      labelStyle: TextStyle(color: sel ? Colors.white : Colors.grey.shade700, fontSize: 12),
      onSelected: (_) => setState(() => _ledger = k),
    );
  }

  Widget _priorityChip(String k, String label) {
    final sel = _priority == k;
    return ChoiceChip(label: Text(label), selected: sel, selectedColor: AppTheme.priorityColors[k], onSelected: (_) => setState(() => _priority = k));
  }

  Widget _repeatChip(String k, String label) {
    final sel = _repeat == k;
    return ChoiceChip(label: Text(label), selected: sel, selectedColor: AppTheme.accent, onSelected: (_) => setState(() => _repeat = k));
  }
}
