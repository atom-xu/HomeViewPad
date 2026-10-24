# HomePad 本地开发

本仓库是 `kuscholar/HomeViewPad` 的个人 fork。应用显示名为 HomePad，Xcode 工程、scheme 和源码目录仍叫 HomePad。项目统一描述为 homepad。项目使用 SwiftUI 和 Apple 系统框架，没有第三方包或自建后端。

## 开发入口

- [开发规则](AGENTS.md)
- [开发经验与迭代方式](docs/DEVELOPMENT.md)
- [本地初始化记录](docs/INITIALIZATION.md)
- [现有架构和数据生命周期](docs/ARCHITECTURE.md)
- [测试记录](docs/VALIDATION.md)
- [iPad 待机与专用面板参考](docs/IPAD-KIOSK-RESEARCH.md)
- [真机验收清单](docs/HARDWARE_CHECKLIST.md)

## 检查环境

需要 macOS、完整 Xcode、Python 3 和已安装的 iPad Simulator runtime。最低应用部署目标为 iPadOS 17。

```sh
xcode-select -p
xcodebuild -version
xcodebuild -showsdks
xcrun simctl list runtimes
xcrun simctl list devices available
xcodebuild -project HomePad.xcodeproj -scheme HomePad -showdestinations
```

必须在最后一条命令中看到可用 iPad 目标。仅有 SDK 列表或 `simctl` 的设备列表不能证明 Xcode 可以构建并运行。

若提示 `iOS 26.5 is not installed`，在 Xcode → Settings → Components 安装当前 Xcode 要求的 iOS 平台支持，也可使用下面的命令。版本取自本机提示，不应固定照搬其他电脑的版本。

```sh
xcodebuild -downloadPlatform iOS -buildVersion 26.5 -architectureVariant arm64
```

组件管理流程见 [Apple 官方文档](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components)。下载完成后重新检查 destinations。

## 使用本次创建的独立模拟器

本机 UUID 保存在忽略目录 `.validation/local/simulator-id`。初始化时只加入两张脚本生成的渐变照片，位置为模拟注入的 San Francisco。

```sh
mkdir -p .validation/local/tmp
homepad_simulator_id=$(cat .validation/local/simulator-id)
xcrun simctl list devices available
open HomePad.xcodeproj
```

在 Xcode 中选择 HomePad scheme 和 HomePad Development 模拟器运行。首屏为 Home，点击 Explore demo。演示模式不会创建真实 HomeKit 管理器。

其他电脑首次使用时，用 `xcrun simctl list devicetypes` 和 `xcrun simctl list runtimes` 选择已安装的 iPad 和 runtime，再创建独立模拟器；不要复用含个人照片的模拟器。以下命令中的两个标识应替换为本机列表里的实际值。

```sh
mkdir -p .validation/local/tmp
xcrun simctl create 'HomePad Development' \
  DEVICE_TYPE_IDENTIFIER RUNTIME_IDENTIFIER > .validation/local/simulator-id
homepad_simulator_id=$(cat .validation/local/simulator-id)
xcrun simctl boot "$homepad_simulator_id"
xcrun simctl bootstatus "$homepad_simulator_id" -b
python3 scripts/seed_test_photos.py "$homepad_simulator_id"
xcrun simctl location "$homepad_simulator_id" set 37.7749,-122.4194
```

合成照片只需加入一次，重复运行会产生重复照片。位置注入用于定位测试，不能视为真机 GPS 验证。

## 运行现有测试

在可用目标和测试照片准备好之后执行：

```sh
homepad_simulator_id=$(cat .validation/local/simulator-id)
TMPDIR="$PWD/.validation/local/tmp/" \
  sh scripts/test.sh "$homepad_simulator_id" > .validation/local/baseline-test.log 2>&1
```

这里为上游脚本指定项目内的临时目录，避免与其他 checkout 共用 `HomePadDerived`。构建缓存和结果包位于 `.validation/local/tmp/`，日志位于 `.validation/local/baseline-test.log`。UI 套件包含真实天气请求、系统权限弹窗和实际 30 秒照片轮播，需要网络与完整模拟器环境。

从日志取得实际 `.xcresult` 路径，再运行 `python3 scripts/export_screenshots.py RESULT_BUNDLE .validation/local/screenshots` 导出截图并逐张检查。上游历史测试通过情况不能代替本机结果。

## 真机和签名

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

填入自己的唯一 bundle identifier 和 development team。该文件被 Git 忽略；不要提交个人签名配置、证书、家庭标识或照片。真机安装和家庭设备操作按 [硬件清单](docs/HARDWARE_CHECKLIST.md) 单独验收。

## 工程和 Git

新增 Swift 文件后运行 `python3 scripts/generate_project.py`，再检查生成差异。生成器会覆盖工程、scheme、Info.plist 和 entitlements，个人配置留在 `Config/Local.xcconfig`。

```sh
git remote -v
git fetch upstream
git log --oneline HEAD..upstream/main
git diff --check
python3 scripts/commit_guard.py
```

上游规则限制实际提交时间：America/New_York 工作日 22:00 之后或周末。遵守真实时间，不改写时间戳；窗口外保留本地改动。远端推送、发布及设备操作遵循当次授权范围。
