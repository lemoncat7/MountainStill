# MountainStill v1.3.20 控场反馈独立源码审查

## 结论

**当前候选未发现阻断本次功能的缺陷，可进入后续 GUI、完整回归及实际发行载荷门禁；这不是发布或全平台通过结论。** 本审查只读候选，所有测试脚本和日志在独立 QA 目录，未改候选源码。

最终独立测试 39 组、27,188 检查、0 失败：相对 v19 的 2,965 条完整返回事件、3,840 个推进步骤，以及状态、资源、RNG、旧战报字段和语义姿态均一致。正式宿主完成、暂停、重试及取消后，State 全快照、正式 Duel 引用、三套正式 RNG 状态及已落盘存档的原始字节保持不变。

初审提出的唯一文案遗漏已由作者修复并复核：霜滞起手可能随后中断，两指标可重叠。当前说明还明确中断包括收势，不等于破势次数、避免命中或节省秒数。

## 精确版本边界

- 候选：`control-feedback-v1320`；基线：`chapter-practice-v1319`。
- 作者最终 70 文件冻结清单 SHA256：`cf2740f50c34a788462bed6a286c190d37cce64648e634c25473368e90163bca`，本审查逐项重新计算全匹配。
- `practice_session.gd`：`61435f595461d941125768db701c3df5f00637b29ecfafc562266a0f2f125101`。
- `practice_pages.gd`：`0ff49bb70745dbf98bf228ce25254687c774d021c359c29ff04fb9a529e889af`。
- Godot：`4.6.3.stable.official.7d41c59c4`，Linux headless，独立 XDG 数据目录，不操作真实玩家存档。
- 独立 live GitHub `fetch_file` 按精确 commit `04d556e51d8c86ef5c02c37d146bbb143527cc9d` 获取 14 个 CI 文件的 Git blob SHA；候选全部逐字节匹配。见 `remote-ci14.json`。这只证明 CI 源文件保留，不证明这些工作流已对 v20 执行。

## 源码边界

`scripts/` 相对 v19 只有四个文件不同：两项控场实现，以及 `update_service.gd`、`update_store.gd` 的版本常量。其余差异为版本配置、说明、定向测试和指定最新 CI/打包工具。

`duel_timeline.gd`、`combat_report.gd`、`cultivation_state.gd`、`practice_host.gd` 和 `cultivation.gd` 完全相同；464 个既有资产逐字节相同，无新增/缺失资产。未混入 native 几何或 authored 实验的运行时代码/资产。实际导出包成员仍须构建门禁另验。

- `practice_session.gd:43–53`：先调用原 `duel.advance`，再只读归约同批返回事件，最后冻结胜/负/超时报告。终局同批不丢失；超时追加既有 `practice_timeout` 事件，不改引擎输出。
- `practice_session.gd:56–65`：只认 enemy `turn_started.slowed`，以 action_id 去重；只认 hero→enemy `poise_break.interrupted`，以 contact_id 去重。普通 contact 的 poise_broken、空闲/未中断破势、对方造成的破势不冒充收益。
- 启动先清空两张观察字典；取消和终局冻结；已结束后 observer/advance 不能再累加。报告保持深拷贝。
- 新字段只加到 PracticeSession 返回的临时副本。正式 CombatReport schema、State schema4、存档及 RNG 不扩展。
- `practice_pages.gd:57–68`：必须有版本 1 和两个完整、有限、非负整数数值才显示；缺字段、旧记录、错误版本、异常数字显示“未记录”，不是捏造零。真实测量零仍为零。说明不推导节省秒数或胜率。

## 独立运行覆盖

主脚本 `independent_review.gd` 不调用作者新增测试中的 reduction；单独载入 v19 原 PracticeSession 与 v20 PracticeSession。二者引用的战斗引擎已由字节审计证明相同。

1. 18 个 canonical 敌人 × basic/control 两种明确合成英雄，共 36 场固定 seed17、0.2 秒推进。control 复制未改动的 Content frost/thunder 定义；合成属性不冒充合法成长或平衡结论。
2. 另验 seed42 一次 120 秒调用整场胜利、一批败北、1000 秒调用截断到 120 秒真实超时，共 39 组：37 胜、1 败、1 超时。
3. 每批严格对比完整事件序列；每步精确对比 RNG state、status、battle resources、剔除仅三个新字段后的完整报告、全量语义姿态。独立事件归约再核对控场数；冻结后 cancel/pause/resume/advance 不改报告，重试清零。
4. 合成边界覆盖 20 次重复事件批、空闲破势、敌方破势、contact-only 假破势、暂停/非法 delta、取消后再次 observer、无效重启、旧/部分报告缺字段及真实零。
5. 宿主真实 `main.tscn` 的自动化运行：完成→同敌重试→退出、进行中取消、暂停/恢复、保存拦截、正式资源和战报写入防护。每段比对整个正式 State（仅除时间戳 saved_at）、adventure RNG、journey RNG、正式 Duel RNG；正式引擎对象恢复；原存档 bytes 未变化。

