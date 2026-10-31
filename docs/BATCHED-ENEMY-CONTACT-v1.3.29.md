# v1.3.29-test.1 敌方接触批量采样候选

日期：2026-10-31。范围仅 `melee_contact_geometry.gd` 的 `body_fronts` 帮助方法，以及 `duel_timeline.gd` 的同次接触采样调用。不新增持久缓存，不改变各点 `_front_at_y` 算式、比较/归约顺序、伤害、时序、奖励或存档。现有 runtime 文件已在资源导出列表内，不新增运行时文件。测试中的 scalar fixture 仅用于等价对照，不能导入发布 PCK。

## 已取得的局部证据

- 专项和独立复核各 184187 检查、0 失败，含边界/碰撞采样及六章普通/首领逐 tick 对照。
- 两轮独立完整 ABBA：每轮三场景 × A1-B1-B2-A2 ×（一次 warmup + 三次测量），每场 480 ticks、seed 377。总计 24 warmup、72 测量 duel；每轮每场每 arm 另有两次冷/热语义对照。
- 所有逐 tick 状态、事件、完整 trace/event digest 精确匹配；无删样或筛选失败重试。
- 以下是每轮各 arm 的中位数，不是显著性检验，也不是每帧保证。

|轮次|场景|总耗时变化|tick p95 变化|峰值变化|
|---|---|---:|---:|---:|
|1|bamboo_pass / sword|-2.14%|-13.53%|+1.04%|
|1|cloud_slope / unarmed|-1.94%|-13.55%|-0.85%|
|1|cloud_slope / fan|-2.46%|-12.37%|-0.34%|
|2|bamboo_pass / sword|-5.01%|-12.44%|-5.54%|
|2|cloud_slope / unarmed|+0.56%|-10.34%|+1.00%|
|2|cloud_slope / fan|-2.97%|-11.24%|-0.96%|

p95 改善约 10–14% 在两轮三场景重复出现；总耗时和峰值不是全面改善，徒手第二轮总耗时反向 +0.56%。全部报告的中位 trial 峰值仍超过 33.3ms，不宣称解决开招峰值预算。增加一个 Array[Dictionary] 并保留同次 N 个 front 字典，减少 N−1 次 `_body_data` 字典及重复输入转换；并非无分配方案。retained memory / Object 监控不等于分配计数或无泄漏证明。

## 保持和待验事项

存档 schema 4、Bootstrap ABI 1、Windows ANGLE 优先/OpenGL 备用不变。合法旧 active 内容继续优先，不自动清除旧更新。Windows 黑底没有实机复现或已修复结论。原基线 encounter_balance 4474 检查 / 2 条剑式 summit 节奏失败保留。

本文件写于版本冻结/构建前：最终同字节全量回归、实际完整包/双 PCK 结构与运行、目标 Windows/macOS 原生证据仍待补充。历史成功不算本轮通过。以上 CPU 结果仅是同机 Linux headless 固定场景；不代表原生 GUI、GPU/FPS、声音、用户设备或自然长测。Windows 未签名，macOS ad-hoc、无 Developer ID/公证；不关闭系统防护。
