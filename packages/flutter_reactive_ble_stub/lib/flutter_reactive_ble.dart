// OpenHarmony 占位实现：flutter_reactive_ble 社区暂无鸿蒙适配，
// 这里仅提供最小 API 让工程在鸿蒙平台编译通过；运行时 BLE 不可用，
// 由 UI 层（device_screen）在 Platform.isOhos 时降级提示。
//
// 符号清单对照 scale_connector.dart / device_screen.dart 的使用：
//   FlutterReactiveBle, DiscoveredDevice, Uuid, ScanMode,
//   DeviceConnectionState, QualifiedCharacteristic,
//   DiscoveredService, DiscoveredCharacteristic
import 'dart:async';

class Uuid {
  const Uuid();
}

enum ScanMode { lowLatency, lowPower, balanced }

enum DeviceConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

class QualifiedCharacteristic {
  const QualifiedCharacteristic({
    required this.serviceId,
    required this.characteristicId,
    required this.deviceId,
  });
  final Uuid serviceId;
  final Uuid characteristicId;
  final String deviceId;
}

class DiscoveredCharacteristic {
  const DiscoveredCharacteristic({
    required this.characteristicId,
    this.isNotifiable = false,
  });
  final Uuid characteristicId;
  final bool isNotifiable;
}

class DiscoveredService {
  const DiscoveredService({
    required this.serviceId,
    this.characteristics = const <DiscoveredCharacteristic>[],
  });
  final Uuid serviceId;
  final List<DiscoveredCharacteristic> characteristics;
}

class DiscoveredDevice {
  const DiscoveredDevice({required this.id, this.name = ''});
  final String id;
  final String name;
}

class FlutterReactiveBle {
  /// 鸿蒙占位：不扫描真实设备。
  Stream<DiscoveredDevice> scanForDevices({
    required List<Uuid> withServices,
    ScanMode scanMode = ScanMode.lowLatency,
  }) {
    return const Stream.empty();
  }

  Stream<DeviceConnectionState> connectToDevice({required String id}) {
    return Stream.value(DeviceConnectionState.disconnected);
  }

  Future<List<DiscoveredService>> discoverServices(String id) async {
    return const <DiscoveredService>[];
  }

  Stream<List<int>> subscribeToCharacteristic(
      QualifiedCharacteristic characteristic) {
    return const Stream.empty();
  }
}
