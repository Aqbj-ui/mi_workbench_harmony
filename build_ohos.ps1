# 米工作台 HarmonyOS 版一键构建脚本（Windows / PowerShell）
# 前置：已安装 OpenHarmony Flutter SDK 3.27.4-ohos + DevEco Studio + API12
# 用法：在 mi_workbench_harmony 目录下
#   powershell -ExecutionPolicy Bypass -File build_ohos.ps1
$ErrorActionPreference = 'Stop'

Write-Host "==> 1/5 生成 / 修正 ohos 平台壳（flutter_ohos.har 等）" -ForegroundColor Cyan
flutter create --platforms=ohos .

Write-Host "==> 2/5 拉取依赖（含 OpenHarmony 适配版）" -ForegroundColor Cyan
flutter pub get

Write-Host "==> 3/5 清理缓存" -ForegroundColor Cyan
flutter clean
flutter pub get

Write-Host "==> 4/5 构建 HAP（release）" -ForegroundColor Cyan
flutter build hap --release

Write-Host "==> 5/5 产物位置" -ForegroundColor Cyan
$hap = "build\ohos\entry\default\outputs\default\entry-default-signed.hap"
if (Test-Path $hap) {
  Write-Host "HAP 已生成：$hap" -ForegroundColor Green
  Write-Host "安装到设备：hdc install $hap" -ForegroundColor Yellow
} else {
  Write-Host "未找到签名 HAP，请先在 DevEco 配置自动签名后重试。" -ForegroundColor Red
}
