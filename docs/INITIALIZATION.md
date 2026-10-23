# HomePad 本地初始化与交接

## 当前交接：2026-10-17

项目目录 `/Users/atom/Desktop/homepad`，分支 `codex/ipad-display-01`，基于 `3c395111ab2a6c85e62ca763f7c156da4845b49c`。项目称 homepad，应用显示名 HomePad。以下旧章节保留初始化历史；当前工具链与验证以 VALIDATION 顶部记录为准。

### 当前：音乐返回与顶部控件 08

- 用户要求播放器返回专辑卡片；队列只从右下入口进入。已修复未知播放源返回队列导致的循环，所有来源都回 Albums 根页，确认专辑仅辅助焦点；不把重开空队列改成持久化需求。
- 搜索 UI／入口撤除；AirPlay、音量、设置统一44点圆形目标。音量使用带标题／完成的原生 MPVolumeView 弹层；专辑和歌曲 Cover Flow 增加上下渐隐及阴影空间，沿用原横向渐隐、拖动与独立大字号列表。未改 Home 几何、MusicStore、Dashboard、Services 或播放／权限／后台策略。见 [MUSIC-REFINEMENT-08](MUSIC-REFINEMENT-08.md)。
- 原实现单元复现0／1；修复后170单元通过。旧UI runner执行旧方法的失败和一次主动中断均保留；仅卸载独立 Acceptance 的测试 runner、换外部 derived 后，实际新返回／音量与最大中文字号两项2／2通过。加入未知源／空专辑／空队列边界后，最终未筛选 scheme 正在运行，尚不称完整回归通过。
- 当前48文件清单 `7c794f69a68c8a3201aed9988764cab6051478e7223dba2c52210055d7f2666c`；签名包构建、严格签名、profile到期与包含目标设备检查通过。无线实际RPC4016／配对重试4000后，用户连接USB，CoreDevice有线connected，已安装到同一 Boom pad／iPadOS27.0.1；精确URL及普通 `--page 5` 前台启动、PID／executable回读通过。真机查看器关闭；未改网络、权限、系统音量／输出或重置数据。用户确认音量滑杆“能看到滑杆，拖动正常”；SDK27 devicectl静态取图先读到时钟，经用户打开专辑后已查看真实封面静止帧，上下空间／渐隐与圆形图标可见，未开查看器或远程点击。用户随后确认待播清单→播放器→返回为“到了专辑卡片页，不再循环”；其他来源焦点／动态翻动／声音仍待验，不能沿用05结果。原始证据 `.validation/local/music-refinement-08/`；[摘要](evidence/ipad-music-refinement-summary.json)。未提交、推送或公开发布。

### 上次：音乐浏览与返回 06、手动天气城市 07

- **随后真机更新已完成（2026-10-17）**：用户再次授权连接重试后，精确设备RPC恢复，已安装同一验证签名包到 Boom pad（iPad Pro11寸第4代／iPadOS27.0.1，24A446）。新安装URL与bundle回读一致；普通 `--page 5` 前台启动与PID／executable独立回读通过，仅工具默认TERM，无演示／测试／语言覆盖。全部48源码与5个包文件未变，未重跑原生测试。CoreDevice当前报告有线连接，先前“无线”描述已更正；未由agent操作线缆、改代理／音频、打开Device Hub或重置数据。画面／发声／真实一次定位等仍待独立硬件验收。[真机证据](evidence/ipad-music-browser-weather-physical-update-summary.json)。下列“尚未安装”为前一检查点历史，不代表当前状态。

- 音乐范围见 [MUSIC-BROWSER-06](MUSIC-BROWSER-06.md)：封面边缘渐隐、专辑／歌曲／歌单选中区分、歌曲封面翻阅、顶栏搜索、播放留页、底部进入播放器、箭头返回实际播放来源、原生可读设置与小随机控件。Home 几何、音频路线未改。
- [WEATHER-MANUAL-07](WEATHER-MANUAL-07.md)：手动城市优先，只有显式“定位一次”才申请位置；成功保存取整城市并释放资源。启动／前台／旧follow值／天气刷新均不定位；取消、后台、超时与手动新选择拒绝旧回调。天气仍按已存城市刷新。
- 初次全套主动中断后修正来源指纹时序／Form同行按钮结构；未筛选音乐06候选 **200／204**。合入天气后的相关 scheme **175／176**（169单元、6／7 UI）。最后一项是新增测试把940点满宽行要求包含在938点人工视口；纠正真实几何后，队列末曲与手动城市两项 **2／2**。前一候选到此只变三文件：UI测试、权限页一句说明和其双语。原失败包保留，跨相关包169单元＋8个不同UI方法通过，不称单份全绿完整回归。
- `app.screenshot()` 的队列附图带方向／裁切异常，独立重跑同一验收改用现有 `XCUIScreen.main` 捕获；只改测试附件，重复同一验收 **1／1** 通过，完整队列前后像素已查看；最终48文件快照 `14932f7c509d46238c82f5f1d0d6728a44d67ed195f13168191ea7afc97b3347`，其他47个清单文件与最终签名构建相同。精确状态与截图检查见 [VALIDATION](VALIDATION.md)和[结果摘要](evidence/ipad-music-browser-weather-summary.json)。真实 Apple 逆地理成功及真机新音乐导航／封面仍待验。
- 上一连接检查点：最终包构建、严格签名、profile到期及目标设备包含检查通过；构建48文件清单 `59d358f6e2ed4b37ab79a4c44a548fc17d0bc9be9a8ab474119ee54bf3c1e20b`。用户已解锁／同Wi-Fi，最终精确 app RPC仍4016（早期重连4000），本轮未安装或启动新包。未改代理／音频，未打开 Device Hub。原始资料 `.validation/local/music-browser-06/` 及 `.validation/local/weather-manual-07/`。无提交、推送或公开发布。

