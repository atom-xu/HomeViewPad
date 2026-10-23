# HomePad project rules

This is an independent personal open-source SwiftUI iPad project. Never import employer code, credentials or private services. Use public Apple APIs and original/licensed assets.

Actual Git commits may occur only after 22:00 on weekdays or at any time on weekends in America/New_York. Check the real current time with `python3 scripts/commit_guard.py`. Never fabricate or backdate timestamps. Leave changes uncommitted outside the window. Do not push, publish or deploy without a separately specified destination and authorization.

Keep demo mode visibly labeled and deterministic. Never show demo values as real hardware results. Do not instantiate HMHomeManager in demo mode. Physical HomeKit/HomePod/camera/AirPlay verification is separate from simulator tests.

Run the HomePad scheme's XCTest/XCUITest suite after meaningful behavior changes. Inspect exported screenshots after layout changes. Document tested device/runtime and limitations in docs/VALIDATION.md. The project generator overwrites project settings; preserve intentional changes when regenerating.

## Fork 开发约定

本 fork 的开发入口是 `SETUP.md`、`docs/DEVELOPMENT.md` 和 `docs/INITIALIZATION.md`。以上原作者规则继续保留；下列约定用于后续本地开发。

- 开始前读取上述文档和 `docs/ARCHITECTURE.md`，检查当前分支、差异和远端。保留已有工作，按路径暂存自己的改动。
- 每次迭代先写清用户场景、范围、验收方式，再做最小可验证修改。发现无关问题时记录，不顺手扩大本次范围。
- 保留原生 SwiftUI、系统权限和无后端的现有边界；不要把其他项目的服务、框架、业务状态和部署方式搬进来。
- HomeKit 控制统一经 `HomeStore`；成功反馈以设备写入及回读为依据。权限撤销、切换家庭、取消和后台恢复都要处理旧请求与旧数据。
- 常用交互复用现有组件；布局改动检查横竖屏、大字号及无障碍，保留截图证据。
- 用独立模拟器和合成照片建立基线，产物放在 `.validation/`。先定位失败来自环境、测试还是应用，再决定是否改代码；不为变绿而放宽断言。
- 记录具体版本、命令和通过、失败、未测项。代码完成、测试通过、Git 提交、远端同步、真机运行和硬件验收分别报告。
- `origin` 是 `atom-xu/HomeViewPad`，`upstream` 是 `kuscholar/HomeViewPad`。上游同步使用 fetch 和普通合并或变基；不覆盖已有工作，不向上游直接推送，不使用强推完成初始化。
- 新经验只在问题复现并验证修复后写入 `docs/DEVELOPMENT.md`，写清适用条件；每次交接更新 `docs/INITIALIZATION.md`，不要把推测写成既定结论。