完整事件、每步 RNG/HP/资源和宿主前后快照保存于 `full-evidence.json`。事件的 Vector 等值在 JSON 中为可读字符串；相等断言是在原运行时 Variant 和原 JSON 事件批上执行，不依赖事后解析的浮点容差。

### 真实引擎语义证据

额外 `phase_probe.gd` 以 0.05 秒推进 summit boss 的同样合成 basic/control 夹具，抓取原引擎 `_lanes` 的 frozen_phase，仅观察不修改：

- 收势中断：basic，4.490429 秒，hero contact `6:0`，enemy action4，`frozen_phase.name=recovery`、进度0.903374；统计中断1。敌动作已在收势，不能据此说避免命中。
- 空闲破势不计中断：control，5.057516 秒，hero contact `6:0`，enemy lane 为空、`interrupted=false`，此时中断数仍0。
- 对方造成破势不算我方收益：basic，6.610429 秒，enemy contact `7:1`，目标为 hero；我方中断仍1。
- 霜滞起手随后中断：control，27.201448 秒，hero contact `35:0`，enemy action32 保持 `slowed=true`，在 recovery 进度0.734783被中断。证明两项确可重叠。

主39组轨迹合计49个霜滞起手、163次实际中断；26次中断发生在先前已标慢的敌动作上；18个 hero 非中断破势和55个 enemy 破势不计入我方中断。这些是夹具事件计数，不是玩法收益排序。

## 测试夹具修正记录

首轮对 pose 使用原生对象相等，得到 3,840 条姿态失败，其余23,348检查通过。独立 diagnostic 定位到各 Duel 独立分配的 `weapon_unarmed.gd` provider RefCounted 对象 ID 不同，数值动作未见差异。直接比较不同会话的对象身份并不适合作为行为等价判断。

未删失败证据：`initial-exact-variant-comparison.gd/.log/.exit`、`initial-evidence.json` 和两份 `pose-diagnostic*.log` 全部保留。只修外部测试为递归比较每个 provider 的脚本路径、class 和全部 script-variable 状态，以及姿态所有其他字段；随后完整39组重新执行，27,188/0。不是修改产品或跳过姿态比较。

## 尚未覆盖及交接要求

- 未做任何 GUI/像素验收，尤其新增第四行 tooltip、长数值与小窗/125%字体布局须独立 GUI 检验。
- 未在本审查重跑全量 GDScript、旧包混合升级、Windows/macOS 真正包或原生 OS；由现有门禁继续，不可用本报告替代。
- 未做性能评估，不宣称解决既有 native 性能边界或历史两条节奏断言。
- 本审查未推送、发布或更改仓库。授权发布不代替这些未完成的质量门禁。
- 请实现者把本审查 QA ZIP 与作者证据合并到统一 Library QA，保留初失败诊断，更新审查完成状态但保持未执行门禁为待完成。

## 复现

在同一工作区（脚本固定 baseline/output 的绝对路径）运行：

```sh
ROOT=/workspace/scratch/778a2592935f
export XDG_DATA_HOME="$ROOT/control-feedback-independent-review/user/data"
export XDG_CONFIG_HOME="$ROOT/control-feedback-independent-review/user/config"
export XDG_CACHE_HOME="$ROOT/control-feedback-independent-review/user/cache"
godot --headless --path "$ROOT/control-feedback-v1320" \
  --script "$ROOT/control-feedback-independent-review/independent_review.gd"
godot --headless --path "$ROOT/control-feedback-v1320" \
  --script "$ROOT/control-feedback-independent-review/phase_probe.gd"
```

两个最终 exit 均0。主测试日志 `independent.log`，phase日志 `phase-probe.log`；完整最终源冻结核对 `final-reviewed-hashes.json`；scope diff `source-scope-audit.json`。统一归档不包含 user 目录、.godot 或用户真实数据。