### 上次：整队列播放与显示待机 05

- 已实现整张专辑／歌单连续播放与一次整队列随机，完整分页及重复曲目位置；Music 实际播放时临时覆盖 Home 音乐卡和 Home／时钟背景，暂停恢复原背景，独立照片页不变。旧单曲操作本来就传整个数组，不把此前“一次只播一首”归因冒充已复现。范围见 [PLAYBACK-DISPLAY-05](PLAYBACK-DISPLAY-05.md)。
- “保持当前页面”按真实闲置延时调暗，播放音乐也生效；首次触摸只唤醒。自动时钟／照片另为模式；未明确选择的旧 V1／传感器偏好不自动迁移。设置统一一层完整原生标题与背景，背景照片／默认颜色／独立照片墙分清；日历、天气城市与单位、权限提升入口，连接日历后可主动添加 Home。
- 诊断编译和首轮测试编译失败保留；完整 scheme **195／198**（156 单元全过，39／42 UI）。失败为旧自动城市超时、启动字符串未实际设成 30 秒，以及长照片演示跨入了持久化闲置模式。仅调整真实 Picker 设置／显式测试模式，原计时与分页断言保留。看图发现最大字号图标栏重叠，修为 ScaledMetric 后，最终快照 `1c9adfae6796a3460e6e286767d18ddaf46997507e09d003b0426a90e35aa3e6` 的相关回归 **161／161**（156 单元＋5 UI），17 张最终截图全部查看；完整包 87 张查看 10 张。其余 46 文件与完整候选相同，不称最终单份全绿完整套件。[验证结果](evidence/ipad-playback-display-summary.json)。
- 用户批准仅绕过 iPad 本地域名；既有 DNS filter 添加 `+.coredevice.local`，原生重载，其他生成配置值未变，代理 rule／TUN 保持开启，连接恢复。最终签名包已更新同一实体 iPad，并普通打开音乐页，精确安装 URL／进程回读一致。用户已确认新包“有声音，且自动进入下一首”。真机查看器关闭，未改音频输出／音量。大歌单／真机随机／真实封面背景／日历添加／长期亮度夜间等另待验，旧定位及连续预览观察保留。原始证据 `.validation/local/playback-display-05/`；未提交、推送或公开发布。

### 上次：音乐页导航修复 04

- 用户反馈音乐页单指不能退出；新增播放器封面／空白横向分页、页头「页面」入口；Cover Flow／进度条及本地控件保留自身操作。退出后保留浏览路径、专辑位置、搜索草稿和播放，不改 Home 几何、权限或音频策略。见 [MUSIC-NAVIGATION-04](MUSIC-NAVIGATION-04.md)。
- 原实现 0／1 复现，首次修复 2／3、封面取消点击修复 1／1；第一份完整 scheme **170／172**，失败为旧自动城市超时及真实专辑拖动误切页面。视频／触摸位置确认是父手势冲突，未删断言。音乐页改为自己的低优先级分页、专辑高优先级，135 单元＋六项音乐 UI **141／141**；只读审查后再以 GestureMask 从识别阶段禁用音乐／待机的根分页，活动记录独立。
- 最终应用 48 文件 SHA256 `0b9b7c2bdb5b716723f27a69588dc81216db6ed0150d251c81c880cb8d5c5fbf` 的相关回归 **146／147**（135 单元、11／12 UI，六项音乐全过）。唯一失败是额外连续预览探针第二次未打开，尚未拖动。随后只拆分 UI 场景，原点击唤醒用例完整恢复并 **1／1**，新独立滑动唤醒实际执行 **1／1**；其余 47 文件及应用包不变。第一次 follow-up 未发现新用例，不把未执行计入通过；只重置独立 test runner／新 derived data 后才执行它。最终测试快照 `215cb47cb52875c28d33cc075bee73a3767d111b123c6a5823171e452298a488`，最终应用跨三包 135 单元＋13 个不同 UI 方法通过，不称单份全绿完整回归。[结果与限制](evidence/ipad-music-navigation-summary.json)。23 张最终专项截图查看 15 张，唤醒三张全部查看。
- 最初只完成本地签名构建、严格校验和设备 profile 检查；用户当时选择“保持代理开启，先完成测试”，该检查点未安装。随后用户明确授权“可以更新”，本次已连接并安装同一签名包到实体 iPad Pro 11-inch 第 4 代／iPadOS 27.0.1（24A446）；精确应用及新安装 URL 回读一致，普通 `--page 5` 前台启动成功，匹配 PID／executable 回读通过。48 文件与五个本地包文件未变，无演示／测试／语言覆盖；工具仅带默认 TERM 环境。[真机更新](evidence/ipad-music-navigation-physical-update-summary.json)。未修改代理／网络、音量或输出，未打开 Device Hub，未卸载或重置 App 数据；此前代理干预推测仍无对照，不定根因。实体音乐手势、画面与新包发声待验，上一版硬件结论不沿用。
- 遗留：旧自动城市超时；快速连续重开待机预览失败（未改 preview 策略）；设置列表行中横向拖动可能同时进子项；极长大字号标题从封面起拖的纵向滚动未专项覆盖。当前最大字号合成资料的控件与「页面」均在屏内。原始记录在 `.validation/local/music-page-navigation-04/`。收尾 48 文件、签名包五文件／严格签名、647 项双语、证据 JSON／文档链接及 diff 检查通过；纽约 23:54 提交守卫允许，但本轮无 Git 提交、推送或发布。

