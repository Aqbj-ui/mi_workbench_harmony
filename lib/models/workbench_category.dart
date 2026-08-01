// 米工作台 - 侧边栏分类（参照设计稿：每日计划/减肥/英语/AI学习/运动/妆容/读书...）
class WorkbenchCategory {
  final String id;
  String name;
  String icon; // emoji 或 icon name
  int sortOrder;

  WorkbenchCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'sort_order': sortOrder,
      };

  factory WorkbenchCategory.fromMap(Map<String, dynamic> m) => WorkbenchCategory(
        id: m['id'] as String,
        name: m['name'] as String,
        icon: m['icon'] as String,
        sortOrder: m['sort_order'] as int,
      );
}
