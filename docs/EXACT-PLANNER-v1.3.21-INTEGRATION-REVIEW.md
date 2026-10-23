# MountainStill v1.3.21-test.1 — 独立集成审查

审查时间：2026-10-23 18:07 UTC。审查者：`/root/review_exact_planner_integration`。
候选：`exact-planner-v1321`；本地 main mirror：`browser-publish-source`，HEAD `e367bea61f9d5d5def932bbe479932c500b6c6fe`。

## 结论

**本次源码集成与已冻结专项未发现 blocking；可继续既定构建/完整回归/GUI/实际载荷验证。此结论不是发布完成、原生平台通过或正式性能验收通过。**

本审查未修改任何 runtime、测试、版本文件或发布仓库，也未运行 GUI/性能基准。仅独立执行一个 focused Godot correctness entry、release-file-policy 回归，以及只读源码/清单/历史原始证据复核。

## 1. 来源及最小改动核对

- 两个集成 runtime 与研究 `branch-bound-shadow/candidate` 最终冻结字节一致：
  - `scripts/melee_contact_geometry.gd`：`22f6d2e77daa089f14eed6bd4982c89561193f42aac485201beb704464b15752`
  - `scripts/duel_timeline.gd`：`c71e5419b10010fc2b3225e515fc8c448676475e7d0b6dce18a9398b9b5432f9`
- 研究 baseline 的所有 `.gd` runtime 与当前 main mirror scripts 逐文件相同，无漏项。候选相对研究 candidate scripts 仅另有 `update_service.gd` / `update_store.gd` 的必要版本值差异。
- 九个版本文件的 diff 均仅 `1.3.20`→`1.3.21`（future fixture 相应 `test.2`）；无 save schema、bootstrap ABI、命名空间或 updater 行为改动。
- main tracked 文件未丢失；所有 tracked `assets/` 字节未改。导出资源集合未变，export presets 仅平台版本元数据变更。
- 当前源码未加入 GDExtension 或研究动态库。native 工作流/诊断工具的保留不代表加入 native runtime 依赖。

证据：`research-source-ancestry.json`、`static-preservation.json`。

## 2. API / 规划边界审查

- `fit_approach` 新尾参数 `trusted_planning_samples` 默认 `false`；短路条件保证旧四/五参数调用不进入 eligibility 扫描/剪枝，保留完整旧枚举与 samples 写入语义。
- runtime 仅两处 `true`，均位于 `_plan_melee_approach`（Duel 1276 / 1295），共用函数入口局部新建的 `planning_samples`；未将 samples 放入 action 或回调参数对外发布。
- exact builtin Script 身份同时约束 pose/strike provider，子类/未知 provider 不放宽；Object 在 `get_script()` 前检验有效性；递归/非有限/不支持值 fail open。
- 原候选序、首个 neutral 特殊早返、严格 `<` 胜出、原 cost 左结合浮点运算均保留。LB0/LB1 只在有限 incumbent/bound 下跳过不能严格胜出的候选；首个 neutral 不可被跳过。
- `_clearance_sources` 仍在枚举前执行。研究的 missing-image 首次缓存填充风险没有被删除或换算法：这些相关函数与研究最终源相同；没有将缓存字节/淘汰顺序误称一致。
- `true` 是内部 ownership 契约，不是对恶意 external code 或污染 samples 的安全边界；新增 provider/call graph/调用点必须重新审查。

独立阅读了研究 `PROOF_REVIEW.md`、`FINAL_REVIEW.md`、README 的前提和限制，未将它们当作本轮包验证。

## 3. 自包含专项：独立运行结果及真实覆盖

命令（独立 HOME/XDG，官方 Godot 4.6.3）：

```
godot --headless --path exact-planner-v1321 --script res://tests/test_exact_planner_guard.gd
```

**217 checks / 0 failures；32 neutral early-return observations；2 finite equal-cost observations；exit 0。** `guard.log` 中无 `ERROR` / `SCRIPT ERROR` / leak 诊断。
`python exact-planner-v1321/tools/release_file_policy.py`：PASS。

测试冻结 SHA：
- `test_exact_planner_guard.gd`：`db3a955919b3878ec689468eea1c27efeaf1dc980785a6448f664c491c985fe1`
- `exact_planner_custom_fan.gd`：`01e8f914ff2b822c1e4e497b2698b209963d086a518e08c9987cf1299a7be319`

已检查测试自身不是只比较同一函数两次：oracle 保留原 fit 枚举体，调用实际产品 measure/separate/rig/artwork；不加载研究替代 runtime。测试覆盖 default/explicit-false 结果与完整 samples 字节相等、builtin eligibility、trusted fresh/warm samples 结果、三种 builtin、signed-zero origins、nonfinite fallback、custom subclass callback count、污染 external samples、深/循环/未知/释放 Object guard，以及真实 neutral early return。