### 小红书纯效果图与官方对比（修订，不改 App）

用户改为只要简单效果图，不要宣传文字，并允许填入照片壁纸、摄像头示意和播放中音乐；随后明确对比对象是 **Apple HomeView 官方图**，不是开源上游 HomeViewPad。新版在 `design/social/2026-10-17-xiaohongshu-simple/`：三张无额外文案的全屏 UI 概念图与一张上方 HomeView 官方图、下方 HomePad 的无字对比。HomePad 三图由内置 ImageGen 基于模拟器截图编辑，使用有来源记录的真实摄影，保留演示／TEST DATA；它们不再声称为未改动实截。Apple 官方原图保持原字节，仅在对比版式裁周围墙面。来源、完整提示词与验证保存在素材目录；详情见 [VALIDATION](VALIDATION.md)。旧六张海报保留供追溯。本次未修改 App、操作模拟器／真机、运行原生套件、提交、推送或公开发布。

用户随后要求再补音乐选专辑页：已增加 `exports/05-albums.png`，沿用同套暖棕摄影封面与 Cover Flow，保留 TEST DATA；未修改原四张图。当前共五张（四张 HomePad 概念图与一张官方对比），无字概览与画廊均更新，五图来源／尺寸／资源加载检查通过。新增完整提示词在 `assets/imagegen-albums-prompt.json`，不把概念选专辑效果当真实资料库或播放验收。

### 小红书展示素材第一版（不改 App）

用户已明确选择只制作展示图和文案。交付目录为 `design/social/2026-10-17-xiaohongshu/`，六张 1440 × 1920 PNG 涵盖封面、家庭控制、音乐、照片墙、时钟待机与功能概览，另有离线预览、可编辑 HTML/CSS 和截图来源清单。父任务与设计 agent 已分别逐张看图；渲染检查通过，详见 [VALIDATION](VALIDATION.md)。App 实截保留演示／音乐测试数据标记，封面单独的 ImageGen 家居背景有 AI 标识，未重画 App 或伪造设备成果。本轮未修改 App、接管模拟器、安装真机或重跑原生套件；既有音乐导航 04 并行开发及其测试属于另一范围。未提交、推送或公开发布。

### 上次：四项交互修复 03

- 用户要求修复 AirPlay 跳加载、总览左右切页黑底、Home 长按放大裁切，以及摄像头跨页重复重连。范围见 [INTERACTION-FIXES-03](INTERACTION-FIXES-03.md)，保留既有 Home 几何与真实服务边界。
- AirPlay 以原生 delegate 区分临时 inactive；真正后台仍清理、暂停，恢复检查撤权。Overview 黑底与方形内容归为同一转场；长按菜单使用完整有安全边的预览，补系统白底导致的对比度问题。Home 摄像头改为共用前台内存快照，最短十秒更新、同相机单请求、跨页复用，点开才静音实时；切家庭／权限／后台清理并拒绝迟到结果。
- 首次构建失败与 134／136、138／139 两次专项失败均保留；135 单元已全部通过（3 AirPlay＋11 摄像头新增），总览反复切页与左右横屏像素检查通过；正常字号温控／边缘卡片预览修复后 1／1 通过且两张截图已查看。原生快照回调独立 delivery 修复经过只读复审和可控回归，不能冒充硬件复现。最后新增中文最大字号预览检查一并进入完整回归。
- 完整 scheme 的 48 文件快照 `7068126a79d7d8ea6de33dbe7674e514e5e81686cad6185c44ae7eee9e2dc049` 未变，有效结果包 **168／170**（135 单元全过、33／35 UI）。失败为旧自动城市超时和进入动画期间过早查询中文音乐按钮。仅 UI 测试增加页头就绪等待，其他 47 文件／已安装应用不变；测试快照 `57df524b02a1abe3902ab3b012216068e18516533040b9d25dee3ba0dc6ab3b2` 的 4 条音乐 UI **4／4 通过**。跨包 169 个不同方法通过，旧定位仍未通过，不能称单一 170 全绿。完整包 70 张截图查看 10 张，复测 7 张全部查看。[最终结果](evidence/ipad-interaction-fixes-full-suite-summary.json)。原始资料在 `.validation/local/interaction-fixes-03/`。最终签名包严格校验通过，已无线更新同一台实体 iPad Pro 11-inch 第 4 代／iPadOS 27.0.1（24A446）；精确应用及安装 URL 回读一致，普通 `--page 5` 启动成功，无演示／测试／语言覆盖。真机查看器保持关闭。用户已确认音乐 AirPlay「页面保持不变，不再跳加载」及 Home「能看到静态快照更新」；未测量精确间隔，不据此推断音频、后台／撤权、离线恢复、实时停流及真机时钟／预览等其他硬件路径。[真机更新](evidence/ipad-interaction-fixes-physical-update-summary.json)。48 文件当前散列、5 个签名包文件、645 项双语、JSON／链接和 diff 检查通过。纽约实时时间 2026-10-16 22:29 的守卫允许提交；本轮仍未提交、推送或发布。

