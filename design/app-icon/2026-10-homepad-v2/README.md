# HomePad · 第二轮图标设计

2026-10-16。根据用户“允许变形，更像个人智能家居 app，避免公司产品感”的新反馈重新设计。本轮解除第一轮“正式路径完全不变”的限制，三个新符号均标明为 **HomePad 原创变形**，不作为正式 VILHIL 企业 Logo。

打开 [完整离线预览](index.html)，或直接查看 [三方案总览](previews/overview.png)、[深浅背景 120 / 60 px 对比](previews/backgrounds-120-60.png)、[原标演变说明](previews/evolution.png)。

| 方案 | 结构方向 | 交付 |
| --- | --- | --- |
| A · 小憩 / Nook | 连续弯折的开放空间，小灯移到入口，打破原标对称中轴。 | [1024 PNG](01-nook/icon-1024.png) · [SVG](01-nook/icon.svg) |
| B · 相连 / Gather | 两条弧线连接三个不等角色的圆润节点，表达聚合。 | [1024 PNG](02-gather/icon-1024.png) · [SVG](02-gather/icon.svg) |
| **C · 家窗 / Dwell（推荐）** | 三块不等尺寸的窗格拼成房屋，缝隙成为负空间。 | [1024 PNG](03-dwell/icon-1024.png) · [SVG](03-dwell/icon.svg) |

推荐 C 继续深化：家与面板是同一个轮廓，贴近 HomePad 的内容，而不会直接被认作公司原标。总览内的同色轮廓明确展示三种结构差异，图标并非配色变体。每个目录还含 120 / 60 px PNG 与可编辑的 `symbol-monochrome.svg`。

## 参考与演变

已用浏览器实际查看 [Apple Home 官方 app 页面](https://apps.apple.com/us/app/home/id1110145103) 的层叠房屋，以及 [Samsung SmartThings 官方 app 页面](https://apps.apple.com/us/app/smartthings/id1222822904) 的五向连接图标。只借鉴“家／空间”和“连接／聚合”的概念；不复制其烟囱、层叠房屋、五向放射、空心圆组或官方配色。参考边界另见 [Apple HomeKit 视觉指南](https://developer.apple.com/design/human-interface-guidelines/homekit)。

VILHIL 原图来源沿用第一轮已核对的正式 VI / SVG，单独保留于 [source/vilhil-original.svg](source/vilhil-original.svg)。新符号只保留斜面、负空间、核心节点的概念，所有轮廓与结构重新绘制。每个方向怎样从原标演变，见 [evolution.png](previews/evolution.png)、[manifest.json](manifest.json) 和 [BRIEF.md](BRIEF.md)。本包不含 Apple / Samsung 的图标文件，也不导入其他项目代码或服务。

## 验证

已查看三个 1024 px 原稿、总览、演变图和深浅背景的实际 120 / 60 px 预览。自动检查三种同色结构各不相同、九张 PNG 准确尺寸／全不透明、六项小尺寸形体关系：A 的小灯独立，B 的连接完整，C 的三片窗格互相分开且不碰画布边界。结果见 [validation.json](validation.json)，渲染环境见 [previews/render-environment.json](previews/render-environment.json)。

环境：macOS 27.0 / arm64，Node 22.22.3、Playwright Chromium 135.0.7049.17、1× 像素比；Python 3.13.12 / Pillow 12.1.0。SVG 在目标像素尺寸直接渲染；1024 / 120 / 60 PNG 均为全幅不透明正方形。圆角仅用于桌面示意，未预裁进原稿。渐变为轻微材质，不承担轮廓识别。

```sh
python3 design/app-icon/2026-10-homepad-v2/generate.py
node design/app-icon/2026-10-homepad-v2/render.mjs
python3 design/app-icon/2026-10-homepad-v2/validate.py
```

原 AppIcon、工程和应用功能未变；第一轮设计保留。本轮无应用行为或界面布局改动，未运行 XCTest / XCUITest，未声称做过模拟器或真机图标验收。系统最终遮罩、色调／透明等特殊外观与实体显示色彩未测。未安装、提交、推送、发布或部署。
