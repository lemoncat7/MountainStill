# MountainStill v1.3.19 章敌情导航独立审查

日期：2026-10-23。审查对象：`chapter-practice-v1319`；对照：`full-install-candidate/MountainStill`（v1.3.18）。

## 结论

**最终四个导航脚本在本次审查范围内无未解决发布阻断。** 最终源码通过独立 Godot 4.6.3 Linux headless 导航回归 386 项及补充 probe 1512 项，均 0 失败、退出码 0，无 SCRIPT ERROR、解析错误或泄漏警告。补充计数主要由控件几何断言组成，不是 1512 个自然游戏流程。

这是源码逻辑及 headless 控件检查，不是 v19 原生 Windows/macOS、GUI美术、GPU/DPI、性能或发行包验收结论。应继续由构建负责人按最终源码导出、核对实际载荷，并保留已有性能和平台边界。

## 发现及处理

1. **已修复：入口语法阻断。** 初审 `scripts/adventure_pages.gd:178` 的 `elif not guide_open` 比对应 `if` 多一层缩进，脚本不能解析。实现者修正缩进；最终独立两组测试都实际加载该脚本。
2. **已修复：新章来源残留劫持跨书导航。** 初版可复现：历练 → 本章敌情 → 合书 → 札记 → 显式整理衣冠，仍显示敌情，无实际衣冠控件，返回按钮为“返回山路”。直接机缘页 → 看山路 → 整理衣冠也会暴露残留来源。
   - v18 三导航脚本对照确认，旧 insight 覆盖衣冠入口是既有行为，但 v19 新来源令返回转向旧章。因此仅修新来源生命周期，不泛化修复所有旧覆盖层。
   - 最终 `scripts/player_journey_pages.gd:35–41`：有新章来源时，显式札记导航清来源及两覆盖层。
   - 最终 `scripts/ink_pages.gd:79–85`：有新来源且改到非 equipment 页时，同步清理，覆盖直接机缘入口。
   - 独立最终 probe 验证实际衣冠控件恢复，来源为空，机缘/正式状态/RNG保持；已纳入候选新增回归。
3. **测试夹具修正（非产品缺陷）：** 初版旧代数测试用 `_refresh_drawer()` 却期待 generation 递增；宿主仅 animated=true 递增。最终分开验证真实 detached 旧按钮与 `_refresh_drawer(true)` 旧代数，未放松正式状态/准入检查。

## 实际验证范围

- 所有六章：新档锁章占位及显式解锁夹具；敌人行数变化后按 `stage_id` 动态定位，不依赖旧固定下标。锁章只读，不泄露未解锁敌人内容、不允试招。
- 进入/返回不发起历练或试招，不替换 `State.selected_stage`，原章ID与分页恢复；旧装备比较层关闭。
- 快速重复点击、失效按钮、旧代数、变章/变标签/变抽屉后的回调不能覆盖新导航；旧返回按钮不能覆盖新侧标签。
- 六个侧标签和普通衣冠真实入口：来源消耗，普通返回仍是衣冠；合书后直接重开原页则保留原章返回。
- 未完历练、遗体已搜进度、未回应机缘及正在进行的正式历练：既有试招准入继续拦截，未完进程和奖励所有权不变。
- 显式试招后：实际 Escape 取消和完成结果的“结束试招”按钮，恢复原正式 duel/pause 状态，然后可返回原章；无消耗、无正式奖励/存档/RNG改变。
- 快照比较排除 `saved_at`；另外在再次调用 `_snapshot()` 前比较 clock-high-water，避免快照读取自身触时钟造成误判。
- 宽 960/1200/1440 的路页、敌情页、返回页控件均在纸内、不重叠。未观察真实像素、字体裁切、动画或操作系统输入。
- 无效章ID inert；真实在途正式历练可浏览而不能借此试招。

夹具用预置境界/通关标记、尸体种子和机缘检查点，不代表自然养成或通关证据。绝未 GUI 操作或运行性能基准。

## 字节保全与CI

- `final-runtime-integrity.json` 对 v18 比较 **604** 个 scripts/assets/config/场景文件；无增删，仅四个导航脚本、两个版本常量文件、project/export 版本共8处文件差异。
- Service/Store 除 `1.3.18-test.1 → 1.3.19-test.1` 外逐字节逻辑相同；Bootstrap、Policy、Guard、存档结构、战斗算法、试招准入、RNG实现、奖励规则和资产未改。
- 未发现 `.gdextension`，没有 native加速实验混入。
- 经 GitHub connector 按精确 commit `6eb28d396a3d67de0410856d664632a1754537e3` 独立读取14个CI文件的 Git blob SHA，全部与候选实际字节一致。见 `remote-ci-blobs.json` 和 `local-ci-hashes.json`。这些CI文件保留原版本定位，不构成已跑v19的证据。
- 最终四脚本 SHA256 见 `final-runtime-integrity.json`；构建/打包前应再次核对该清单，不能以本报告为后续改动背书。

## 证据与复现

最终：`navigation-final.log`（386/0）、`extra-final.log`（1512/0）；候选最终测试和独立补充测试均附本包。最初通过日志、跨书复现及v18对照日志保留，不覆盖原证据。

将最终候选复制到独立目录（不要在生产存档中跑），把 `test_chapter_practice_navigation_final.gd` 放到 `tests/test_chapter_practice_navigation.gd`，把 `review_chapter_navigation_extra_final.gd` 放到 `tests/review_chapter_navigation_extra.gd`，先导入资源，然后分别运行：

```sh
XDG_DATA_HOME=/absolute/review/data XDG_CONFIG_HOME=/absolute/review/config XDG_CACHE_HOME=/absolute/review/cache \
  godot --headless --path /absolute/review/source --script res://tests/test_chapter_practice_navigation.gd
XDG_DATA_HOME=/absolute/review/data XDG_CONFIG_HOME=/absolute/review/config XDG_CACHE_HOME=/absolute/review/cache \
  godot --headless --path /absolute/review/source --script res://tests/review_chapter_navigation_extra.gd
```

环境事件：第二个完整v18副本因 ENOSPC 未建成；该失败副本已删除，失败日志保留。随后在审查私有副本临时换回v18三导航脚本进行对照，退出0，再恢复最终脚本。没有修改候选或生产目录。该复制失败不是产品失败，也不计作测试通过。

本次不重复全游戏平衡/全更新器矩阵、原生GUI/性能、打包旧安装链或公网发布检查；这些仍由各负责人独立验收。既有无新章来源时的跨书旧overlay行为没有扩大修复范围。