### 上次：音乐切换交互补齐 02

- 用户指出切换细节未完成，本轮按音乐主流程处理：来源返回、跨 Dashboard 保留专辑位置与搜索词、Home 卡片明确打开播放器、子页过渡、Cover Flow 跟手／越界归位、选歌完成再跳转与失败留原处、当前歌曲标记与统一等待状态、封面和背景交接。其他页面排布不改；细化范围在 MUSIC-DESIGN-01 顶部。
- 首次专项 **31／31 通过**（27 媒体单元＋4 音乐 UI），已导出查看返回后专辑、选歌失败和 Home 卡片截图。随后新增单元测试在旧代码复现“每次打开音乐页重新连接、清空当前专辑并重复请求”的问题，修复为前台复用并照常重查权限、保留显式刷新。
- 完整执行的 48 文件快照 SHA256 `31b0cac357da7ed3e18af2e8ac66f6aaee886a485d3a538728eed669db124672` 未变。未过滤执行日志为 **151／154 通过、3 失败**（121 单元全过、30／33 UI）：旧自动城市超时，加上两项在页面进入动画期间过早点击的音乐 UI 用例。全部方法跑完后 Xcode 保存结果包失败、退出 73，完整日志与部分 Staging 诊断保留，不能声称有有效完整 xcresult。只为测试补播放器／按钮布局稳定与 Cover Flow 就绪断言，其他 47 文件未变；新测试快照 `9caf096fb2a44385c2b3412607c4618ed3bcbce08f86bd84c0edde73a4064aa6` 的专项复测 **125／125 通过**（121 单元＋4 音乐 UI，0 失败、0 跳过），退出 0；有效 xcresult 摘要及 7 张截图已导出，7 张均查看。跨两次执行共 153 个不同方法通过，旧自动城市仍未通过，不能称单一 154／154 全绿。[完整执行与最终复测](evidence/ipad-music-interaction-full-suite-summary.json)。
- 原始资料在 `.validation/local/music-interaction-02/`；此前一次完整尝试主动中止，另一次编译回调参数报错发生在测试开始前，均不计成功套件。
- 补充区分搜索草稿与已提交搜索；返回搜索页只恢复先前明确提交的请求，不自动提交草稿。最终签名包已严格校验并更新实体 iPad，精确应用回读成功，安装 URL 一致；安装后尝试启动时 iPad 锁屏，系统拒绝自动打开，用户解锁后可自行打开。应用源码仍对应完整执行的 `31b0…` 快照，后续仅改测试等待，无需为此重装。[真机更新回读](evidence/ipad-music-interaction-physical-update-summary.json)。上一版真机发声已由用户确认，本轮新包尚不能沿用此结论。保持 Mac 真机查看器关闭；没有改系统音频或真实家庭。收尾 48 文件散列、签名包文件、639 项中英文、证据 JSON／链接及 diff 检查通过；12:58 纽约时间的守卫要求保留待提交。未提交、推送或公开发布。

### 音乐改版：原生接入并更新真机

- 用户已批准预览并要求接入真实 Apple Music、更新 iPad。原生 MusicPage 现使用真实封面／进度／播放队列，资料库支持 Cover Flow 翻专辑、展开曲目；只浏览专辑不切歌。统一文字和 SF Symbols 尺寸，最大无障碍字号使用可滚动专辑列表。
- Home 现有右列长方形内增加音乐小控件，与完整音乐页共用一个 MusicStore；封面／文字打开完整页，暂停、切歌及拖动进度同步。处理了它与 Dashboard 横向翻页的手势冲突，没有调整其他 Home 控件布局。
- 真实 MusicKit 专辑／曲目／队列与 playbackTime 读回已接入；没有伪造播放进度。调试合成资料只在同时带 `--uitesting --music-fixture` 时启用并明确显示「测试数据」；普通真机启动没有这些参数。
- 48 文件冻结快照 SHA256 `4e8d6de7f3f3c76442d8f7a6741af62fb877fed3a2f629673d8d32d9b29be453`，完整测试期间未变。独立 iPad Pro 11-inch M5／iPadOS 26.5 模拟器的完整未过滤 scheme 回归 **150／151 通过、1 失败、0 跳过**（120 单元＋30／31 UI）。唯一失败仍是原有自动城市解析超时；音乐及其他 UI 用例通过。完整包导出 65 张截图，音乐播放、Cover Flow、Home 小控件、中文最大字号和 Home 几何图已查看。[完整结果](evidence/ipad-music-full-suite-summary.json)。
- 最终包已自动签名、严格校验并无线更新实体 iPad Pro 11-inch 第 4 代／iPadOS 27.0.1（24A446）；精确应用与进程回读成功，普通 `--page 5` 启动。实际画面显示真实资料库封面、Cover Flow、当前曲目和播放进度。
- 最初用户报告 HomePad 无声，系统「音乐」对照同样无声，但视频有声。原输出曾是两个 AirPlay 扬声器；切回 iPad 后仍无声。随后退出 Mac Device Hub、由用户在系统音乐暂停／恢复并按音量加键，用户先确认系统音乐恢复，再确认 **HomePad 也有声音了**。这些步骤同时发生，不能将原因断言为远程查看或音量之一；没有据此改播放代码。HomePod／远端 AirPlay 发声仍未验收。
- 本轮原始结果、源码快照、签名／安装回读及截图在 `.validation/local/music-implementation-01/`；[真机更新与发声验收](evidence/ipad-music-physical-update-summary.json)、[专项失败与修复记录](evidence/ipad-music-focused-summary.json)。独立重生成的工程／scheme／Info／entitlements 与现有文件一致，639 项中英文完整，diff 检查通过。真机资料库、家庭标识与私有图片不导出到共享证据。11:37 纽约时间的提交守卫要求保留待提交；未提交、推送或公开发布。

