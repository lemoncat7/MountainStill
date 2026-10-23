# 石灵守壳 / 露隙可读性候选（未发布）

基于已冻结 practice-candidate，独立于 performance-candidate。

只添加名牌右侧局部纸底14px「守壳 / 露隙」短标记，以及石灵身侧3枚紧收/松开的局部石纹。读取 DuelTimeline.pose().mechanic；无独立计时，无动作阶段推断。第一起招以引擎真实 river_exposed 显示。既有 tide 弧线及全部PNG不变。

同一普通战斗 / 试招渲染路径；战斗结束、取消、气血归零、拾取及退出时隐藏。暂停不增加视觉时钟。不修改伤害、防御倍率、RNG、事件、招式、碰撞、存档 schema 或 bootstrap ABI。

## 已验证

- 新状态测试及独立重跑：3,239 checks，0 failures。
- 180场固定seed / 10,798事件、完整战报、elapsed、victory与冻结practice-candidate完全一致。
- 五项试招回归：4,716 checks，0 failures。
- Linux原生GUI独立验收：1200×400条带、960×540最小窗、1340×880宽窗；暗终端/白编辑器桌面透明合成；普通/首领两种状态、暂停约25秒、普通战斗和实际尸体隐藏、试招结束/退出；15张证据截图。

## 限制

此文档不是发行资格证明。GUI角色无兵器，不能宣称所有兵器动画已覆盖。普通尸体阶段Alt+F4仍有ObjectDB/1 resource退出警告，与practice原有日志相同，未修复。未重跑完整测试套件，旧pacing失败不在本轮修复范围。Windows/macOS原生、高DPI、长时性能未测；此前模型3帧/恢复硬切问题未解决。性能分支未合入；不对其改善作声明。
