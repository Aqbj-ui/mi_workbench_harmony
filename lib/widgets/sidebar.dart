// 左侧侧边栏 - 参照设计稿（绿色 + 分类列表 + 折叠 + 底部水印）
// v3 UI 规范：选中态左侧绿色高亮条 + 折叠按钮显眼化 + 底部 v3 水印
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/workbench_category.dart';
import '../services/db_service.dart';
import 'package:uuid/uuid.dart';

class Sidebar extends StatefulWidget {
  final String selectedId;
  final ValueChanged<String> onSelect;
  const Sidebar({super.key, required this.selectedId, required this.onSelect});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  List<WorkbenchCategory> _cats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats = await DbService.instance.getCategories();
    if (mounted) setState(() => _cats = cats);
  }

  Future<void> _addCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddCategoryDialog(),
    );
    if (name != null && name.trim().isNotEmpty) {
      final c = WorkbenchCategory(
        id: const Uuid().v4(),
        name: name.trim(),
        icon: '⭐',
        sortOrder: _cats.length,
      );
      await DbService.instance.insertCategory(c);
      await _load();
    }
  }

  Future<void> _deleteCategory(WorkbenchCategory c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('删除"${c.name}"？'),
        content: const Text('该功能将从侧边栏移除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await DbService.instance.deleteCategory(c.id);
      await _load();
      if (widget.selectedId == c.id) widget.onSelect('todo');
    }
  }

  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final expandedWidth = 220.0;
    final collapsedWidth = 64.0;
    final w = _collapsed ? collapsedWidth : expandedWidth;
    return SizedBox(
      width: w,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 侧栏主体
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: w,
            decoration: const BoxDecoration(
              gradient: AppTheme.sidebarGradient,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 0))],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Logo + 标题
                  Padding(
                    padding: EdgeInsets.fromLTRB(_collapsed ? 8 : 16, 16, _collapsed ? 8 : 16, 12),
                    child: Row(
                      mainAxisAlignment: _collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: const Center(child: Text('米', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                        ),
                        if (!_collapsed) ...[
                          const SizedBox(width: 10),
                          const Flexible(child: Text('米工作台', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                        ],
                      ],
                    ),
                  ),
                  // 内置功能（固定）
                  _SidebarItem(iconData: Icons.dashboard, label: '概览', selected: widget.selectedId == 'dashboard', collapsed: _collapsed, onTap: () => widget.onSelect('dashboard')),
                  _SidebarItem(iconData: Icons.check_box, label: '待办', selected: widget.selectedId == 'todo', collapsed: _collapsed, onTap: () => widget.onSelect('todo')),
                  _SidebarItem(iconData: Icons.account_balance_wallet, label: '记账', selected: widget.selectedId == 'bookkeeping', collapsed: _collapsed, onTap: () => widget.onSelect('bookkeeping')),
                  _SidebarItem(iconData: Icons.fitness_center, label: '运动', selected: widget.selectedId == 'exercise', collapsed: _collapsed, onTap: () => widget.onSelect('exercise')),
                  _SidebarItem(iconData: Icons.monitor_weight, label: '体重', selected: widget.selectedId == 'weight', collapsed: _collapsed, onTap: () => widget.onSelect('weight')),
                  _SidebarItem(iconData: Icons.repeat, label: '习惯', selected: widget.selectedId == 'habit', collapsed: _collapsed, onTap: () => widget.onSelect('habit')),
                  _SidebarItem(iconData: Icons.bluetooth, label: '设备', selected: widget.selectedId == 'device', collapsed: _collapsed, onTap: () => widget.onSelect('device')),
                  _SidebarItem(iconData: Icons.notifications_active, label: '提醒', selected: widget.selectedId == 'reminder', collapsed: _collapsed, onTap: () => widget.onSelect('reminder')),
                  _SidebarItem(iconData: Icons.settings, label: '设置', selected: widget.selectedId == 'settings', collapsed: _collapsed, onTap: () => widget.onSelect('settings')),
                  if (!_collapsed) const Divider(color: Colors.white24, indent: 16, endIndent: 16),
                  // 用户自定义分类
                  Expanded(
                    child: ListView.builder(
                      itemCount: _cats.length,
                      itemBuilder: (_, i) {
                        final c = _cats[i];
                        return _SidebarItem(
                          iconData: null,
                          emoji: c.icon,
                          label: c.name,
                          selected: widget.selectedId == c.id,
                          collapsed: _collapsed,
                          onTap: () => widget.onSelect(c.id),
                          onLongPress: () => _deleteCategory(c),
                        );
                      },
                    ),
                  ),
                  // 底部 v3 水印（深色模式加亮可读）
                  if (!_collapsed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        'v3.0 · 本地数据\nCodemagic 构建',
                        style: TextStyle(
                          color: AppTheme.sidebarFootColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                  // 底部增加/删除按钮
                  if (!_collapsed)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _addCategory,
                              icon: const Icon(Icons.add, size: 16, color: Colors.white),
                              label: const Text('增加工作', style: TextStyle(color: Colors.white, fontSize: 12)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(vertical: 8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (_cats.isNotEmpty) _deleteCategory(_cats.last);
                              },
                              icon: const Icon(Icons.remove, size: 16, color: Colors.white),
                              label: const Text('删除工作', style: TextStyle(color: Colors.white, fontSize: 12)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(vertical: 8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 折叠按钮（v3 显眼化：移到侧栏外 + 大色块 + ⇆ 图标 + 高亮阴影）
          Positioned(
            top: 0,
            bottom: 0,
            right: -18,
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => _collapsed = !_collapsed),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: AppTheme.fabShadow,
                  ),
                  child: Center(
                    child: AnimatedRotation(
                      turns: _collapsed ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData? iconData;
  final String? emoji;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _SidebarItem({
    this.iconData,
    this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: collapsed ? 6 : 8, vertical: 2),
        padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Stack(
          children: [
            // v3 选中态左侧绿色高亮条
            if (selected && !collapsed)
              Positioned(
                left: 0, top: 6, bottom: 6, width: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.sidebarActiveBar,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: AppTheme.sidebarActiveBar.withOpacity(0.6), blurRadius: 6)],
                  ),
                ),
              ),
            // v3 折叠态：底部居中高亮条
            if (selected && collapsed)
              Positioned(
                left: 12, right: 12, bottom: 2, height: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.sidebarActiveBar,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                iconData != null
                    ? Icon(iconData, color: Colors.white, size: 18)
                    : Text(emoji ?? '⭐', style: const TextStyle(fontSize: 16)),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();
  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _ctrl = TextEditingController();
  String _emoji = '⭐';
  final _emojis = ['⭐', '📅', '🥗', '🔤', '🤖', '🏃', '💄', '📚', '📝', '🌸', '💛', '🔍', '🎯', '💼', '🎨', '🎵'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('增加工作'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(labelText: '名称', hintText: '如：写作'),
          ),
          const SizedBox(height: 12),
          const Text('选择图标'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: _emojis.map((e) {
              final sel = e == _emoji;
              return GestureDetector(
                onTap: () => setState(() => _emoji = e),
                child: Container(
                  width: 36, height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.primary.withOpacity(0.2) : Colors.transparent,
                    border: Border.all(color: sel ? AppTheme.primary : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 18)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(onPressed: () => Navigator.pop(context, _ctrl.text), child: const Text('确定')),
      ],
    );
  }
}