### 音乐改版：此前设计预览记录

- 用户提供新的音乐播放器参考图，并明确选择老 iPod 的 **Cover Flow 左右翻专辑封面**。方案见 [MUSIC-DESIGN-01](MUSIC-DESIGN-01.md)。播放页保持大封面／进度／大播放控件，选歌页独立翻专辑、展开曲目；浏览不切歌。
- 本轮完成对话内可点击设计预览，使用明确标注的原创示例封面和虚构曲目，不播放音频。检查了资料库、翻阅、歌曲选择返回以及窄宽度无溢出；证据副本在 `.validation/local/music-design-01/`。
- 已按最新反馈统一图标：圆角实心播放控件、双三角上下首，次级入口统一描边与视觉尺寸；播放器和专辑浏览实际渲染均已查看。当前本地预览为 `http://127.0.0.1:52848/`。
- 后续反馈已纳入同一预览：歌名字号和主播放图标收小、次级描边减轻，增加 Home 右侧长方形音乐小控件（相当于左侧一行高）。小控件与完整页的暂停／切歌／进度同步及封面打开完整页已在浏览器检查；320px 下无横向溢出，临时 viewport 已恢复。仍未改变原生源码或真机安装。
- 原生 46 文件仍与上一轮最终测试快照一致。本轮没有改 SwiftUI、没有运行原生测试、没有更新 iPad；当前真机仍是下列真实使用迭代版本。下一步是根据用户对可见预览的反馈实现 MusicPage／真实专辑与播放进度能力，不能把预览当作已接入 MusicKit。

### 真实使用迭代 01 已更新真机

- 范围见 [REAL-USE-01](REAL-USE-01.md)：多选照片墙／收藏／照片待机；独立 Apple Music 页与只读七日日程；家庭选择与按需权限；Home 左三列正方形、右列长方形且逐行等高；图标开关、文字详情；移除提醒事项读取。原生 MusicKit/EventKit/PhotoKit/HomeKit，无新增后端或私钥。
- 摄像机默认不自动选取；明确选入右侧卡片后才显示视频。旧无来源场景捷径要求重新选择家庭，不继承另一家庭的同名场景。照片授权后回前台重读结果；折叠组标识不覆盖子项。复现与修复依据见 DEVELOPMENT 和 VALIDATION。
- 用户已确认在 Apple 开发者后台勾选 MusicKit 并保存；当次界面看到勾选，刷新登录过期，未以服务器回读或真实播放确认。iPad 音乐／日历授权由用户按需连接。
- 完整 scheme **133／141 通过、8 失败、0 跳过**（112 单元＋21／29 UI），冻结 SHA256 `f639c07462460951431c44534de9affda8cc8f5ea4b5dcdddae3d7f7b43f67ec`。首轮 7 项诊断复测为 1 通过／6 失败，原证据保留。最终应用修复包 46 文件 SHA256 `8aceed0dece70a07f01de9d2eca2e1153fd364ea724e9bab7d6c68c46cfd6a7a`，修复检查 **118／119 通过**（112 单元、6／7 UI）；最后仅修正欢迎页旧标题断言，单项复测 **1／1 通过**，其余 45 文件不变。最终测试快照 SHA256 `51d12ef409379e8465acf115bcdf54d298b44f563c780d08f36eb0cc8dc1fb5e`。跨包共 140 个不同方法通过，自动城市解析仍未通过，不能称单一 141／141 全绿。
- 最终应用已签名更新到实体 iPad Pro 11-inch 第 4 代／iPadOS 27.0.1（24A446）。应用精确回读、普通启动 `--page 1`、进程回读成功，无演示、测试或语言覆盖参数。Device Hub 已看到真实中文 Home 保留原家庭与卡片、右侧同高长方形；最后更新后看到真实照片页与当前日期时间。未替用户选择照片或推断照片来源。
- 原始命令／日志／结果包／源码快照／合成截图位于 `.validation/local/real-use-01/`；可分享摘要见 [完整回归](evidence/ipad-real-use-full-suite-summary.json)、[最终复测](evidence/ipad-real-use-final-check-summary.json)、[真机更新](evidence/ipad-real-use-physical-update-summary.json)。不导出家庭标识、私有照片或账号。
- 真实音乐播放、AirPlay、日历访问、家庭视频／设备写入及感知硬件未验收。旧自动定位城市测试仍失败，手动选城／实时天气已通过。未提交、推送或发布；当前纽约工作日时间不在提交窗口。用户的真机当前页面不再自动改动。

### 前次首次真机安装检查点

