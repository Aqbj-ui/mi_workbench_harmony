# 米工作台 · HarmonyOS（OpenHarmony）版构建指南

本目录是「米工作台」的 **鸿蒙（HarmonyOS NEXT / OpenHarmony）版**，复用原 iOS 工程的
全部 Dart 业务代码（`lib/` 直接拷贝），仅额外叠加 `ohos/` 平台壳 + 少量平台兼容改造。

> ⚠️ 重要说明：本工程由 AI 在本机（无 DevEco / 无 OpenHarmony Flutter SDK）按官方标准结构
> 手写完成，**未做真机编译验证**。拿到装有鸿蒙环境的机器按下方步骤即可编译运行；
> 若个别三方库 API 有细微出入，以对应插件的 `example` 为准微调即可。

---

## 一、环境要求（一次性搭建）

| 组件 | 版本 / 说明 |
|------|------------|
| OpenHarmony Flutter SDK | `flutter_flutter` 3.27.4-ohos-1.0.4（OpenHarmony SIG 维护，**非官方 Flutter**）|
| DevEco Studio | 5.0+（推荐 6.1.1 Release），安装时勾选 HarmonyOS SDK（API 12）|
| HarmonyOS SDK API | **固定 API 12**（3.27.x 仅适配 12，API 13 未完成适配）|
| JDK | 17 |
| Node.js | 22.x LTS |
| ohpm / hvigor | 随 DevEco 安装，需加入 PATH |
| 镜像 | `PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn` |

环境变量示例（Windows PowerShell）：
```powershell
$env:FLUTTER_ROOT = "D:\flutter_ohos"
$env:PATH = "$env:FLUTTER_ROOT\bin;$env:PATH"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:TOOL_HOME = "D:\DevEco Studio"
$env:DEVECO_SDK_HOME = "$env:TOOL_HOME\sdk"
$env:PATH += ";$env:TOOL_HOME\tools\ohpm\bin;$env:TOOL_HOME\tools\hvigor\bin;$env:TOOL_HOME\tools\node\bin"
```
`flutter doctor -v` 应输出 `Flutter (Channel [user-branch], 3.27.4-ohos-1.0.4)` 且鸿蒙工具链 OK。

---

## 二、构建步骤

```bash
# 1) 进入本目录
cd mi_workbench_harmony

# 2) 生成 / 修正权威 ohos 平台壳（关键！会生成 flutter_ohos.har、
#    自动修正 entry/oh-package.json5 的 har 路径、填充 GeneratedPluginRegistrant）
flutter create --platforms=ohos .

# 3) 拉取依赖（已通过 dependency_overrides 指向 OpenHarmony 适配版）
flutter pub get

# 4) 清缓存（可选，遇到依赖异常时执行）
flutter clean && flutter pub get

# 5) 连上鸿蒙设备或启动模拟器
flutter devices

# 6) 运行调试
flutter run -d <device_id>

# 7) 打 release HAP 包
flutter build hap --release
#    产物：build/ohos/entry/default/outputs/default/entry-default-signed.hap

# 8) 安装到真机（需 hdc）
hdc install build\ohos\entry\default\outputs\default\entry-default-signed.hap
```

> 也可用一键脚本：`build_ohos.sh`（Linux/macOS）或 `build_ohos.ps1`（Windows）。

---

## 三、签名

鸿蒙应用**强制签名**，未签名无法安装。DevEco 内：
`File → Project Structure → Project → Signing Configs`，
勾选 **Automatically generate signature**（需登录华为账号），IDE 自动生成调试证书。

---

## 四、平台兼容改造清单（本工程已处理）

| 位置 | 改造 |
|------|------|
| `lib/services/notification_service.dart` | `InitializationSettings` 增加 `ohos:` 分支（`OHOSInitializationSettings`）；`NotificationDetails` 增加 `ohos:`；iOS 专属授权逻辑包 `if (!Platform.isOhos)` |
| `lib/screens/device_screen.dart` | 顶部 import `dart:io`；`Platform.isOhos` 时显示「蓝牙秤鸿蒙版待适配」提示并禁用扫描按钮 |
| `lib/screens/device_screen.dart` & `lib/services/scale_connector.dart` | 继续 import `flutter_reactive_ble`，但由本地 stub 占位（见下）|

---

## 五、三方库 OpenHarmony 适配情况

| 库 | 状态 | 处理方式 |
|----|------|---------|
| sqflite | ✅ 有 git 版 | `dependency_overrides` → `gitee.com/openharmony-sig/flutter_sqflite` |
| path_provider | ✅ 有 | override → `openharmony-tpc/flutter_packages` |
| shared_preferences | ✅ 有 | override → `openharmony-tpc/flutter_packages` |
| flutter_local_notifications | ✅ 有（17.2.4_ohos）| override → `openharmony-sig/fluttertpc_flutter_local_notifications` |
| **flutter_reactive_ble（蓝牙）** | ❌ **无社区适配** | 本地 stub 占位（`packages/flutter_reactive_ble_stub`），运行时 BLE 不可用，UI 降级 |
| fl_chart / table_calendar / intl / uuid / provider / cupertino_icons / path / timezone | 纯 Dart | 直接可用，无需覆盖 |

### 蓝牙（体脂秤）降级说明
`flutter_reactive_ble` 在 OpenHarmony 上**没有可用适配**（社区 issue 确认）。本工程用
`packages/flutter_reactive_ble_stub/` 提供最小 API 让工程可编译；运行时扫描无设备，
`device_screen` 在鸿蒙上显示橙色提示卡「鸿蒙版暂不支持扫描」，体重仍可在「体重」页
**手动录入**。待社区出现 ohos 适配后，把 `pubspec.yaml` 里 `flutter_reactive_ble` 的
override 换成真实适配库即可恢复自动读数。

### 通知说明
鸿蒙本地通知需**应用内主动申请授权**；APP 关闭状态下能否收到取决于系统通知策略与权限，
与 iOS 行为不同。首次进入「提醒」页点「开启通知」即可。

---

## 六、与 iOS 工程的关系

- `mi_workbench/`（iOS 版）与 `mi_workbench_harmony/`（鸿蒙版）是**两个独立目录 / 独立 git 仓库**，
  共享同一套 Dart 业务代码逻辑（从 iOS 工程拷贝而来）。
- iOS 工程不受影响，仍可正常侧载。
- 若后续 Dart 业务代码有改动，两边需同步（建议以 iOS 工程为源，重新拷贝 `lib/` 后
  再补一次本指南第四节的平台兼容改造）。

---

## 七、故障排查

1. `flutter doctor` 认不出鸿蒙工具链 → 检查 `DEVECO_SDK_HOME` 是否设置。
2. HAP 装不上 → 未签名，去 DevEco 勾「自动生成签名」。
3. `EPERM` 报错（Windows）→ 开启「开发者模式」或管理员运行。
4. 依赖报 `xxx doesn't support OpenHarmony` → 在 `pubspec.yaml` 的 `dependency_overrides`
   补该库的 git 适配版（参考 openharmony-tpc/flutter_packages 仓库）。
5. `OHOSNotificationDetails` 构造参数不符 → 以 `flutter_local_notifications` ohos 版
   的 `example` 为准微调 `notification_service.dart`。
