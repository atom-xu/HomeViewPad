# 响应速度优化 13

用户场景：首次打开 HomePad、左右切页、Home 滚动和进入设置时出现卡顿。保留已确认的布局、Liquid Glass、音乐交互、家庭权限与待机策略。

本轮范围：先在独立 iPad 模拟器记录同一输入的基线，定位主线程重复工作；仅修复已确认的加载、刷新和渲染热点。重点检查音乐时钟对整页的刷新、Home 配置解析、隐藏背景及设置图片的读取。真机体感与模拟器性能数据分别记录。

验收：对同一合成资料和相同操作做前后对比；运行 HomePad scheme 的 XCTest/XCUITest，覆盖连续音乐进度、跳曲／队列／后台清理、Home 编辑与切页、设置入口与权限；保持既有断言。性能数值注明构建、设备、运行时和采集方式，避免把测试等待时间当渲染帧耗时。沿用本会话明确的 Boom pad 测试安装目标，真实家庭的交互效果另外记录。没有新的 Git 提交／推送；前次时间例外不延用。

状态：Home／音乐／设置性能候选已安装到Boom pad，用户确认操作顺畅。另一个相册查询热点的异步改造仍在本地，照片单元10／10通过，完整照片UI导航回归未通过，尚未安装；不计为完成。

已确认原因与实现：HomeKit每个参数读回都重建并排序全屋，真机系统报告记录9113ms／6580ms主线程阻塞。改为100ms固定窗口合并与局部值替换，结构变化才重新排序；音乐计时不再广播到整页，配置和队列复用缓存。本地播放器按需创建，原布局与硬件写入／回读边界保留。

未证明：模拟器启动首帧基线1.263s、候选1.311s，各3次，不能宣称启动时间改善；暂无线程级真机帧率或有效功耗数据。完整记录见VALIDATION与INITIALIZATION。

依据：[Apple SwiftUI性能诊断](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance)、[PHFetchResult线程安全说明](https://developer.apple.com/documentation/photos/phfetchresult)。