- 最新本地要求：相册选择壁纸，以 aspect-fill 铺满 Home／Clock 视口；可取消、替换、重启恢复和恢复默认，与独立照片页分开保存。首页控件排布与温控 2×2／右侧新增一列保持原样。
- 暂仅支持左右横屏；竖屏代码保留但不启用。不改变 iPad 的系统旋转锁定。iPadOS 26.5 的兼容窗口缩放与 `UIRequiresFullScreen` 前向兼容警告如实记录；未测 iPadOS 27 窗口模式。
- 另一会话转交了用户已批准的设置精简：四个主入口为家庭／显示与待机／内容与隐私／通用，帮助与关于单列，教程及演示诊断下沉。三个屏幕模式只在明确选择时写新偏好；读取旧自动待机与常亮组合不改变行为。
- 相机默认关闭。旧人脸唤醒偏好只允许待机采样；持续前台检测仍须独立版本化同意，系统相机权限不能替代。关闭总开关清除额外同意。新天气设置无预设城市、不自动申请定位、温度跟随系统地区；旧手动城市与单位保留。完全空白旧沙盒无法与首次安装区分，按新安装处理。
- 整合源码冻结 38 文件，SHA256 `9f16832e2a8efe9c0619db31dec5e09076b24c204e5d9fae115d9e187d78491c`；完整 scheme 为 **90／92 通过（66 单元＋24 UI），2 失败、0 跳过**。仅加强系统选图器取消后的测试等待后，三项复测 **2 通过、1 失败**，选图器及设置返回通过；城市解析首轮无结果、复测请求超时，仍未通过。应用源码未变，只有 UI 测试 helper 改动，当前测试快照 SHA 为 `a626603005eaa5c11209453daaab4b2d4f2607c94dd4059056928da9f0d2e4f4`。不得称单一 92／92 全绿。此前壁纸候选与旧 59／59 均为历史结果。
- 独立 13-inch M5／iPadOS 26.5 预览已安装并启动当前冻结构建，13 个应用文件（含实际原生代码 dylib）散列一致，没有语言启动覆盖，也未修改相机同意。[预览读回](evidence/ipad-settings-wallpaper-preview-summary.json)。11-inch M5 同 runtime 模拟器独立验收，照片为两张生成渐变图及 runtime 样图，位置为模拟注入。
- 10:44 的只读收尾确认没有 xcodebuild／XCTest／UI runner 在运行，38 文件快照仍一致；定位失败保留为系统解析依赖未通过，手动选城与实时天气已验证，不重复完整套件。见 [定位收尾证据](evidence/ipad-weather-location-closure-audit.json)。
- 实体「Boom pad」已通过局域网无线配对，实测为 iPad Pro 11-inch 第 4 代（iPad14,3）／iPadOS 27.0.1（24A446）。用户启用开发者模式、解锁并本人同意 Apple 开发者协议后，开发组件兼容，自动签名构建及 codesign 校验通过。Desktop 构建产物的 FinderInfo 导致签名失败；同源码改用独立 `/private/tmp` derived-data 后通过，未改源码或系统安全保护。
- 当前冻结包 HomePad 1.0（1）已无线安装到真机，应用列表精确回读、演示启动和进程回读均成功；Device Hub 实际看到横屏中文时钟、演示标记及演示时间。启动参数为 `--demo --page 1`，后续看到的时钟不作为首次 Home 页面或自动待机触发证据。未覆盖语言、连接真实家庭或授予相机／定位权限。见 [真机安装证据](evidence/ipad-physical-install-summary.json)。
- 真机已完成安装与基本启动；HomeKit／HomePod／摄像头／AirPlay、真机选壁纸、旋转及窗口模式、感知距离、持续功耗和发热仍未验收。源码本地未提交、未推送、未发布；个人签名配置保留在被忽略的 Local.xcconfig。本次仅处理打包安装，38 文件快照未变，未重复完整测试，定位遗留失败仍保留。

日期为 2026 年 10 月 15 日，时区 Asia/Shanghai。

## 仓库基线

| 项目 | 本次状态 |
| --- | --- |
| 上游 | `kuscholar/HomeViewPad`，MIT 许可 |
| Fork | `atom-xu/HomeViewPad`，GitHub 已确认 parent 指向上游 |
| 本地目录 | `/Users/atom/Desktop/homepad` |
| 开发分支 | `codex/project-initialization` |
| 源码基线 | `3c395111ab2a6c85e62ca763f7c156da4845b49c` |
| 远端 | `origin` 为个人 fork，`upstream` 为原作者仓库 |
| 初始差异 | `origin/main...upstream/main` 为 `0 0` |

## 已完成的初始化

- 完整 clone 到原先为空的本地目录，保留上游历史与 MIT 许可。
- 阅读上游开发约定、架构、隐私、测试和硬件验收文档。
- 生成器执行前后，工程、scheme、Info.plist、entitlements 四个文件的 SHA256 完全一致。
- `xcodebuild -list` 能识别 HomePad、HomePadTests、HomePadUITests 和共享 HomePad scheme。
- 创建独立的 HomeViewPad Development iPad Pro 11-inch M5 模拟器，加入两张合成照片并注入测试位置；UUID 保存在 `.validation/local/simulator-id`。
- 在 `AGENTS.md`、`SETUP.md` 和 `docs/DEVELOPMENT.md` 固化适用的开发经验与操作入口。

## 本机验证

Xcode 为 26.6，build 17F113；Swift 为 6.3.3；现有模拟器 runtime 为 iOS 26.3.1，build 23D8133。应用最低部署版本为 iPadOS 17。

第一次完整测试命令在执行测试前以退出码 70 结束：Xcode 提示 `iOS 26.5 is not installed`，未识别可用 destination。已有 SDK 和可启动模拟器并不足以通过该检查。原始日志保存在 `.validation/local/baseline-test.log`。

