<p align="center">
  <img src="media/homepad-icon.png" width="104" height="104" alt="HomePad 应用图标">
</p>
<h1 align="center">HomePad</h1>
<p align="center"><strong>把 iPad 变成家里的常用面板。</strong></p>
<p align="center">家庭控制 · 音乐 · 照片 · 时钟 · 航拍壁纸</p>
<p align="center">
  <a href="../README.md">English</a> · <a href="../SETUP.md">构建与运行</a> · <a href="ARCHITECTURE.md">架构与隐私</a> · <a href="VALIDATION.md">验证记录</a>
</p>

HomePad 把家庭操作和日常展示放到同一块 iPad 上：控制 Apple 家庭配件、翻阅音乐专辑、展示照片；空闲时，让时钟或缓缓移动的航拍风景接替操作界面。

HomePad 按独立项目持续开发，拥有自己的界面和产品方向。使用 **SwiftUI 与 Apple 公共框架**，支持 **iPadOS 17 及以上**，没有第三方包或自建后端。界面支持左右横屏、中英文切换、VoiceOver 和大字号。

<p align="center">
  <img src="media/homepad-home.png" width="880" alt="HomePad 家庭面板，包含大温控、时钟、配件操作、摄像头与音乐卡片；示例配件保留 DEMO 标记。">
  <br><sub>当前原生界面，来自 iPad 模拟器；配件为明确标记的演示数据。</sub>
</p>

## 一块日常用得上的家庭面板

**家庭控制** — 选择 Apple 家庭，排列支持的配件与快捷入口，确认后运行场景。点击配件图标切换电源，点击名称打开设备支持的参数。

**音乐** — 浏览 Apple Music 专辑、歌曲和歌单，用 Cover Flow 翻封面，播放整张专辑或歌单，查看队列，通过系统控件调音量与选择 AirPlay。Home 音乐卡与完整播放器共用播放状态，也支持本地音频文件。

**照片** — 手选最多24张照片，或选择相册、个人收藏。独立照片页支持单张全屏或照片墙，并保留自己的选择与轮播。

**壁纸** — 在 Mac 式缩略图库中选择照片、颜色或12段 Apple 官方航拍。选中视频后通过 Wi-Fi 下载，离线静音循环；可按1／5／15分钟随机轮换已下载片段。家庭页、时钟与时钟待机共用背景。

**时钟与待机** — 空闲时保留当前页面并调暗，或显示时钟、照片墙。首次触摸恢复操作；在设置中配置夜间外观、亮度与屏幕行为。

**天气与日程** — 手动选择天气城市或定位一次；主动连接日历并授权后，查看未来七天日程。

<table>
  <tr>
    <td width="50%"><img src="media/homepad-music.png" alt="HomePad 原生音乐浏览器，以 Cover Flow 展示明确标为测试数据的合成专辑。"></td>
    <td width="50%"><img src="media/homepad-wallpaper.png" alt="HomePad 壁纸图库，包含紧凑预览、照片入口与颜色缩略图。"></td>
  </tr>
  <tr>
    <td align="center">音乐浏览 · 合成测试数据</td>
    <td align="center">家庭、时钟与待机共用壁纸图库</td>
  </tr>
</table>

以上为原生实截，保留演示／测试标记。截图来源见[素材说明](MEDIA.md)。

## 构建并体验

当前版本以源码形式提供。需要 macOS、Xcode，以及匹配的 iPad 模拟器或自己的 iPad。

```sh
git clone https://github.com/atom-xu/HomeViewPad.git homepad
cd homepad
open HomePad.xcodeproj
```

选择 **HomePad** scheme 和 iPad 模拟器，运行后点击「体验演示」（Explore demo），不需要真实配件。也可使用 `--demo` 启动参数直接进入固定演示。

安装到自己的 iPad 时，将 `Config/Local.xcconfig.example` 复制为 `Config/Local.xcconfig`，填写自己的 Bundle ID 和开发团队，再用 Xcode 签名安装。之后按需在 HomePad 设置中连接功能：

- **Apple 家庭：**先在 Apple「家庭」App 配置家庭和配件，再授权 HomePad。
- **音乐：**为 App ID 启用 MusicKit，并授权用户音乐账号；曲库播放需要符合条件的 Apple Music 账号。
- **照片与日历：**通过系统选择器选择照片，或主动连接日历并授权。
- **壁纸：**进入「设置 → 显示与待机 → 壁纸」。航拍选中后下载，随机播放只使用已下载内容。

完整环境、模拟器、签名和测试步骤见 **[SETUP.md](../SETUP.md)**。

## 适合共享屏幕的使用方式

HomePad 无需应用账号，没有分析 SDK 或自建后端。家庭、照片、音乐、日历、相机和位置访问由系统权限控制。导入照片和已下载航拍保存在应用本地；天气请求使用 Open-Meteo，航拍下载使用 Apple 服务器。存储、网络请求与清理方式见[架构与隐私](ARCHITECTURE.md)。

待机在 HomePad 保持前台时运行，不能替代 iPadOS 锁屏或解锁已锁定的 iPad。可选的相机唤醒需要独立同意和兼容硬件。系统「减弱动态效果」会让航拍显示静帧并简化转场。专用面板的配置与边界见[常驻展示说明](IPAD-KIOSK-RESEARCH.md)。

项目持续开发中。[验证记录](VALIDATION.md)保留实际测试结果、已知失败和真机检查。模拟器通过、应用安装成功与真实配件、长期常驻体验分别验收。

## 开发 HomePad

- [开发与构建](../SETUP.md) — 本地构建、签名、运行和测试。
- [架构](ARCHITECTURE.md) — 组件、公共 API、数据存储与权限。
- [开发经验](DEVELOPMENT.md) — 项目约定及已验证的实现经验。
- [验证记录](VALIDATION.md) — 实际结果、已知问题与硬件边界。
- [开发交接](INITIALIZATION.md) — 当前分支与开发历史。

开发规则见 [AGENTS.md](../AGENTS.md)。个人签名配置和私有数据不提交到 Git。

## 许可证与致谢

HomePad 使用 [MIT 许可证](../LICENSE)。项目起源于 kuscholar 及贡献者开发的 [HomeViewPad](https://github.com/kuscholar/HomeViewPad)，保留原有版权与许可声明。源码及素材归属见[致谢](../CREDITS.md)。

Apple 服务、音乐封面与航拍素材保留其各自权利人的权利。HomePad 是独立项目，与 Apple 没有关联或背书关系。
