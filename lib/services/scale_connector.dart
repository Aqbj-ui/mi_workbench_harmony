// 通用蓝牙设备连接器（不限品牌 / 型号）
//
// 设计原则：扫描附近「所有」BLE 设备，连接时不挑品牌。体脂秤（小米 / 华为 /
// 沃莱蚂蚁阿福 / 有品 / 香山 / Fitdays 代工…）、手表手环、心率带等都能被发现与连接。
//
// 说明：
// - 体重解析为通用启发式：不同秤编码不同，真机联调时按需微调 _tryParseWeight。
//   体脂率多属各品牌私有协议（Fitdays / 米家 SDK 等），暂未全量自动解析，用户在「体重」页手动补。
// - 手表/手环的睡眠「自动同步」依赖苹果 HealthKit（需付费开发者账号），免费侧载暂不可用；
//   已提供手动记睡眠兜底，自动同步接口在 SleepService.connectWearable() 预留。
// - _hints 只用于「猜图标/分类」，绝不做连接过滤——任何设备都能连。
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

enum DeviceKind { scale, watch, other }

class BleDeviceConnector {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // 仅用于「猜图标/分类」的广播名特征，不影响连接（任意设备都可连）。
  static const Map<DeviceKind, List<String>> _hints = {
    DeviceKind.scale: [
      'SCALE', 'MI SCALE', 'MISCALE', 'WELLAND', 'HPS', 'FITDAYS',
      '蚂蚁阿福', 'A1', '体脂', '体重', 'WEIGHT', 'YF', 'QINGPING', 'XIAOMI',
      'REALME', 'OPPO', 'YOLANDA', 'FORA',
    ],
    DeviceKind.watch: [
      'BAND', 'WATCH', 'MI BAND', 'HUAWEI', 'HONOR', 'GALAXY', '手表', '手环', 'WEAR', 'GTR', 'GTS',
    ],
  };

  DeviceKind guessKind(DiscoveredDevice d) {
    final n = d.name.toUpperCase();
    for (final e in _hints.entries) {
      if (e.value.any((h) => n.contains(h))) return e.key;
    }
    return DeviceKind.other;
  }

  // 扫描附近所有 BLE 设备（不过滤品牌）
  Stream<DiscoveredDevice> scan() {
    return _ble.scanForDevices(
      withServices: const <Uuid>[],
      scanMode: ScanMode.lowLatency,
    );
  }

  // 连接并读取一次体重（kg）。读不到返回 null，调用方回退手动录入。
  // 对任意设备都尝试：体脂秤通常会广播/通知体重特征值。
  Future<double?> connectAndRead(DiscoveredDevice device) async {
    final completer = Completer<double?>();
    final subs = <StreamSubscription<List<int>>>[];
    final connSub = _ble.connectToDevice(id: device.id).listen((state) async {
      if (state.connectionState != DeviceConnectionState.connected) {
        if (state.connectionState == DeviceConnectionState.disconnected &&
            !completer.isCompleted) {
          completer.complete(null);
        }
        return;
      }
      try {
        final services = await _ble.discoverServices(device.id);
        for (final s in services) {
          for (final c in s.characteristics) {
            if (!c.isNotifiable) continue;
            final qc = QualifiedCharacteristic(
              serviceId: s.serviceId,
              characteristicId: c.characteristicId,
              deviceId: device.id,
            );
            final sub = _ble.subscribeToCharacteristic(qc).listen((data) {
              final w = _tryParseWeight(data);
              if (w != null && !completer.isCompleted) completer.complete(w);
            });
            subs.add(sub);
          }
        }
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      }
    });
    final result = await completer.future
        .timeout(const Duration(seconds: 25), onTimeout: () => null);
    for (final s in subs) await s.cancel();
    await connSub.cancel();
    return result;
  }

  // 启发式解析体重（kg）。覆盖常见编码：uint16*0.01 / uint16/10 / float32 LE。
  double? _tryParseWeight(List<int> b) {
    if (b.isEmpty) return null;
    if (b.length >= 2) {
      final u16 = b[0] + (b[1] << 8);
      final w1 = u16 * 0.01;
      if (w1 > 20 && w1 < 300) return w1;
      final w2 = u16 / 10.0;
      if (w2 > 20 && w2 < 300) return w2;
    }
    if (b.length >= 4) {
      final bd = ByteData.sublistView(Uint8List.fromList(b));
      final f = bd.getFloat32(0, Endian.little);
      if (f > 20 && f < 300) return f;
    }
    return null;
  }
}