补充检查用 `-target HomePad -sdk iphonesimulator` 直接构建时，以退出码 65 结束，资源编译器提示已安装 runtime `23D8133` 无法用于 SDK `23F81a`。日志为 `.validation/local/baseline-build.log`。两次失败均发生在测试运行之前，目前没有本机测试通过结论。

曾通过 Apple 官方命令下载 iOS 26.5 平台组件。用户随后说明正在更新 Xcode，因此已停止本次启动的下载进程并关闭本次专用模拟器，避免与更新并行占用。下载日志保留在 `.validation/local/platform-install.log`。Xcode 更新完成后先重新读取工具链、runtime 和 destinations，再选择可用目标运行测试；不要沿用本文旧工具链快照。

## 提交和验收状态

本次没有修改应用行为。新增开发文档仍为本地未提交工作；原作者 `AGENTS.md` 的时间窗口检查在当前运行时返回 `commits must remain pending`。不修改时间戳或绕过检查。

GitHub fork 创建已完成。文档提交与推送、真机签名安装、实际 HomeKit 控制、HomePod/AirPlay、摄像头和长时间常亮仍需各自验证。

## iPad 预览安装

用户已授权将现有版本安装到自己的 iPad 体验。已找到有效 Apple Development 签名，并在忽略的 `Config/Local.xcconfig` 中设置独立 bundle identifier 和本机 development team；`xcodebuild -showBuildSettings` 已确认配置生效。

目前尚未安装。真机资源编译同样因缺少与当前 SDK 匹配的 simulator runtime 失败，日志为 `.validation/local/device-build.log`。App Store 中 Xcode 更新仍在下载；无需再并行启动另一份平台下载。

设备工具保留一台历史配对 iPad，但当前显示 unavailable；USB 设备树也尚未列出连接设备。用户表示已连接并解锁；随后直接检查 Finder 的“位置”侧栏，也没有出现 iPad。不能把缓存中的旧 OS、开发者模式和配对状态当作当前设备状态。

### Xcode 更新后的验证

Xcode 已更新为 27.0，build 27A266a。首次检查曾遇到旧 CoreDevice/CoreSimulator 组件不匹配；配套组件安装完成后，`xcodebuild -showdestinations` 已能正常列出设备目标，iOS 26.5 runtime 也已可用。

未签名的 arm64 真机构建已通过（`CODE_SIGNING_ALLOWED=NO`），生成的应用为 `cn.vilhil.homeviewpad`，部署目标 iPadOS 17。应用包位于 `.validation/local/device-products/Debug-iphoneos/HomePad.app`，日志为 `.validation/local/device-compile-xcode27.log`。编译通过不等于可安装：带自动签名的构建仍返回 `No Accounts` 和缺少 development provisioning profile；已在界面打开 Xcode 的 Apple Accounts 页面，该页当时显示 Sign In，等待用户完成登录。

用户确认暂时没有可用的数据线，iPad 当前为 iPadOS 26 或更早。Apple 的当前说明要求首次无线配对使用 iPadOS 27 或更高版本；尝试用历史 iPad UDID 配对也返回 device not found，本次需要先通过可传输数据的线建立连接。

用户随后完成 Apple Accounts 登录，界面已确认显示账号。重试自动签名后，Apple 返回 `PLA Update available`，要求在开发者账户同意最新 Program License Agreement；日志为 `.validation/local/device-sign-after-login.log`。协议应由账号本人查看并确认，尚未代为接受。当前编译已通过，签名和真机安装尚未完成。

继续安装时，先确认开发账号、签名 profile 和实体 iPad 连接，再用自动签名构建。安装后须通过设备应用列表回读 bundle identifier，并实际启动确认；这不代替 HomeKit、照片权限和其他硬件功能验收。

## 模拟器预览

用户随后要求先在已经打开的模拟器中体验。已复用 iPad Pro 13-inch M5、iPadOS 26.5 模拟器，以 Xcode 27.0 构建当前 HomePad scheme，`CODE_SIGNING_ALLOWED=NO`，构建退出码为 0。缓存独立放在 `.validation/local/SimulatorDerived/`，日志为 `.validation/local/simulator-preview-build.log`。

已安装 `cn.vilhil.homeviewpad`，通过 `simctl launch --terminate-running-process … --demo` 启动，并回读到已安装应用路径和运行中的进程。Device Hub 界面确认显示 Overview 的日期、时钟、相册、天气和 DEMO 标记；截图 `.validation/local/screenshots/simulator-preview.png` 已查看，界面正常显示。日期、时间和天气是固定演示值。

本次没有修改应用源码，也没有运行完整 XCTest/XCUITest。模拟器预览安装已完成；实体 iPad 的数据连接、签名协议和安装仍保留上述待办。

## 独立 App Icon 设计交接（2026-10-16）

