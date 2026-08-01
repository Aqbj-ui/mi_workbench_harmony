// 米工作台主题 - 绿色基调（参照设计稿）+ 深色模式 + v3 UI 规范
import 'package:flutter/material.dart';

class AppTheme {
  // 主色（绿色，从设计稿提取）
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFFE8F5E9);
  static const Color accent = Color(0xFF66BB6A);

  // 深色模式下用亮一点的绿，避免暗背景上发闷
  static const Color primaryOnDark = Color(0xFF66BB6A);

  // 侧边栏渐变（深浅通用：绿色渐变上永远是白字）
  static const LinearGradient sidebarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
  );

  // ===================== v3 全局规范：半径 / 阴影 / 语义色 =====================
  /// 半径统一（v3）
  static const double radiusXs = 6;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 999;

  /// FAB 默认阴影（v3）
  static List<BoxShadow> get fabShadow => _dark
      ? const [BoxShadow(color: Color(0xCC000000), blurRadius: 14, offset: Offset(0, 6))]
      : const [BoxShadow(color: Color(0x662E7D32), blurRadius: 14, offset: Offset(0, 6))];

  // 标签色
  static const Map<String, Color> priorityColors = {
    'urgent': Color(0xFFE53935), // 紧急 - 红
    'important': Color(0xFFFFA726), // 重要 - 橙
    'normal': Color(0xFF66BB6A), // 普通 - 绿
  };

  // 记账分类色（环图用）
  static const List<Color> categoryColors = [
    Color(0xFF66BB6A), // 水果 - 绿
    Color(0xFF42A5F5), // 餐饮 - 蓝
    Color(0xFFFFA726), // 交通 - 橙
    Color(0xFFAB47BC), // 购物 - 紫
    Color(0xFFEF5350), // 娱乐 - 红
    Color(0xFF26A69A), // 生活 - 青
    Color(0xFF8D6E63), // 其他 - 棕
  ];

  // ===================== 深浅色语义色 =====================
  // 说明：页面里大量自绘卡片（Container + BoxDecoration），不走 Card 组件，
  // 拿不到 ThemeData。这里用一个全局 brightness 标记 + 静态 getter，
  // 主题切换时 MaterialApp 整树重建，读到的值自然是最新的。
  static bool _dark = false;
  static bool get isDark => _dark;

  /// 由 MaterialApp.builder 每帧同步，确保和当前主题一致
  static void syncBrightness(Brightness b) {
    _dark = b == Brightness.dark;
  }

  /// 自绘卡片背景
  static Color get cardBg =>
      _dark ? const Color(0xFF1F2124) : Colors.white;

  /// 页面底色（比卡片更深一层）
  static Color get pageBg =>
      _dark ? const Color(0xFF131416) : const Color(0xFFFAFAFA);

  /// 弱背景（分组条、空状态、次级块）
  static Color get subtleBg =>
      _dark ? const Color(0xFF25282C) : const Color(0xFFF5F5F5);

  /// 描边
  static Color get borderColor =>
      _dark ? const Color(0xFF34383D) : const Color(0xFFE0E0E0);

  /// 主文字
  static Color get textMain =>
      _dark ? const Color(0xFFE8E8E8) : Colors.black87;

  /// 次要文字
  static Color get textMuted =>
      _dark ? const Color(0xFF9AA0A6) : const Color(0xFF757575);

  /// 强调绿（深色下自动提亮）
  static Color get brandOn => _dark ? primaryOnDark : primary;

  /// v3 侧边栏选中态左侧高亮条
  static Color get sidebarActiveBar =>
      _dark ? const Color(0xFF81C784) : const Color(0xFF66BB6A);

  /// v3 侧边栏底部水印（v3.0 · 本地数据...），深色模式下加亮保证可读
  static Color get sidebarFootColor =>
      _dark ? const Color(0xCCEAF6EB) : const Color(0xCCFFFFFF);

  /// v3 appbar 右侧操作颜色
  static Color get appBarActionColor =>
      _dark ? const Color(0xCCE8E8E8) : const Color(0xE6FFFFFF);

  /// v3 输入框深色模式背景/边框
  static Color get inputBg =>
      _dark ? const Color(0xFF25282C) : Colors.white;
  static Color get inputBorder =>
      _dark ? const Color(0xFF3D4248) : const Color(0xFFE0E0E0);

  /// v3 逾期浅红警示背景
  static Color get alertBg =>
      _dark ? const Color(0x33E53935) : const Color(0xFFFFEBEE);
  static Color get alertBorder =>
      _dark ? const Color(0x80E53935) : const Color(0xFFFFCDD2);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDarkMode = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: b,
      primary: isDarkMode ? primaryOnDark : primary,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDarkMode ? const Color(0xFF131416) : const Color(0xFFFAFAFA),
      canvasColor: isDarkMode ? const Color(0xFF1F2124) : Colors.white,
      dialogBackgroundColor:
          isDarkMode ? const Color(0xFF1F2124) : Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: isDarkMode ? const Color(0xFF1B1D20) : primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: isDarkMode ? const Color(0xFF1F2124) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDarkMode ? const Color(0xFF1F2124) : Colors.white,
      ),
      dividerColor:
          isDarkMode ? const Color(0xFF34383D) : const Color(0xFFE0E0E0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDarkMode ? primaryOnDark : primary,
          foregroundColor: isDarkMode ? Colors.black87 : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
    );
  }
}
