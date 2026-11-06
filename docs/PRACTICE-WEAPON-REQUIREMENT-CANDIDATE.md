# 暂停出招缘由：明确所需兵器

## 来源与范围

- 基于完整公开源码 `MountainStill-v1.3.35-test.1-Public-Source.zip`，SHA-256：`50f8850cb6f608bb224310869573ce3afab914c27bb2888e81d627269f13d4d8`。
- 2026-11-05 独立复制后修改，原冻结源码未改。此目录为完整源码候选，沿用基础工程版本信息，不冒充新发布版。尚未上传 GitHub，也未重新构建 Windows/macOS 安装包。
- 运行差异只有 `scripts/practice_pages.gd` 的 `weapon_mismatch` 显示映射一行：真实内容 ID `weapon_sword` →「持剑」、`weapon_fan` →「持扇」；保留 `sword` / `fan` 兼容别名，空、缺失及未知值仍为「相配兵器」。短行和悬停说明共用已有 formatter。
- 没有新运行依赖，69 个运行脚本及原有导出列表不增加。实际 `_hero_action`、`skill_decision_snapshot`、全部战术、平衡数据、原有测试及其门槛保持原字节。素材、字体、透明窗口、人物比例、存档 schema 4、Bootstrap ABI 1 与更新交易不变。

## 新增回归

`tests/test_practice_weapon_requirement.gd`（及其 Godot UID）在 Linux Godot 4.6.3 检查：

- 两个真实 ID、两个历史别名、空值、缺失、未知字符串、近似误匹配字符串、null 和数字的安全兜底。
- 精确短文案与提示首行，输入字典只读，其他原因不变。
- 真实 host 与真实 Content 定义：空手、持剑、持扇三种合成搭配，各自在 960×320 和 960×540 暂停并打开实际控件，检查真实 snapshot、显示缓存、tooltip、已有字号与列宽。
- 打开/重建/返回/取消不改正式存档、正式 RNG、战斗状态、待处理事件、已起手动作或奖励记录。

131 检查、0 失败。相同测试先在原运行实现上执行为 131 检查、20 失败，全部是预期的两种新 ID 文案缺失。测试编写期曾有一次 GDScript 局部变量推断错误，随后只为测试变量补充 bool 类型；该失败日志也保留，不计为通过。

复现：先在隔离 HOME/XDG 下运行 Godot 4.6.3 `--headless --editor --import`，再运行 `--headless --path <工程> --script res://tests/test_practice_weapon_requirement.gd`。

## 验证边界

这是显示修正，不是性能优化，不声称 FPS、GPU、音频、长时间稳定性或无泄漏提升。全部新增代码只在原有手动打开纸页的格式化路径执行，不新增逐帧探针。源码完整回归与性能观察由另附证据报告列出，不把历史通过状态当成本轮结果。

旧版已知 `test_encounter_balance.gd` 两条剑式 summit_gate/gate_sentinel 报告为 6.8161 秒，低于不变的 7 秒下限（奖励种子 20261020、61，共用战斗种子 8039）。本候选不更改相关逻辑或阈值；只有重新运行证据才代表本轮观察。

Windows/macOS 原生执行、透明合成、DPI、GPU、音频、关闭、签名/公证和长期稳定性未验证。Windows 黑底未证实修复。未创建此候选的新平台包，不得将旧安装包冒充包含本修正。
