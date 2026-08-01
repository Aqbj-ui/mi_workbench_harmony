// 主页：侧边栏 + 主区域
import 'package:flutter/material.dart';
import '../widgets/sidebar.dart';
import 'dashboard_screen.dart';
import 'todo_screen.dart';
import 'bookkeeping_screen.dart';
import 'exercise_screen.dart';
import 'weight_screen.dart';
import 'habit_screen.dart';
import 'device_screen.dart';
import 'reminder_screen.dart';
import 'settings_screen.dart';
import 'health_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedId = 'dashboard';

  Widget _buildContent() {
    switch (_selectedId) {
      case 'dashboard':
        return DashboardScreen(onNavigate: (id) => setState(() => _selectedId = id));
      case 'todo':
        return const TodoScreen();
      case 'bookkeeping':
        return const BookkeepingScreen();
      case 'exercise':
        return const ExerciseScreen();
      case 'weight':
        return const WeightScreen();
      case 'habit':
        return const HabitScreen();
      case 'device':
        return const DeviceScreen();
      case 'reminder':
        return const ReminderScreen();
      case 'settings':
        return const SettingsScreen();
      case 'health':
        return HealthDetailScreen(
            onNavigate: (id) => setState(() => _selectedId = id));
      default:
        return _Placeholder(title: '功能正在开发', hint: '你可以在侧边栏底部"删除工作"中移除它');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            selectedId: _selectedId,
            onSelect: (id) => setState(() => _selectedId = id),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  final String hint;
  const _Placeholder({required this.title, required this.hint});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(hint, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
