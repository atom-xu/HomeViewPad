# HomePad · VILHIL app icon study

日期：2026-10-16。仅供本地设计审阅。

## 用户场景

在 iPad 主屏上快速找到 HomePad，同时清楚保留用户自己的 VILHIL 品牌识别；不把长字标缩小塞入图标。

## 范围

- 用已有正式 VILHIL 图案标制作三个材质／色彩方案；不改造图案、不新造简称。
- 每个方案交付可编辑 SVG、1024 px 不透明正方形 PNG、60 / 120 px 缩略图。
- 交付深浅桌面背景对比和离线可查看的设计预览。
- 保留现有 AppIcon、工程绑定、应用源码和其他既有工作；不提交、不推送、不发布、不安装到设备。

## 验收

- 视觉核对正式 VI 的独立图案、比例和主／辅色；以 SVG 原路径精确排版。
- 在 1024 / 120 / 60 px 检查留白、轮廓、节点、边缘和不透明度。
- 桌面预览加示意圆角遮罩；交付的图标 PNG 保持不透明全幅正方形，避免二次圆角。
- 对原 AppIcon PNG、Contents.json 及既有未提交文件做前后 SHA256 核对。
- 本轮没有应用行为或布局改动，不运行或声称通过 XCTest / XCUITest；不声称已做真机图标验收。

## 正式素材依据

- `/Users/atom/Desktop/vilhil/品牌/VilHil 视觉识别系统_8.16.pdf`：第 15 页图案及比例，第 19 页允许独立图案用于小尺寸识别，第 24 页黑白主色，第 25 页 LIGHT YELLOW RGB 254 / 235 / 143。
- `/Users/atom/Desktop/软件项目/entroWEB/public/vilhil-mark-vi-20261013.svg`：已有正式图案 SVG，viewBox `0 0 278.398 208.801`，三条原始路径。其配套 DESIGN_SYSTEM.md 第 120 行明确标注正式 VI 主标；本次已与 VI 页面视觉核对。
- `/Users/atom/Desktop/vilhil/品牌/VilHil.ai`：2025 年旧版 VilHil Studio 字标，已查看，未用于本次设计。
- 当前 AppIcon 为淡紫底房屋图案；README 的绿色房屋图案为另一套 HomePad 素材，均不等同于 VILHIL。

本次只复用用户指明的品牌矢量资产，不导入附近项目代码、服务、凭据或其他公司的标志。
