// 米工作台 - 入口
import 'dart:async';
import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'services/db_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';

/// 全局主题模式（设置页改这个，整树自动重建）
final ValueNotifier<ThemeMode> appThemeMode =
    ValueNotifier<ThemeMode>(ThemeMode.system);

ThemeMode themeModeFromString(String s) {
  switch (s) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

String themeModeToString(ThemeMode m) {
  switch (m) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化数据库
  await DbService.instance.getCategories();
  // 读取外观偏好（很轻，放在首帧前避免闪一下白）
  try {
    appThemeMode.value =
        themeModeFromString(await SettingsService.instance.themeMode);
  } catch (_) {}
  // 初始化本地通知（很快），提醒重排放后台跑，不拖慢冷启动
  await NotificationService.instance.init();
  unawaited(NotificationService.instance.rescheduleAll());
  runApp(const MiWorkbenchApp());
}

class MiWorkbenchApp extends StatelessWidget {
  const MiWorkbenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (_, mode, __) => MaterialApp(
        title: '米工作台',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        // 页面里大量自绘卡片靠 AppTheme 的静态语义色取色，
        // 这里每次重建时把当前亮度同步过去，保证深浅色一致。
        builder: (ctx, child) {
          AppTheme.syncBrightness(Theme.of(ctx).brightness);
          return child ?? const SizedBox.shrink();
        },
        home: const HomeScreen(),
      ),
    );
  }
}
