# HomePad 常驻展示与待机参考

查阅日期：2026-10-16，Asia/Shanghai。以下是官方资料核对与产品建议，不是本机或真机验收结果。

## 可以落实的“接管”

建议将 HomePad 定义为：**应用在前台运行时承担家庭控制与待机展示，用户可自行开启系统“引导式访问”将 iPad 固定在本应用。** 应用维护自己的空闲、时钟、夜间和感知状态；系统锁定、解锁、退出限制和设备管理仍由 iPadOS 控制。

| 已核对的事实 | 来源与对本项目的影响 |
| --- | --- |
| 引导式访问可暂时将 iPad 限制在一个应用，并配置屏幕自动锁定时间。 | [Apple：将 iPad 锁定在一个 App](https://support.apple.com/en-ie/guide/ipad/ipada16d1374/ipados)。适合用户自用的第一版常驻面板；由用户在系统中开启。 |
| 应用调用 `requestGuidedAccessSession` 进入单 App 模式，要求设备经 MDM 监管且该应用获准。 | [Apple API 文档](https://developer.apple.com/documentation/uikit/uiaccessibility/requestguidedaccesssession(enabled:completionhandler:))。不能给普通个人 iPad 做一个保证成功的“一键系统接管”按钮。 |
| Configurator 的 Single App Mode 可强制打开选定应用，并在设备重启后重新打开；前提是受监管设备。 | [Apple：配置单 App 模式](https://support.apple.com/guide/apple-configurator-mac/set-single-app-mode-cadbf9c172/mac)。这是独立的专用设备部署方案，本轮不修改个人 iPad 的监管状态。 |
| Apple 的 StandBy 文档描述的是充电横置时的 iPhone 展示体验。 | [Apple：Use StandBy](https://support.apple.com/en-ie/guide/iphone/iph878d77632/ios)。可借鉴远距时钟和夜间红色，但不能把该 iPhone 功能当作 iPad 可接管的系统接口。 |

## 同类设计

**Home Assistant 官方 iOS Kiosk 模式**提供常亮、隐藏界面栏、配置入口、空闲后 Clock / Dim / Blank 三种屏保、预览与触摸恢复。相机检测只在前台工作，开启时系统显示相机指示；远程 kiosk 指令也要求应用已在前台。其文档同样推荐通过系统引导式访问限制退出。[官方文档](https://companion.home-assistant.io/docs/integrations/ios-kiosk-mode/)

**Wallflower**把长期展示与临时操作区分开：显示当前相关设备和固定项目，接近时恢复操作控件，提供自定义面板、夜间变暗与设置保护。官方声明注意力检测采用相机元数据、主动选择开启、不保存或发送图像。[产品官网](https://nxtbgthng.com/wallflower/)

**HomeDash**支持可配置的 HomeKit / Matter 仪表盘、场景组织和 iPad 布局；其更新说明还列出用系统生物识别保护仪表盘配置。可借鉴“大屏布局可编辑”及“家庭成员能用、配置需保护”这两点。[App Store 开发者说明](https://apps.apple.com/us/app/homedash/id1003033186?platform=ipad)

Wallflower FAQ 另记载了“引导式访问＋允许自动锁定＋外部 Home 运动传感器通知”唤醒面板的技巧；开发者明确称仅在 iOS 26 做过测试，不保证系统持续支持。这是第三方厂商的实验记录，**不能作为 HomePad 已能唤醒系统锁屏的依据**。[厂商 FAQ](https://nxtbgthng.com/wallflower/faq)

## 本项目建议与待验证项

1. 本轮采用应用内待机：持续近竖直、静止且空闲达到时限后进入时钟；触摸或启用的移动／人脸在场检测恢复原页面。保留明确的预览入口和硬件不可用说明。
2. 后续可增加“时钟／调暗原面板／纯黑”样式，以及引导式访问状态和简短系统操作指引。配置入口始终可找回；是否增加系统认证保护由用户场景决定。
3. 本轮已通过纯状态机复现“只在待机开相机、见脸即停”会在持续有人时周期性待机再恢复。旧人脸唤醒偏好仍只允许待机检测；不能用修复循环为由扩大旧授权。持续检测使用独立、默认未同意、带版本的开关，用户明确选择后才在非待机前台页面低频检测，在场刷新独立活动时间、离开满时限再待机。系统相机权限不代表这项新同意。关闭可恢复原范围，关闭总开关还会清除额外同意；后台和弹层暂停，过期样本不会永久阻止待机。设置、中英文权限说明及数据生命周期同步说明采样时段与系统指示；实际感知与功耗仍需真机验证。
4. 后续优化可评估 `AVCaptureMetadataOutput`，先检查设备的 `availableMetadataObjectTypes` 是否包含人脸类型，再决定是否替换 Vision。Apple 明确要求只配置设备实际支持的元数据类型；厂商的节能表述不代替本项目实测。[Apple：可用元数据类型](https://developer.apple.com/documentation/avfoundation/avcapturemetadataoutput/availablemetadataobjecttypes)
5. 长期常驻、锁定后的恢复、硬件感知距离、发热、充电和耗电必须在实体 iPad 分别验收。模拟器只能验证界面、偏好保存与应用内状态转换。未经真机测试，不把上述建议写成已完成能力。

## “专用 iPad”设置体验

本轮源代码已增加以下设置区块；构建、界面验证及实体设备上的引导式访问会话分别验收，结果以 `docs/VALIDATION.md` 为准。

待机设置前的“专用 iPad”区块显示“引导式访问：正在运行／未运行”，提供 Apple 设置说明链接。状态读取 `UIAccessibility.isGuidedAccessEnabled`，通过状态变化通知及回到前台时刷新；它表示会话是否正在运行，不代表已检测系统全部配置。[Apple：状态变化通知](https://developer.apple.com/documentation/uikit/uiaccessibility/guidedaccessstatusdidchangenotification)

给用户的设置步骤保持三步：

1. 在 iPad“设置 → 辅助功能 → 引导式访问”开启功能并设置退出密码。
2. 回到 HomePad，连按三次顶部按钮或主屏幕按钮，启动引导式访问。保留“触摸”和“运动”，让点按、旋转及移动检测继续可用。
3. 返回应用设置先点“预览待机”确认体验；需要离开时，连按三次相同按钮并完成系统认证。应用内设置展示当前前台常亮与夜间计划，不显示未经系统 API 确认的“已接管锁屏”。

以上手动流程依据 [Apple 的引导式访问说明](https://support.apple.com/en-ie/guide/ipad/ipada16d1374/ipados)；专用设备的自动锁定时间也应由用户在该系统页面确认。普通设备不提供保证成功的“一键开启引导式访问”入口，不调用私有设置深链。