明确限制：
- finite ±0.2 tie 是实际产品 geometry + 手工 external pose-cache fixture，验证 public default/false 的先负 aim 留存；**不是** trusted-path 污染样本安全证明，也不是本轮动态触发 LB==best 的完整证明。
- fresh/cold 仅指局部 planning samples。oracle 先运行会预热 G 静态 source/pixel 缓存，不是全局 cold-cache 独立基线。
- 本轮专项未重新动态覆盖 missing-art / pose/pixel/front eviction；这些仍是冻结研究测试的证据，不能重标成本轮执行。
- 无效 provider 的若干用例只测 guard，未调用不合法旧 API 几何路径；fail open 不等于任意非法输入不会产生旧错误。
- 外部 fixture 按自身路径加载 sibling，并引用产品 `res://scripts`，设计上支持挂实际 PCK；**实际 PCK 执行在本报告时尚待 builder 完成。**

审查发现初版 tie 计数为零、缺少 warm reuse，已在冻结前反馈作者；最终补入上述可实测有限 tie 与 fresh/warm 检查。没有为补测试修改 runtime。

## 4. 最新 48 项 native 工具保全 / 源打包

- 当前 main 48 项 workflow/doc/test/tool 逐字节全部保留（48/48）；CI pins 未随版本盲改。
- 独立运行 `package_source.py --dry-run`：main allowlist 仅含其中 14 项；候选包含 48 项。新增显式清单是实际修复遗漏，不是无关 native 实验集成。
- 首次检查候选清单 1,239 个源文件；测试/文档新增会使最终数量变化，因此不能把此数字当作最终 ZIP 文件数。
- 检查清单没有 private/build/cache 目录或 `.gdextension/.dll/.so/.dylib` 实验库路径。对清单内 561 个文本文件做常见 GitHub/OpenAI/AWS credential/private-key 特征扫描，无匹配；这不是通用秘密检测证明。
- 当前只有 dry-run 清单验证，**尚未在本审查中检查最终 Source ZIP 字节/CRC/最终 native 48 文件**。builder 必须对最终归档再次校验并确保不混入 isolated HOME/XDG、日志、save、缓存。

证据：`package-dryrun.txt`、`baseline-package-dryrun.txt`、`static-preservation.json`、`release-file-policy.log`。

## 5. 研究原始证据重新核算（非重新跑性能）

读取 12 份 `final-bench-*` JSON：B 源 SHA 均对应本轮冻结文件；每个场景 12 个 measured state 记录相同。重新 SHA 核对三场景完整 baseline/candidate trace 文件及 72 场景 matrix 均成对相同。结果见 `research-evidence-recheck.json`。

| 场景 | A worst ms A1/A2 | B worst ms B1/B2 | pooled per-trial p95 A→B ms | median total A→B ms |
|---|---:|---:|---:|---:|
| 竹关/剑 | 51.329 / 63.736 | 53.398 / 63.548 | 2.856 → 3.081 | 874.762 → 857.794 |
| 云坡/空手 | 69.492 / 67.922 | 68.998 / 62.954 | 3.8125 → 4.0495 | 1140.270 → 1089.264 |
| 云坡/扇 | 105.637 / 118.497 | 53.776 / 55.787 | 4.248 → 4.485 | 1206.732 → 1190.210 |

云坡扇最坏 CPU tick 约减半，非全程速度翻倍；p95 有 +0.225–0.237 ms 观测增加，整场总时间下降幅度较小。其它场景没有稳健普遍峰值改善结论。**全部 B worst 仍超过 33.3 ms 正式门槛。** ABBA 是共享环境 headless CPU、每块三 measured trials，不是 GUI/GPU/帧率或跨硬件统计保证。

候选现有新增说明保留这些限制，未发现“全面无回退”的错误声明。

## 6. 未验项 / 交接条件

本报告不覆盖完整回归、已知节奏断言复现、长时稳定性、真实 GUI、Windows/macOS 执行、导出后的实际脚本身份/资源依赖、最终 Source ZIP、实际 PCK、旧安装更新/存档/重启/回滚、远端 commit/release 及下载后 hash。由对应作者/build/platform 工作流完成，不可用历史 v20 CI pins 冒充 v21通过。

无权限拒绝或待用户批准；没有需要修改 runtime 才能继续的 blocker。后续若两冻结 runtime 或调用边界改变，当前研究性能归因和本审查源码结论需重新核验。
