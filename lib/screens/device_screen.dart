// 设备连接页：通用蓝牙设备 + 睡眠（手动 / 手表手环预留）
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart' hide Uuid;
import 'package:uuid/uuid.dart';
import '../services/scale_connector.dart';
import '../services/sleep_service.dart';
import '../services/db_service.dart';
import '../models/weight_record.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});
  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  final _ble = BleDeviceConnector();
  final _sleep = SleepService();
  List<DiscoveredDevice> _devices = [];
  bool _scanning = false;
  bool _connecting = false;
  String _status = '未连接';

  IconData _iconFor(DeviceKind k) =>
      k == DeviceKind.scale ? Icons.scale : k == DeviceKind.watch ? Icons.watch : Icons.bluetooth;

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _devices = [];
      _status = '正在搜索附近蓝牙设备（体脂秤 / 手表 / 心率带…任意 BLE 均可）...';
    });
    final sub = _ble.scan().listen((d) {
      if (!_devices.any((x) => x.id == d.id)) {
        setState(() => _devices.add(d));
      }
    });
    await Future.delayed(const Duration(seconds: 8));
    await sub.cancel();
    setState(() {
      _scanning = false;
      _status = _devices.isEmpty
          ? '未找到任何蓝牙设备，请确认手机蓝牙已开、设备已开机且在附近'
          : '找到 ${_devices.length} 个设备，点击「连接」（体脂秤连接后上秤站稳等待读数）';
    });
  }

  Future<void> _connect(DiscoveredDevice d) async {
    setState(() {
      _connecting = true;
      _status = '连接 ${d.name} 中…';
    });
    final kind = _ble.guessKind(d);
    if (kind == DeviceKind.scale) {
      final w = await _ble.connectAndRead(d);
      if (w != null) {
        final rec = WeightRecord(id: const Uuid().v4(), weightKg: w);
        await DbService.instance.insertWeight(rec);
        setState(() => _status =
            '✅ 已自动记录体重 ${w.toStringAsFixed(1)} kg。如秤显示体脂率，请在「体重」页点 + 补充体脂。');
      } else {
        setState(() => _status =
            '未能从 ${d.name} 读取体重（可能不是体脂秤，或需真机联调微调解析）；可改用手动录入。');
      }
    } else {
      // 非体脂秤设备：连接即成功，无体重解析
      setState(() => _status =
          '✅ 已连接 ${d.name}（${kind == DeviceKind.watch ? '手表/手环' : '其他设备'}）。睡眠自动同步需付费 Apple 账号启用 HealthKit，现在请用「手动记录睡眠」。');
    }
    setState(() => _connecting = false);
  }

  Future<void> _manualSleep() async {
    final bed = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 23, minute: 0));
    if (bed == null) return;
    final wake = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 7, minute: 0));
    if (wake == null) return;
    final now = DateTime.now();
    final bedtime = DateTime(now.year, now.month, now.day, bed.hour, bed.minute);
    final wakeTime = DateTime(now.year, now.month, now.day, wake.hour, wake.minute);
    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('睡眠备注（可选）'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(hintText: '如：多梦 / 中途醒 / 质量好'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, noteCtrl.text),
              child: const Text('保存')),
        ],
      ),
    );
    if (note == null) return;
    await _sleep.saveManual(
      date: now,
      bedtime: bedtime,
      wakeTime: wakeTime,
      note: note.isEmpty ? null : note,
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已记录今日睡眠')));
    }
  }

  Future<void> _connectWearable() async {
    final ok = await _sleep.connectWearable();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? '已连接'
            : '当前免费侧载暂不支持自动同步。手表/手环睡眠需在付费 Apple 开发者账号下启用 HealthKit 后读取；现在请用「手动记录睡眠」。'),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设备连接')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (Platform.isOhos)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('鸿蒙版蓝牙说明',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  SizedBox(height: 4),
                  Text(
                      'flutter_reactive_ble 社区暂无鸿蒙（OpenHarmony）适配，体脂秤自动读数暂不可用。'
                      '体重仍可在「体重」页手动录入；待社区适配后本页即可恢复扫描。',
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                ],
              ),
            ),
          const Text('蓝牙设备（通用）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
              '支持体脂秤 / 手表手环 / 心率带等任意 BLE 设备，不限定品牌。连接体脂秤后上秤可自动读体重。',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: (_scanning || Platform.isOhos) ? null : _startScan,
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(_scanning
                ? '搜索中…'
                : (Platform.isOhos ? '鸿蒙版暂不支持扫描' : '扫描附近设备')),
          ),
          const SizedBox(height: 8),
          ..._devices.map((d) => ListTile(
                leading: Icon(_iconFor(_ble.guessKind(d))),
                title: Text(d.name.isEmpty ? '(未知设备)' : d.name),
                subtitle: Text(d.id),
                trailing: _connecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: () => _connect(d),
                        child: const Text('连接'),
                      ),
              )),
          const SizedBox(height: 8),
          Text(_status, style: const TextStyle(color: Colors.grey)),
          const Divider(height: 32),
          const Text('睡眠（手表 / 手环）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
              '买手表/手环后，其睡眠数据经 iPhone 健康 App 聚合。当前免费侧载暂不支持自动读取，可手动记录。',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _manualSleep,
            icon: const Icon(Icons.bedtime),
            label: const Text('手动记录睡眠'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _connectWearable,
            icon: const Icon(Icons.watch),
            label: const Text('连接健康 App / 手表（自动同步）'),
          ),
        ],
      ),
    );
  }
}
