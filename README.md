# 米工作台 (Mi Workbench) - iOS App

个人生活管理 iOS App：待办 / 记账 / 运动 / 体重 / 习惯 五合一 + 首页今日概览仪表盘，绿色主题 + 侧边栏（参照设计稿）。

> 2026-07-29 已根据市面同类 App（滴答清单、鲨鱼记账/一木、Keep、薄荷健康、小日常）调研，补全一批高价值功能。

## 功能清单

| 模块 | 功能 | 来源/对标 |
|---|---|---|
| 首页概览 | 一屏聚合：待办完成率、本月支出+预算剩余、连续运动天数、最新体重+距目标、今日习惯 | 米工作台/All-in-one 工作台理念 |
| 待办 | 勾选、拖拽排序、紧急/重要/普通、**截止日期（逾期高亮）**、**标签筛选**、**重复任务（日/周/月自动生成下一次）** | 滴答清单（截止日期/标签/重复） |
| 记账 | 自然语言输入自动分类、周/月汇总、**月度预算 + 一木式超支预警（按当前速度预测月底超支）**、**支出趋势柱状图** | 鲨鱼记账/一木记账（预算+趋势） |
| 运动 | 日历打卡、记录项目与时长、**连续打卡天数**、**周目标进度** | Keep/小米运动（streak/目标） |
| 体重 | 输入自动记录、曲线图、**目标体重 + 距目标进度**、**BMI 计算**、**体脂率** | 薄荷健康（目标/BMI/体脂） |
| 习惯 | **今日勾选打卡 + 连续天数 + 按周几重复 + 日历高亮** | 小日常（习惯养成） |
| 工作台 | 增加/删除自定义分类模块 | 设计稿：侧边栏底部"增加工作""删除工作"按钮 |

## 技术栈

- **Flutter 3.24+** / Dart（跨平台，Windows 上也能写完整代码）
- **SQLite** 本地存储（sqflite），离线可用
- **Provider** 状态管理
- **fl_chart** 体重曲线 + 记账饼图
- **table_calendar** 运动打卡日历
- **本地 NLP 关键词匹配** 记账自动分类（完全离线，不依赖任何 API）

## 目录结构

```
mi_workbench/
├── lib/                            # 全部 Dart 源码（已写完）
│   ├── main.dart                   # 入口
│   ├── theme.dart                  # 绿色主题
│   ├── models/                     # 6 个数据模型
│   │   ├── todo.dart               # +截止日期/标签/重复
│   │   ├── transaction.dart
│   │   ├── exercise_record.dart
│   │   ├── weight_record.dart      # +体脂率
│   │   ├── workbench_category.dart
│   │   └── habit.dart              # 习惯 + 打卡记录
│   ├── services/                   # 数据 + NLP + 设置
│   │   ├── db_service.dart         # +习惯表/迁移 v2
│   │   ├── nlp_service.dart
│   │   └── settings_service.dart   # 预算/目标/身高等本地设置
│   ├── screens/                    # 7 个页面
│   │   ├── home_screen.dart        # 侧边栏 + 主区域
│   │   ├── dashboard_screen.dart   # 今日概览仪表盘（默认首页）
│   │   ├── todo_screen.dart
│   │   ├── bookkeeping_screen.dart
│   │   ├── exercise_screen.dart
│   │   ├── weight_screen.dart
│   │   └── habit_screen.dart
│   └── widgets/
│       └── sidebar.dart
├── tools/
│   └── ExportOptions.plist         # iOS 打包签名选项
├── codemagic.yaml                  # 云端打包配置（Codemagic 读这个）
├── analysis_options.yaml
├── pubspec.yaml
├── .gitignore
└── README.md
```

> ⚠️ **没有 `ios/` 文件夹**：本机是 Windows 且没装 Flutter，Xcode 工程（几千行 XML）由 Codemagic 云端第一次构建时自动通过 `flutter create .` 生成，不用手动管。

## 从代码到 iPhone 安装：完整流程（无 Mac）

> 📌 **本地仓库已就绪**：本机已 `git init` + 全部提交（25 个文件）。你只需在 GitHub 建一个空仓库，加 remote 推上去即可。

### 第 1 步：推到 GitHub

```bash
cd D:/电商知识库/mi_workbench
git branch -M main
# 在 github.com 新建一个空仓库（不要勾选 README/.gitignore），拿到地址后：
git remote add origin https://github.com/你的用户名/mi_workbench.git
git push -u origin main
```

> 两种推法：① 你自己按上面命令推；② 把 **GitHub Personal Access Token（勾 repo 权限）** 发我，我直接建仓库 + 推。Token 用完可随时在 GitHub 撤销。

### 关于"签名 / Apple 账号"（重要澄清）

- **打包阶段不需要 Apple 账号**：`codemagic.yaml` 用 `--no-codesign` 产出**未签名 ipa**，Codemagic 全程不碰你的 Apple ID。
- **签名发生在你装 App 时**：用 AltStore 侧载 ipa 时，你电脑上的 AltServer 会用**你的 Apple ID（免费个人号即可）自动签名**再装进 iPhone。这是苹果"免费侧载"的唯一机制，无法再省——但它发生在**安装**环节，不在**打包**环节，所以你打包时完全不用管账号。
- **软件里要不要登录账号**：米工作台目前**没有任何强制登录**，数据全存本地 SQLite。如果以后想做云同步/多设备共享，那是一个可选的 App 内功能，到时你自己选开不开，和打包签名是两码事。
- 唯一需要 $99 + 绑 Apple 账号的情况：你想把 App **上架 App Store**（和"自己装来用"无关）。