- 独立设计包位于 [`design/app-icon/2026-10-vilhil/`](../design/app-icon/2026-10-vilhil/README.md)，完整离线预览为 `index.html`；总览及深浅背景 120 / 60 px 对比位于 `previews/`。
- 已核对用户的正式 VILHIL VI 图案及使用规范，复用既有正式 SVG 的三条原始路径和原比例。2025 旧 AI 字标、当前淡紫房屋图标及 README 绿色房屋均已区分，不混用品牌，不导入其他项目代码或服务。
- 交付 A 深石墨、B 瓷白、C 晨光三个方案，各含可编辑 SVG 和 1024 / 120 / 60 px 不透明正方形 PNG。推荐 A，主标轮廓清楚，深浅桌面稳定；用户尚未选择或授权接入。
- 三套 1024 原稿及完整预览已查看；原路径、等比变换、九张 PNG 尺寸与不透明度、六项小尺寸中心节点与采样检查通过。具体环境和检查记录见设计包 `validation.json`，源素材及散列见 `manifest.json`。
- 当前 AppIcon PNG、Contents.json、工程和应用源码保持原样，已有工作保留。本轮仅设计资产，无应用行为改动，未运行或声称通过 XCTest/XCUITest；未安装模拟器或实体 iPad，系统最终遮罩与色调外观未验收。未提交、推送、发布或部署。

### App Icon 第二轮：独立符号变形（2026-10-16）

用户反馈第一轮太像公司产品，明确允许变形，并希望参考 Home / SmartThings 的智能家居 app 语言。新包为 [`design/app-icon/2026-10-homepad-v2/`](../design/app-icon/2026-10-homepad-v2/README.md)，旧包保留。已实际查看两者官方 App Store 视觉，只借鉴空间／连接概念，不使用官方具体轮廓或图标。

新交付为三个不同结构：A 小憩（开放空间＋入口小灯）、B 相连（三节点弧形聚合）、C 家窗（三片窗格拼成房屋，推荐继续深化）。各含 SVG、1024 / 120 / 60 PNG 和同色结构；另有总览、深浅背景与原标演变说明。均标注 HomePad 原创变形，不冒充正式 VILHIL Logo。九张 PNG 尺寸／不透明度、六项小尺寸形体关系检查通过，原尺寸及所有预览已查看。未接入 AppIcon、未改工程或应用功能，未安装、提交、推送或发布；系统图标外观与真机色彩仍未验收。

### App Icon 第三轮：家窗精修（2026-10-16）

用户选择第二轮 C「家窗」继续深化，未确认最终颜色或授权替换。新包 [`design/app-icon/2026-10-homepad-v3/`](../design/app-icon/2026-10-homepad-v3/README.md) 保留原 C 并列，交付 C1 清（纯平面）、C2 润（同轮廓细腻层次，推荐）、C3 衡（更宽、更低的屋顶及更紧凑的等宽缝隙）。三片窗格识别保持，圆角改为精确圆弧，统一缝隙，增加主体占比并作轻微光学位移。配色仍是探索基准。

九张新 PNG 与三张原稿对照尺寸／不透明度正确，八项 60／120 px 检查通过，横竖缝至少保留 2 个清楚像素；完整原稿、总览、小尺寸和同色几何预览已查看。每版含 1024 PNG、可编辑 SVG、120／60 PNG。原 AppIcon 与前两轮设计保持一致；图标任务未写入工程或应用源码，工作区其他并行功能改动已保留。本任务未运行应用测试、未安装、提交、推送或发布，系统特殊外观及真机图标仍未验收。


### App Icon 创意发散：家窗的八种可能（2026-10-16）

用户澄清“深化”是继续产生创意，第三轮精修不是当前阶段目标；不把选 C 解释为冻结轮廓。本轮在 [`design/app-icon/2026-10-creative-exploration/`](../design/app-icon/2026-10-creative-exploration/README.md) 交付八个不同结构的同等编号草案：窗里、合院、开页、里外、互嵌、开间、抱窗、拼合。总览 `overview.png` 包含一句概念与 60 px 彩色／单色对比，可编辑 SVG 位于 `symbols/`。只作创意探索，不排序定稿，不逐个生产打包；原 AppIcon 保持不变，本任务未写入工程或应用功能，未安装、提交或推送，其他并行工作保留。


## 已接入选定原版 AppIcon（2026-10-17）

用户在选回第二轮 03 Dwell 家窗后明确说“直接替换吧”。已将其原始 1024 PNG 原样复制到 `HomePad/Assets.xcassets/AppIcon.appiconset/AppIcon.png`：左高青绿、右上薄荷、右下黄色三块。原稿、单款交付 PNG 与项目图标 SHA-256 均为 `491690da02105802543230fbf8eb18645df98e12033b15e12f9b0eec25f57947`，没有改形状、比例、颜色、背景或增加圆角。旧图标及 Contents.json 备份在 `.validation/local/app-icon-original-20261017/backup/AppIcon.appiconset/`。

仅替换这一份应用资源；AppIcon 的 Contents.json、Debug／Release 既有绑定、工程、scheme、生成器、Info.plist、entitlements、签名与其他功能保持本轮开始时状态。Xcode 27.0（27A266a）／SDK 27.0 的独立 generic iOS Simulator Debug（arm64／x86_64）及 generic iOS Release（arm64）未签名构建均退出 0；实际包的 iPad 主图标引用与两份 Assets.car 的不透明 1024 原稿已核对，四张编译后小图已查看。设备 PNG 的 Apple CgBI 优化仅在验证副本中用 pngcrush 解码，未动项目资源或应用产物。40 份构建输入散列保持一致，既有源码警告未在图标任务中扩修。[验证摘要](evidence/ipad-app-icon-original-summary.json)。

没有接管正用于预览／音乐完整测试的两个模拟器，没有为图标改动另跑 XCTest/XCUITest，也未验收系统桌面遮罩、特殊图标外观或真机色彩。本轮未安装模拟器／用户真机，未提交、推送或发布；其他任务原有未提交修改保留。
