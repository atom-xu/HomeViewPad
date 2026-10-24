# HomePad 简单效果图

按用户 2026-10-17 的修订要求制作：只有效果画面，不加宣传大标题、功能文案、编号、品牌条或页脚。App 原生文字与演示标记保留。上一版图文排版留在相邻目录，未覆盖。

打开 `index.html` 查看全部；`overview.png` 为无外部文字的五图概览。正式图片在 `exports/`：

| 文件 | 内容 | 像素 | 性质 |
| --- | --- | --- | --- |
| 01-home.png | 摄影壁纸、摄像头示意画面、音乐卡片 | 1512 × 1040 | ImageGen 概念编辑 |
| 02-music.png | 摄影封面与播放中效果 | 1512 × 1040 | ImageGen 概念编辑 |
| 03-ambient.png | 摄影壁纸与时钟 | 1511 × 1041 | ImageGen 概念编辑 |
| 04-homeview-homepad.png | 上 Apple HomeView、下 HomePad | 1440 × 1920 | HTML/CSS 上下对照 |
| 05-albums.png | Cover Flow 选择专辑 | 1510 × 1042 | ImageGen 概念编辑 |

## 概念图与实测的区别

01、02、03、05 四张基于实际 App 模拟器截图，用内置 `image_gen.imagegen` 作实质图像编辑，**不是未经编辑的真实截图**。摄影壁纸、摄像头画面、虚构音乐封面/曲目与暂停按钮用来表达视觉效果，不证明设备连接、真实视频、账号资料或音频播放。Home 的「演示」、摄像头「演示·无实时画面」、音乐的「TEST DATA」、时钟的「DEMO / Demo time」保留。

图像没有改回 App，也没有运行新的 UI、音乐或硬件测试。`sources/` 仅是未改字节的原始截图参考副本；这些副本不能与四张生成成品混为一谈。原参考来自 iPad Pro 11-inch M5／iPadOS 26.5 的交互修复 03 和音乐导航 04 模拟器附件。

## 摄影输入与生成记录

`assets/wallpaper.jpg` 为 **Filip Zrnzević** 的真实摄影；`assets/camera-room.jpg` 为 **Kevin Lieder** 的真实摄影。两者均来自 Unsplash，作者、原始页面、下载地址、许可与 SHA-256 见 `assets/photo-sources.json`。它们不是 AI 原创摄影、用户的家庭照片或真实 HomeKit 摄像头采集。

四张 ImageGen 成品的提示词与生成原文件位置保存在 `assets/imagegen-prompts.json`、`assets/imagegen-additional-prompts.json` 与 `assets/imagegen-albums-prompt.json`。四张成品均从各自 ImageGen 原文件直接复制，未用 Python 或像素工具重绘、擦字或二次修图。

## Apple HomeView 对比

用户指定的产品是 **Apple HomeView**，不是开源 HomeViewPad 或同名第三方 App。对比图上方来自 [Apple HomeView 官网](https://www.apple.com/apple-homeview/)「The ultimate dashboard」中的 [官方图片](https://www.apple.com/v/apple-homeview/a/images/overview/highlights/dashboard__d7v1zkoeeiwm_large_2x.jpg)。Apple 官方原图保持原像素内容；版式只等比缩放并裁去外围空墙，黑色设备边框和完整 UI 保留，没有 AI 重绘、改壁纸、改设备或改数值。下载原文件和准确来源在 `assets/apple-homeview-dashboard-official.jpg` 与 `assets/apple-homeview-source.json`。

下方是 `01-home.png` 的 HomePad 概念效果图。二者分别为 **Apple 官方宣传图 / HomePad AI 概念图**，不能据此声称功能相同、官方关联、性能优劣，或两边均已真机实测。Apple 图片作为署名来源的比较参考，不宣称原创、MIT 或 AI 素材。对比源文件是 `comparison.html`，图中不叠产品标签或宣传说明。

## 验证与范围

五张正式图、无字概览与本地画廊均逐张实际查看；原参考截图、摄影输入与 Apple 原图散列可回溯。本轮只新增 `05-albums.png`，选专辑参考副本为 `sources/albums-original.png`；虚构专辑 First Light / HomePad Demo 与 TEST DATA 保留，不代表真实资料库或音频。前四张导出 PNG 的散列与上一版完全一致。

图像尺寸、无外部文字、资源加载、375 / 768 / 1500 px 画廊与来源检查见 `validation.json`，完整素材清单见 `manifest.json`。

本素材任务没有修改 App 源码、工程、测试或设备状态；仅同步素材交接与验证文档，没有提交、推送、上传或公开发布。未另写发布文案。原始检查留在 `.validation/local/xiaohongshu-simple-20261017/`。