### 第 2 步：Codemagic 云端打包（无需 Mac，无需 Apple 账号）

1. 打开 https://codemagic.io，用 **GitHub 账号登录**
2. 点 "Add application" → 选 GitHub → 选 `mi_workbench` 仓库
3. Codemagic 自动识别 `codemagic.yaml` 里的 `ios-release` workflow
4. 点 **Start new build**（无需 Apple 账号，直接构建）
5. 等 5-10 分钟，**Artifacts** 区域生成 `app.ipa`（未签名），下载到本地

> 整个过程在 Codemagic 的云端 Mac 完成，本机 Windows 不需要任何苹果工具。

### 第 3 步：用 AltStore 把 ipa 装到 iPhone（免费、零开发者账号）

**一次性配置**（每台电脑 + 每台 iPhone 组合只需配一次）：
1. iPhone 用数据线连电脑
2. iPhone 上安装 **AltStore**（App Store 搜索下载，免费的）
3. 电脑上安装 **AltServer for Windows**：https://altstore.io/
4. 打开 AltServer，系统托盘里点它 → Install AltStore → 选你的 iPhone
5. 输入 Apple ID 和密码（用自己的就行，仅用于签名，免费 7 天，到期可续）

**每次装新版本**：
1. AltServer 里点你的 iPhone → **Sideload .ipa**
2. 选下载好的 `app.ipa`
3. 等待 30 秒，iPhone 上会出现"米工作台"图标

**续期**：每 7 天在 AltServer 里点 Refresh，掉签前续上就行。

### 备用方案（如果有 Mac）

如果以后买了 Mac，本机直接：
```bash
flutter pub get
cd ios && pod install && cd ..
flutter build ios --release
# Xcode 里打开 ios/Runner.xcworkspace，选真机或模拟器，点 Run
```

## 本机调试（不需要 iPhone 也能看效果）

如果你本机装了 Flutter（任意平台都行），可以直接在浏览器看 UI：

```bash
cd D:/电商知识库/mi_workbench
# 第一次需要先生成平台文件夹（含 ios/ android/ web/）
flutter create --platforms=ios,android,web --org com.miworkbench --project-name mi_workbench .
flutter pub get
flutter run -d chrome
```

会打开 Chrome 跑起来，左侧绿色侧边栏 + 右侧各功能模块。所有数据存本地 SQLite，重启数据还在。

## 数据库

7 张表，全部本地 SQLite（DB 版本 2，首次启动自动建表；老版本自动迁移）：

- `todos` - 待办（含 `due_at` 截止时间 / `tags` 标签 / `repeat` 重复）
- `transactions` - 记账流水
- `exercises` - 运动记录
- `weights` - 体重记录（含 `body_fat` 体脂率）
- `categories` - 侧边栏自定义分类
- `habits` - 习惯定义
- `habit_checks` - 习惯打卡记录（按 `habit_id + checked_date` 唯一）

预算、运动周目标、体重目标、身高等**设置项**存在 `shared_preferences`，不进 SQLite。

数据库文件存在 iPhone 应用的 `Documents/` 目录，iCloud 备份会带上。

## 风险提示 & 避雷清单

⚠️ **本方案在生产环境的注意事项**：

1. **AltStore 7 天掉签**：免费方案每 7 天要续期一次，否则 App 图标变灰打不开。商用请走 TestFlight（需 $99/年苹果开发者账号）。
2. **本机还没跑过 `flutter analyze` / 真机**：本机是 Windows 且未安装 Flutter，代码经人工逐文件自检（已修 2 处真机隐患：习惯日历禁用态、仪表盘中文 locale 初始化），但**尚未编译验证**。建议推到 Codemagic 后看构建日志，或本机 `flutter analyze` 过一遍。iPhone 实机可能有细节差异。
3. **NLP 分类精度有限**：当前用本地关键词匹配覆盖常见场景（水果/餐饮/交通/购物/娱乐/生活/医疗）。老板可以自由在 `lib/services/nlp_service.dart` 的 `_rules` 里增删关键词，越用越准。
4. **没有云同步**：所有数据在本地 SQLite，换手机/重装会丢。后续可接 iCloud Drive 或自建后端。
5. **没有账号体系**：单机版，不支持多设备共享。后面要加账号的话改 Provider + 加一层 REST API 即可。

## 后续可加的功能（按优先级）

1. **数据导出 CSV**（记账导出到 Excel 做财务分析）— 目前未做
2. **iCloud 同步**（换手机不丢数据）— 目前未做
3. **更智能的 NLP**（接云端 LLM 做语义分类，比如"和同事吃了顿海底捞，人均 150"自动按人均 × 人数算）— 目前是本地关键词
4. **小组件**（iPhone 主屏显示今天完成率、记账总额）— 目前未做
5. **Apple Watch 端**（运动实时记录）— 目前未做

> 已落地（2026-07-29 调研后补全）：首页今日概览、记账预算+趋势图、运动连续打卡+周目标、体重目标+BMI+体脂、待办截止日期/标签/重复、习惯打卡模块。

## 维护

代码改动后：
```bash
git add . && git commit -m "..." && git push
```
Codemagic 会自动重新构建。AltServer 里 `Refresh` 一下就装上新版本。

---

**项目位置（按老板要求全部在 D 盘，不碰 C:）：**
`D:\电商知识库\mi_workbench\`
