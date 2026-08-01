#!/usr/bin/env bash
# 米工作台 HarmonyOS 版一键构建脚本（Linux / macOS）
# 前置：已安装 OpenHarmony Flutter SDK 3.27.4-ohos + DevEco Studio + API12
set -e

echo "==> 1/5 生成 / 修正 ohos 平台壳（flutter_ohos.har 等）"
flutter create --platforms=ohos .

echo "==> 2/5 拉取依赖（含 OpenHarmony 适配版）"
flutter pub get

echo "==> 3/5 清理缓存"
flutter clean
flutter pub get

echo "==> 4/5 构建 HAP（release）"
flutter build hap --release

echo "==> 5/5 产物位置"
ls -la build/ohos/entry/default/outputs/default/*.hap 2>/dev/null \
  || echo "未找到签名 HAP，请先在 DevEco 配置自动签名后重试。"
echo "安装到设备：hdc install build/ohos/entry/default/outputs/default/entry-default-signed.hap"
