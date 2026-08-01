// 顶部 appbar 主题切换按钮（v3 UI 规范：所有页面常驻）
import 'package:flutter/material.dart';
import '../main.dart' show appThemeMode, themeModeToString;
import '../services/settings_service.dart';

class ThemeToggleIconButton extends StatelessWidget {
  const ThemeToggleIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) {
        final isDarkEffective = mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        return IconButton(
          tooltip: isDarkEffective ? '切到浅色' : '切到深色',
          icon: Icon(isDarkEffective ? Icons.light_mode : Icons.dark_mode),
          onPressed: () async {
            final next = isDarkEffective ? ThemeMode.light : ThemeMode.dark;
            appThemeMode.value = next;
            try {
              await SettingsService.instance.setThemeMode(themeModeToString(next));
            } catch (_) {}
          },
        );
      },
    );
  }
}