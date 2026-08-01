// 体重：输入 + 自动记录 + 曲线图 + 目标体重 + 距目标进度 + BMI + 体脂
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/weight_record.dart';
import '../services/db_service.dart';
import '../services/settings_service.dart';
import '../services/sleep_service.dart';
import '../theme.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});
  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  List<WeightRecord> _list = [];
  double _goal = 0;
  double _height = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DbService.instance.getWeights();
    final goal = await SettingsService.instance.weightGoal;
    final height = await SettingsService.instance.heightCm;
    setState(() {
      _list = list;
      _goal = goal;
      _height = height;
    });
  }

  Future<void> _setProfile() async {
    final hCtrl = TextEditingController(text: _height > 0 ? _height.toStringAsFixed(0) : '');
    final gCtrl = TextEditingController(text: _goal > 0 ? _goal.toStringAsFixed(1) : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('目标 & 身体数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: hCtrl, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(suffixText: 'cm', labelText: '身高（算 BMI 用）')),
            const SizedBox(height: 12),
            TextField(controller: gCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(suffixText: 'kg', labelText: '目标体重')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) {
      final h = double.tryParse(hCtrl.text) ?? 0;
      final g = double.tryParse(gCtrl.text) ?? 0;
      await SettingsService.instance.setHeightCm(h);
      await SettingsService.instance.setWeightGoal(g);
      await _load();
    }
  }

  Future<void> _add() async {
    final res = await showDialog<_WeightInput>(
      context: context,
      builder: (_) => const _AddWeightDialog(),
    );
    if (res == null) return;
    final w = WeightRecord(id: const Uuid().v4(), weightKg: res.weight, bodyFat: res.bodyFat);
    await DbService.instance.insertWeight(w);
    // 体重与睡眠绑定：录入体重时顺带记录当日睡眠
    if (res.bedtime != null && res.wakeTime != null) {
      await SleepService().saveManual(
        date: DateTime.now(),
        bedtime: res.bedtime,
        wakeTime: res.wakeTime,
      );
    }
    await _load();
  }

  Future<void> _delete(WeightRecord w) async {
    await DbService.instance.deleteWeight(w.id);
    await _load();
  }

  ({String category, Color color}) _bmiInfo(double kg) {
    if (_height <= 0) return (category: '设置身高后显示', color: Colors.grey);
    final m = _height / 100;
    final bmi = kg / (m * m);
    if (bmi < 18.5) return (category: '偏瘦', color: Colors.blue);
    if (bmi < 24) return (category: '正常', color: Colors.green);
    if (bmi < 28) return (category: '超重', color: Colors.orange);
    return (category: '肥胖', color: Colors.red);
  }

  double _progressToGoal() {
    if (_goal <= 0 || _list.isEmpty) return 0;
    final latest = _list.last.weightKg;
    final base = _list.first.weightKg;
    if ((base - _goal).abs() < 0.01) return 1;
    final total = base - _goal;
    final done = base - latest;
    return (done / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _list.isNotEmpty;
    final latest = hasData ? _list.last.weightKg : 0.0;
    final first = hasData ? _list.first.weightKg : 0.0;
    final delta = hasData ? (latest - first) : 0.0;
    final bmi = _bmiInfo(latest);

    return Scaffold(
      appBar: AppBar(
        title: const Text('体重'),
        actions: [
          IconButton(icon: const Icon(Icons.tune), onPressed: _setProfile, tooltip: '目标/身高'),
          IconButton(onPressed: _add, icon: const Icon(Icons.add)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: AppTheme.sidebarGradient, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('当前体重', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(hasData ? '${latest.toStringAsFixed(1)} kg' : '--', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  Text('共 ${_list.length} 次记录', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                if (hasData)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: delta >= 0 ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text('${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}', style: TextStyle(color: delta >= 0 ? Colors.red.shade100 : Colors.green.shade100, fontWeight: FontWeight.bold)),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            // 目标 + BMI
            if (_goal > 0 || _height > 0)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderColor)),
                child: Column(children: [
                  if (_goal > 0) ...[
                    Row(children: [
                      const Text('目标', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text('${_goal.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(hasData ? '距目标 ${(latest - _goal >= 0 ? '+' : '')}${(latest - _goal).toStringAsFixed(1)} kg' : '', style: TextStyle(color: (latest - _goal) > 0 ? Colors.red : Colors.green, fontSize: 12)),
                    ]),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _progressToGoal(), minHeight: 6, backgroundColor: Colors.grey.shade200, color: AppTheme.primary),
                    const SizedBox(height: 8),
                  ],
                  if (_height > 0 && hasData)
                    Row(children: [
                      const Text('BMI', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text(bmi.category, style: TextStyle(color: bmi.color, fontWeight: FontWeight.w600)),
                    ]),
                ]),
              ),
            const SizedBox(height: 16),
            Container(
              height: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderColor)),
              child: hasData
                  ? LineChart(LineChartData(
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= _list.length) return const SizedBox.shrink();
                          return Text(DateFormat('M/d').format(_list[i].measuredAt), style: const TextStyle(fontSize: 10));
                        })),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      minY: (_list.map((e) => e.weightKg).reduce((a, b) => a < b ? a : b) - 2),
                      maxY: (_list.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b) + 2),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _list.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.weightKg)).toList(),
                          isCurved: true, color: AppTheme.primary, barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(show: true, color: AppTheme.primary.withOpacity(0.15)),
                        ),
                      ],
                    ))
                  : const Center(child: Text('暂无数据，点右上 + 开始记录', style: TextStyle(color: Colors.grey))),
            ),
            const SizedBox(height: 12),
            const Text('历史记录', style: TextStyle(fontWeight: FontWeight.w600)),
            Expanded(
              child: _list.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      itemCount: _list.length,
                      itemBuilder: (_, i) {
                        final w = _list[_list.length - 1 - i];
                        return ListTile(
                          dense: true,
                          title: Text('${w.weightKg.toStringAsFixed(1)} kg${w.bodyFat != null ? ' · 体脂 ${w.bodyFat!.toStringAsFixed(1)}%' : ''}'),
                          subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(w.measuredAt)),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _delete(w)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightInput {
  final double weight;
  final double? bodyFat;
  final DateTime? bedtime;
  final DateTime? wakeTime;
  const _WeightInput(
      {required this.weight, this.bodyFat, this.bedtime, this.wakeTime});
}

class _AddWeightDialog extends StatefulWidget {
  const _AddWeightDialog();
  @override
  State<_AddWeightDialog> createState() => _AddWeightDialogState();
}

class _AddWeightDialogState extends State<_AddWeightDialog> {
  final _wCtrl = TextEditingController();
  final _fCtrl = TextEditingController();
  TimeOfDay? _bed;
  TimeOfDay? _wake;

  Future<void> _pickBed() async {
    final t = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 23, minute: 0));
    if (t != null) setState(() => _bed = t);
  }

  Future<void> _pickWake() async {
    final t = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 7, minute: 0));
    if (t != null) setState(() => _wake = t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('记录体重 + 当日睡眠'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _wCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  suffixText: 'kg', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  suffixText: '%', labelText: '体脂率（可选）'),
            ),
            const SizedBox(height: 12),
            const Text('顺带记录今日睡眠（可选）',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('就寝时间'),
              trailing:
                  Text(_bed == null ? '未设' : _bed!.format(context)),
              onTap: _pickBed,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('起床时间'),
              trailing:
                  Text(_wake == null ? '未设' : _wake!.format(context)),
              onTap: _pickWake,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            final v = double.tryParse(_wCtrl.text);
            if (v == null || v <= 0) return;
            final now = DateTime.now();
            final bedtime = _bed == null
                ? null
                : DateTime(now.year, now.month, now.day, _bed!.hour, _bed!.minute);
            final wakeTime = _wake == null
                ? null
                : DateTime(now.year, now.month, now.day, _wake!.hour, _wake!.minute);
            Navigator.pop(
              context,
              _WeightInput(
                weight: v,
                bodyFat: double.tryParse(_fCtrl.text),
                bedtime: bedtime,
                wakeTime: wakeTime,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
