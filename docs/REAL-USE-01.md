# 真实使用迭代 01

用户场景：在自己的 iPad 上查看照片、音乐、日程和家庭设备，使用清楚的连接与权限入口；本轮不再以演示场景作为产品完成标准。

## 范围

- 独立照片页支持多张选择、适合横屏的照片墙和轮播；保留单张壁纸的既有用途。检查 Apple 公开接口能读取哪些相册与精选来源，说明 iPhone 照片经 iCloud 同步的边界。
- 增加独立音乐界面、真实 Apple Music 授权与可用播放入口；完善日程连接、摄像机选择及连接状态。外部订阅、签名能力或没有硬件的情况显示真实限制。
- 家庭设置能明确选择和切换已有 Apple Home 家庭。显示与待机改为用户能理解的简短选项；权限在实际连接或启用时申请，拒绝后有明确恢复入口，不自动扩张权限。
- Home 左侧三列正方形主控网格，用户已确认行数随控件增加并向下滚动。右侧固定一列长方形，逐行与左侧等高，宽度使用剩余空间；可选择监控等适合长方形的内容，不做矮快捷条或强制正方形。
- 开关设备：图标直接切换；文字打开详情，颜色等能力以真实设备公开特征为准。移除额外开／关文字与状态圆点，保留可辨认的状态和无障碍说明。
- Home 控制页移除提醒入口；独立日程不混入提醒事项。

## 验收

先冻结应用源码并运行完整 HomePad XCTest/XCUITest；新策略、权限拒绝与数据清理进行必要回归，布局导出截图检查。使用独立模拟器与合成照片验证，不接管用户正在体验的真机。随后签名安装到已授权的 Boom pad，以普通真实模式启动；系统权限由用户按真实需求授予。安装、启动、权限、实际家庭写入和硬件播放／视频分别记录，模拟器不能代替硬件验收。

保留现有未提交工作；不提交、推送或公开发布。新发现与未完成项写入交接和验证记录，不用演示数据替代真实失败。

## 音乐与日历接入边界

本轮新增 `MusicStore`／`MusicPage` 与 `AgendaStore`／`AgendaView`，根页面持有 store。音乐既可作为独立页面，也可复用在原音乐入口；日历仅显示这台 iPad 已同步日历中未来七天的事件，不再请求提醒事项。以下为实现和待验收范围，编译／测试／真机结果以 VALIDATION 为准。

- Apple Music 使用系统 MusicKit：用户点击「连接 Apple Music」后才请求权限。连接后读取订阅可用性、最多 100 首个人资料库歌曲，目录搜索最多 25 首；按用户点击建立应用自己的播放队列，显示真实当前曲及播放／暂停状态。目录播放以 `canPlayCatalogContent` 为依据；非订阅状态不把可尝试播放的个人资料库歌曲与音频文件一并禁用。网络、账号或服务配置失败保留真实错误与重试入口，不显示样例歌曲。
- `ApplicationMusicPlayer` 只控制 HomePad 的播放。AirPlay 扬声器选择由系统处理；不声称能接管 HomePod 自己的播放队列、读取任意 HomePod 的历史或控制 Siri。普通文件播放继续复用现有 `AudioStore`，与 Apple Music 互相暂停。项目保持前台播放边界，不新增后台音频模式。
- MusicKit 的自动开发者 token 来自 Apple 开发门户中与安装包 bundle ID 完全一致的 Explicit App ID → App Services → MusicKit。Apple 明确将其作为服务器端 App Service；不要添加不存在的 `com.apple.developer.musickit` entitlement，也不在项目内放私钥或手工 token。需要在 Info.plist 和本地化用途说明中增加 `NSAppleMusicUsageDescription`。**本地源码接入不代表当前账号已启用这项服务；门户是否可用、Apple Music 授权／订阅／实际播放仍需真机确认。**
- 日历连接按钮同时表达「在共享屏幕显示」的意图并申请 EventKit 权限，无需用户先去设置寻找另一开关。iPadOS 17 以后读取日历需要 `requestFullAccessToEvents()` 和 `NSCalendarsFullAccessUsageDescription`；系统将此权限称为完全访问，但 HomePad 本次只读，不创建、修改或删除事件。拒绝后提供 iPad 设置入口；write-only 不能当作已允许读取。
- 音乐与日历数据只保留在内存；音乐仅保存连接意图。后台、取消连接、隐藏日历和切换演示会清空对应共享内容并移除观察者，迟到回调不能恢复旧列表。权限弹窗引起的临时 inactive 不应破坏已完成的授权；回前台重读实际系统权限，获准后恢复，拒绝则保持真实状态。日历监听 EventKit 变动并重新读取，不发起新权限请求。
- `RealMediaStoreTests` 使用独立 fake adapter 检查未连接／演示隔离、拒绝恢复、权限弹窗前后台时序、取消后的迟到结果、撤权清理、实际错误和日历七天范围；这些不证明 Apple 账号、实际 EventKit 数据、音乐流或 AirPlay 硬件已验收。

Apple 公开资料（2026-10-16 查阅）：

- [MusicKit 框架与权限说明](https://developer.apple.com/documentation/musickit)
- [自动生成 Apple Music 开发者 token](https://developer.apple.com/documentation/musickit/using-automatic-token-generation-for-apple-music-api)
- [开发门户启用 MusicKit App Service](https://developer.apple.com/help/account/services/musickit/)
- [Apple DTS：App Service 不存在代码签名 entitlement](https://developer.apple.com/forums/thread/799000)
- [ApplicationMusicPlayer](https://developer.apple.com/documentation/musickit/applicationmusicplayer)
- [MusicSubscription](https://developer.apple.com/documentation/musickit/musicsubscription)
- [EventKit 日历访问与 iPadOS 17 权限](https://developer.apple.com/documentation/eventkit/accessing-calendar-using-eventkit-and-eventkitui)
- [读取事件需要完整权限](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:))
