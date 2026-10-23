# HomePad 开发与构建

HomePad 是独立维护的原生 iPad 家庭面板，使用 SwiftUI 与 Apple 公共框架，无第三方包或自建后端。应用、工程、scheme 和源码目录统一使用 **HomePad**。源码沿革与许可归属见 [CREDITS.md](CREDITS.md)。

## 环境与首次运行

需要 macOS、完整 Xcode、Python3，以及与 Xcode 匹配的 iPad Simulator runtime。应用最低部署目标为 iPadOS17；当前具体测试工具链见 [VALIDATION](docs/VALIDATION.md)。

```sh
git clone https://github.com/atom-xu/HomeViewPad.git homepad
cd homepad
xcode-select -p
xcodebuild -version
xcrun simctl list runtimes
xcodebuild -project HomePad.xcodeproj -scheme HomePad -showdestinations
open HomePad.xcodeproj
```

在 Xcode 选择 **HomePad** scheme 和可用 iPad 模拟器运行，点击 **Explore demo**。也可在 Scheme → Run → Arguments 加入 `--demo`。演示家庭、时间和天气是固定样本，界面显示 DEMO，不创建 HMHomeManager，不连接真实家庭。

当前应用仅声明左右横屏。更换模拟器或升级 Xcode 后，以 `-showdestinations` 的实际可用目标为准；只看到 SDK 名称或设备列表，不代表平台组件已经完整安装。

如果提示缺少 iOS 平台，在 Xcode → Settings → Components 安装对应版本，或使用 `xcodebuild -downloadPlatform iOS -buildVersion VERSION -architectureVariant arm64`，将 VERSION 换成本机要求的版本。完成后重新检查 destinations。

## 准备独立测试模拟器

普通功能开发使用独立模拟器和合成照片。先查可用的设备类型与 runtime，再替换下面两个标识：

```sh
xcrun simctl list devicetypes
xcrun simctl list runtimes
mkdir -p .validation/local
xcrun simctl create 'HomePad Development'   DEVICE_TYPE_IDENTIFIER RUNTIME_IDENTIFIER > .validation/local/simulator-id
homepad_simulator_id=$(cat .validation/local/simulator-id)
xcrun simctl boot "$homepad_simulator_id"
xcrun simctl bootstatus "$homepad_simulator_id" -b
python3 scripts/seed_test_photos.py "$homepad_simulator_id"
xcrun simctl location "$homepad_simulator_id" set 37.7749,-122.4194
```

合成照片只加入一次；重复执行会增加重复照片。模拟器位置注入只用于测试，不是设备定位验收。`.validation/` 被 Git 忽略，用于本地日志、截图、结果包和快照。

## 运行测试与检查截图

```sh
homepad_simulator_id=$(cat .validation/local/simulator-id)
homepad_test_root=$(mktemp -d /private/tmp/homepad-tests.XXXXXX)
TMPDIR="$homepad_test_root/" sh scripts/test.sh "$homepad_simulator_id"
```

脚本运行 HomePad scheme 的 XCTest／XCUITest，使用未签名模拟器构建，并在日志打印 `.xcresult` 路径。每次使用独立临时目录，避免复用其他开发任务的测试缓存。

UI 套件涉及系统照片选择器、权限弹窗、实际照片轮播和网络集成。准备合成照片与可用网络；部分方法会请求 Open-Meteo 或下载 Apple 官方航拍。可控的音乐／航拍测试数据有独立启动参数和明显标记，不代表真实账号播放或硬件结果。

导出并检查原生截图：

```sh
python3 scripts/export_screenshots.py RESULT_BUNDLE .validation/local/screenshots
```

将 RESULT_BUNDLE 换成实际结果包路径。记录设备、运行时、命令、通过、失败和未测项；不为变绿而放宽断言。当前完整记录见 [VALIDATION](docs/VALIDATION.md)。

## 安装到自己的 iPad

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

在 Local.xcconfig 中填写自己的唯一 Bundle ID 与 development team。完成 Xcode 账号、设备配对、信任和 Developer Mode 设置，再选择 iPad 运行。Local.xcconfig、签名证书及 provisioning profile 不提交到 Git。

按需启用对应能力和权限：

- **HomeKit：**先在 Apple「家庭」App 配置家庭与配件，再在 HomePad 主动连接家庭。
- **MusicKit：**在开发者 App ID 配置 MusicKit，并由用户授权音乐账号。曲库播放取决于账号资格及内容可用性；文件播放使用系统文件选择器。
- **照片：**手选图片使用系统 PhotosPicker；相册／个人收藏模式按需申请照片库访问。
- **日历：**主动连接后申请系统权限，读取未来七天日程。
- **航拍壁纸：**在「显示与待机 → 壁纸」选中片段并通过 Wi-Fi 下载，不需要将视频放进工程。

应用安装、画面显示、音频播放、真实家庭写入、AirPlay、摄像头和长期待机分别验证。真机清单见 [HARDWARE_CHECKLIST](docs/HARDWARE_CHECKLIST.md)。

## 项目结构与生成器

| 路径 | 作用 |
| :--- | :--- |
| `HomePad/` | SwiftUI 界面、原生服务、资源和本地化。 |
| `HomePadTests/` | XCTest 单元测试。 |
| `HomePadUITests/` | XCUITest 界面与集成流程。 |
| `scripts/` | 工程生成、测试、合成照片和截图导出。 |
| `docs/` | 架构、验证、开发经验与素材来源。 |
| `Config/` | 共享签名默认值与个人配置示例。 |

新增 Swift 文件后运行 `python3 scripts/generate_project.py`。它会重写工程、scheme、Info.plist 和 entitlements，重生成前后应核对并保留既有设置。个人值放在被忽略的 Local.xcconfig。

## 开发与 Git

从 [AGENTS.md](AGENTS.md)、[开发经验](docs/DEVELOPMENT.md)、[当前交接](docs/INITIALIZATION.md)和[架构](docs/ARCHITECTURE.md)开始。每次先明确用户场景、范围与验收，再做最小可验证修改。设备控制经 HomeStore，成功反馈以写入和回读为准。

`origin` 是 HomePad 的发布仓库 `atom-xu/HomeViewPad`；`main` 为项目首页与默认获取入口。`upstream` 保留对 `kuscholar/HomeViewPad` 的源码沿革引用。上游同步按需要单独进行，使用 fetch 与普通合并／变基，保留已有工作与历史。

常规实际 Git 提交限定为 America/New_York 工作日22:00后或周末，执行前运行 `python3 scripts/commit_guard.py`；不得伪造或回填时间。推送、发布和设备安装遵循当次授权范围与目标。任何用户明确给出的单次例外只适用于对应任务，不修改后续规则。

项目来源和许可见 [CREDITS](CREDITS.md)；MIT 版权声明保留在 [LICENSE](LICENSE)。
