# HomePad · VILHIL 图标设计

2026-10-16。本地设计审阅包，未接入应用。

直接打开 [index.html](index.html) 查看完整离线预览。静态总览位于 [previews/overview.png](previews/overview.png)，[深浅背景与 60 / 120 px 对比](previews/backgrounds-120-60.png) 可按 100% 大小检查。

## 三个方案

| 方案 | 设计 | 可用原稿 |
| --- | --- | --- |
| **A · 深石墨（推荐）** | 轻微石墨光感、白色主标。轮廓直接，深浅桌面稳定，适合常亮面板。 | [1024 PNG](01-graphite/icon-1024.png) · [可编辑 SVG](01-graphite/icon.svg) |
| B · 瓷白 | 柔和瓷白与深色主标，最贴近正式品牌黑白。 | [1024 PNG](02-porcelain/icon-1024.png) · [可编辑 SVG](02-porcelain/icon.svg) |
| C · 晨光 | VI 的 LIGHT YELLOW 浅黄基色，以轻微光照营造家的温度。 | [1024 PNG](03-daylight/icon-1024.png) · [可编辑 SVG](03-daylight/icon.svg) |

每个目录另有 `icon-120.png` 和 `icon-60.png`，由 SVG 在目标尺寸直接渲染。所有 PNG 是全幅不透明正方形；预览圆角只用于模拟桌面效果，不写入原稿。A/B/C 是同一正式图案的三个设计方案，并非已接入 iPadOS 的默认／深色／色调外观。

## 品牌来源与排版

正式 VI 已视觉核对第 15、19、24、25 页，确认独立图案、使用范围及黑白／浅黄配色。已有正式 SVG 与 VI 一致，复制保存在 [source/vilhil-mark-original.svg](source/vilhil-mark-original.svg)。准确原始来源、文件散列、三个路径和等比变换记录在 [manifest.json](manifest.json)；完整范围见 [BRIEF.md](BRIEF.md)。

三条品牌路径完全保留，不加字标、不拉伸、不裁剪、不改造节点或斜率。主体在 1024 px 画布上宽 600、高约 450；左右各留 212 px、顶部 266 px、底部约 308 px，略向上作视觉平衡。微渐变和轻微投影只改变材质呈现。

2025 年旧 `VilHil.ai` 是较早的 VilHil Studio 字标，未用于本次。当前紫色房屋 AppIcon 与 README 的绿色房屋素材也未用于新标识；它们不是 VILHIL 正式图案。本包不包含 Ronsys 或其他项目的代码、凭据及服务。

## 验证与重建

已查看三种 1024 px 原稿、完整总览和深浅背景的 120 / 60 px 预览；比例、留白、轮廓、中心节点、渐变与边缘无裁切或意外透明。自动检查三份 SVG 的品牌路径与等比变换、九张 PNG 的准确尺寸及全不透明度；六项小尺寸检查确认中心节点完整且与左右斜面分离，三处内部采样均有足够明暗差。结果见 [validation.json](validation.json)，文件散列见 [sha256.json](sha256.json)。

本次环境：macOS 27.0（26A428）/ arm64，Node 22.22.3、Playwright Chromium 135.0.7049.17、1× 像素比。Python／Pillow 的实际版本见 validation.json。渲染器最初因沙盒 Mach port 限制启动失败，经批准使用隔离本地渲染后成功，未更改系统安全设置。

首次自定义检查曾误设“斜面必为一个连通区域”：正式原路径只在一个零面积顶点接触，60 px 抗锯齿后阈值分区会拆成左右两块。现以原路径不变、三处几何采样、中心节点独立及边界误差不超过 1 px 为准，并接受该零面积接触对应的 2 或 3 个栅格分区；未为检查改变图案或填平品牌负空间。

```sh
python3 design/app-icon/2026-10-vilhil/generate.py
node design/app-icon/2026-10-vilhil/render.mjs
python3 design/app-icon/2026-10-vilhil/validate.py
```

`generate.py` 优先读取原始正式 SVG；原文件不在时可使用包内 source 副本。渲染需要已安装的 Playwright / Chromium，检查需要 Pillow。预览完全离线，不依赖网络字体或外部图片。

本轮未改变应用行为或界面布局，因此未运行 XCTest／XCUITest，也未将这些设计检查声称为应用测试通过。现有 AppIcon PNG、Contents.json、工程及应用源码保持不变。未安装到模拟器或实体 iPad，系统最终遮罩、色调／透明外观和真机色彩须在用户选定并授权接入后单独验证。未提交、推送、发布或部署。
