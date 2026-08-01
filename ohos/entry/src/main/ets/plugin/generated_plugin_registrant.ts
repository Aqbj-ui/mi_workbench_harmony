import { FlutterEngine } from '@ohos/flutter_ohos';

// 占位插件登记器。首次在装有 OpenHarmony Flutter SDK 的机器上执行
// `flutter create --platforms=ohos .` 后，工具会生成真实的插件登记代码
// （根据工程实际依赖的鸿蒙适配插件自动填充）。此处为空实现，保证编译通过。
export class GeneratedPluginRegistrant {
  static registerWith(flutterEngine: FlutterEngine) {
    // intentionally empty
  }
}
