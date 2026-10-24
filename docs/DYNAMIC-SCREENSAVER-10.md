# 动态背景与屏保 10

## 场景与范围

HomePad 作为常驻 iPad 面板时，用户希望像 macOS 壁纸设置一样浏览背景，选定一款或随机轮换；Home、Clock 和时钟待机延续同一背景。保留照片、原有颜色、音乐封面临时覆盖和独立照片页。

用户已明确本轮三项范围：

1. 把现有“家庭控制与时钟背景照片”和“默认背景”合并成一个背景选择区。
2. 增加“航拍”背景，允许指定一段或随机轮换，应用于 Home、Clock 和时钟待机。
3. 航拍直接采用 Apple 官方 Aerial 原片，不以原创动画、第三方航拍或用户导入视频替代。

## 接入设计

- 设置页保留一个“背景”入口，内部为照片、颜色、Apple 航拍三个类别，共享当前选中状态和预览；不再把照片与默认背景分散成两套选择。
- 沿用 WallpaperStore 的照片导入与保存。新增背景来源状态及 AerialStore，由 Dashboard 持有，Home、Clock、时钟待机共用一个背景渲染层；去除待机时钟的无条件纯黑覆盖。
- 使用 AVQueuePlayer／AVPlayerLooper 静音循环官方视频、AVPlayerLayer 铺满；不修改音乐音频会话或 AirPlay。随机轮换在可用片段之间避免连续重复，演示使用固定顺序。
- 航拍由 Apple 官方 HTTPS 地址按需获取，下载和缓存放在应用沙盒，不将视频文件打包进仓库。下载必须可取消，成功后再切换；失败保留之前可用的背景，不能把未下载或黑屏算作完成。离线使用已缓存片段。
- 选择照片或颜色退出航拍模式，旧照片／颜色用户在明确选择航拍前保持既有显示。音乐播放时的封面临时覆盖沿用原规则。
- “减少动态效果”用视频静帧；后台、隐藏或被其他页面遮住时停止播放并释放解码资源。夜间沿用亮度／遮罩，首次触摸仅唤醒。

## 已核实的来源与边界（2026-10-23）

- Apple 官方清单 `https://sylvan.apple.com/Aerials/2x/entries.json` 本次实际请求成功，6780 字节、13 个片段。条目含稳定 ID、地点及 1080p／4K、SDR／HDR 的官方视频地址。原始响应只保存在忽略目录 `.validation/local/dynamic-screensaver-10/apple-entries.json`。这只证明清单可读，尚未验证每段视频下载、播放和现代目录的完整性。
- 实际实现选用 Apple [tvOS 16 目录](https://sylvan.apple.com/Aerials/resources-16.tar)中的 1080p SDR HEVC 视频，并按稳定 ID 匹配 Apple [macOS 14 目录](https://sylvan.apple.com/itunes-assets/Aerials126/v4/82/2e/34/822e344c-f5d2-878c-3d56-508d5b09ed61/resources-14-0.tar)的官方预览图。两个目录实际响应分别含 114 和 26 个片段；首批选入夏威夷、巴塔哥尼亚、大峡谷、优胜美地、格陵兰、冰岛、迪拜、纽约、伦敦、香港、加勒比海与非洲／中东，共 12 段，全部视频 HEAD 检查成功。元数据写入 AerialCatalog.swift，原始目录仅保存在忽略目录，不声称是最新完整 Apple 目录。
- 单段视频约 124–412 MB。应用仅在用户选中时下载，单文件上限 750 MiB，总视频存储上限 1,500 MiB；长按已下载卡片可移除。视频与生成的静帧在 Application Support/AppleAerials，排除设备备份。随机按 1／5／15 分钟轮换已下载内容；无前台可见背景时不计轮换。
- Apple 的 [AVPlayerLooper](https://developer.apple.com/documentation/avfoundation/avplayerlooper) 是公开循环播放 API；本项目不调用系统私有屏保框架。
- 官方文件可访问不等同于已经获得再分发授权。Apple [版权许可说明](https://www.apple.com/legal/contact/)提供 Rights & Permissions 联系入口；本次未发现针对第三方 iPad App 的 Aerial 开放再分发许可。实现与个人本地验证、公开发布分别记录，不将官方来源误写成开放许可。

## 当前进度

已在 `codex/dynamic-screensaver` 实现上述图库、缓存、播放器与待机接入，保留从 `codex/ipad-display-01` 带来的全部未提交工作。新增 10 项航拍单元与 4 项 UI 用例；修复候选的 10 项单元、中文最大字号及 Apple 官方夏威夷实际下载／播放用例已通过。截图发现待机时原设置页透出，最终候选隐藏时钟待机底下的页面内容，保留“当前页面调暗”模式；完整 scheme 回归正在执行，最终结果以 VALIDATION 为准。

初始相关文件备份在 `.validation/local/dynamic-screensaver-10/baseline/`，结果包、日志、源码散列和原始截图在同一版本目录。本次没有 Git 提交、推送、发布或真机安装。

## 验收

- 独立 iPad Simulator，合成照片；下载／取消／失败使用可控网络客户端，实际 Apple 片源另做连接与播放验证；不连接真实家庭。
- XCTest 覆盖保存恢复、随机不连续重复、演示确定性、下载校验／取消／替换、缓存、后台与减少动态效果策略。
- XCUITest 覆盖图库选择、随机间隔、跨 Home／Clock／待机一致、重启恢复、静态背景切回及中文大字号。
- 运行 HomePad scheme 完整 XCTest／XCUITest，记录具体运行时、失败与未测项；导出并查看截图。
- 当前 App 只声明横屏；检查两侧横屏，尝试竖屏并记录实际方向限制，不能把未生效的竖屏旋转称作竖屏验收。
- 真机视频解码、长时间功耗／温升、夜间实际亮度另行验收。本轮不安装真机、不推送、不发布。
