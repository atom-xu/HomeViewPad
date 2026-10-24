# HomePad 小红书素材

2026-10-17 · 展示图与文案，不修改 App 界面。

直接打开 `index.html` 查看整套。正式配图为 `exports/01-cover.png` 至 `exports/06-overview.png`，每张 1440 × 1920（3:4）。`overview.png` 仅用于快速选图，不建议作为小红书单张配图。

`发布文案.md` 含标题、正文及标签。`cards.html` 和 `style.css` 是可编辑排版源，`render.cjs` 用本机 Playwright Chromium 导出。不要删除图底部的演示／测试来源说明。

## 素材与验证

- `sources/` 中六张 App 截图与当前图标均逐字节复制来源。App 图像没有重绘、换封面、补设备、改数值、擦除演示标记或提亮处理；CSS 只进行完整等比缩放、设备边框与圆角呈现。原始 PNG 带 EXIF Orientation=8，浏览器按方向呈现为横屏。
- 来源是 2026-10-17 的 iPad Pro 11-inch M5／iPadOS 26.5 模拟器附件。家庭、照片、时钟、总览来自交互修复 03；播放器来自音乐导航 04；Cover Flow 来自 03 的音乐就绪复测。每图测试方法、非失败附件标记和 SHA-256 在 `manifest.json`。
- 照片墙与总览使用项目生成的原创渐变测试照片，没有导出用户家庭照片。音乐中的空白封面和 Synthetic／Validation 名称按原样保留，没有冒充真实账号资料或播放结果。
- `assets/lifestyle-background-ai.png` 是独立 ImageGen 原创场景，只用于封面；不是用户家、实体设备或安装效果实拍。工具与提示词记录于同目录 `lifestyle-background-source.json`。
- 六张导出都已实际查看。无文字越界、重叠或截断，截图方向及比例正确、原数据标记可见。图片尺寸、来源散列、资源加载和浏览页检查记录在 `validation.json`，原始检查在 `.validation/local/xiaohongshu-20261017/`。

本任务未修改 App 源码、工程或测试；没有重跑原生套件、操作实体 iPad、验收真实设备或音频、提交、推送、部署和公开发布。并行 App 开发与本素材任务分开记录，不以这些图片证明当前工作区全部代码已验收。

## 编辑与导出

安装 Node.js 和 Playwright 后，在此目录执行 `node render.cjs`。版式使用 macOS PingFang SC；其他系统的字体替代可能改变字形和换行，应重新检查导出图。浏览 `cards.html` 查看可编辑排版，`index.html` 用于看最终图。

## 项目来源

HomePad 是基于 [kuscholar/HomeViewPad](https://github.com/kuscholar/HomeViewPad) 的个人 fork，沿用原项目 MIT 许可。当前仓库为 [atom-xu/HomeViewPad](https://github.com/atom-xu/HomeViewPad)。图标为本项目原创建议稿中用户选定的「家窗」图案。App 保持原生 SwiftUI 与 Apple 系统权限边界；天气连接 Open-Meteo，其他功能按所需系统授权工作。
