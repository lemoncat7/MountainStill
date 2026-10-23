# v1.3.12-test.1 本地构建与载荷验证（2026-10-22）


这是整合试招、石灵提示和 round2 性能优化的**测试包**，不是首个正式稳定版。最坏同步逻辑 tick 仍不满足 33.3 ms 目标；不能把性能改善表述为正式性能达标。完整功能、原生 Linux 和性能实测由本轮整合 QA 记录提供。

## 最终导出

- Linux / Godot `4.6.3.stable.official.7d41c59c4`，使用此前匹配官方 SHA-512 的官方导出模板；重新完整导出，没有复用上一版本的应用包。
- GUI 定位音频退出残留后，整合版修复关窗生命周期与音频释放，`cultivation.gd` SHA-256 为 `ebf19da98e3218cb4b497d252ade06e99a83bfd36276f2a119bff411262dd729`。修前导出仅用于预验证，已失去最终交付资格；本文件对应修后重新导出和全新测试数据目录。随后全回归发现稀有掉落材料键问题，改为显式 String 键后再次重导、使用全新目录重测；最终 State SHA-256 为 `2d7df34d83bddf03f2c75d791a47b6bd44364d41724fb1d3a9f05b53791ee16d`。材料账本的严格校验未放宽。
- 62 份源码和 104 条依赖路径逐项存在、与当前源码一致。Windows PE AMD64、macOS Universal x86_64 + arm64、版本 1.3.12、可执行权限与 ad-hoc 资源结构通过。
- 两个平台的更新 PCK 均为 78287824 bytes，SHA-256 均为 `6dd53e378fa509e82eda299e1b290e4448a18046d215b9b32046e6a72a6eba3f`。内容平台无关，仍由 manifest 分别绑定 windows/macos；manifest 大小和 SHA 与实际文件匹配。

## 实际载荷与升级

- 从新 Windows EXE 和新 macOS app PCK 直接加载，使用空项目路径而非源码补依赖；每个平台 334 个活动资源全部加载，透明天空/人物落脚资源校验通过。新游戏启动标记为 1.3.12-test.1。
- 使用真实旧 1.3.9、1.3.10 公开包及本轮恢复的 1.3.11 包，两平台合计六种旧安装。每种先用旧 State 创建 schema 4 存档，使用旧 bootstrap 挂载实际新 PCK，再用全新进程二次启动，共十二次升级/重启验证。
- 原存档 herbs=777、dew=333、暂停设置保持；新版本存入 herbs=779，第二次启动正确读回。1.3.11 的非默认 frugal 战术与合法历史战报样本保留。旧 bootstrap/store 内容 hash 与 builtin 版本保持不变，ABI 1/schema 4 未改变。
- 十二次启动均实际启动试招并运行 20 个模拟 tick，结束后正式 State snapshot 和原存档 SHA 不变；正式保存不得在试招中写入。新脚本可实例化，更新 active journal 正确，pending/booting 正常清理。
- 两个更新 PCK 的 policy/guard 验证通过。两个新平台实际载荷均覆盖启动健康标记删除失败注入：预期退出码 1、唯一预期注入 ERROR、暂停并释放失败游戏断言通过。不能把这些预期 ERROR 当作普通正常启动。
- 正常载荷验证拒绝 SCRIPT ERROR、ERROR、ObjectDB 残留和 resources still in use；故障注入仅允许上面的预期错误。

- 两个实际平台载荷均执行稀有掉落专项：State 228 checks / 0 failures，真实 host 19 checks / 0 failures，覆盖真实拾取、容量重试和检查点流程。
- host 测试原本 extends `res://tests/test_battle_resource_host.gd`，测试文件按设计不在发行包内；仅把外部测试副本这一行换成同一测试 base 的绝对路径，断言字节不变。桥接 diff/base hash 与原始结果保存在 `docs/qa/quality-2026-10-22/build-validation/`。运行时仍只解析真实 main-pack，未使用源码补运行依赖。

## 交付与限制

七资产为 Windows ZIP、macOS ZIP、干净源码 ZIP、两平台 PCK、manifest、SHA256SUMS。最终打包核对 CRC、大小、SHA、源码逐文件一致性及敏感模式，排除缓存、临时存档、日志、凭据和旧构建。

上述载荷验证是 Linux Godot 加载实际导出内容，**不是原生 Windows/macOS 实机测试**；不宣称 Apple 公证、开发者签名或长期运行稳定性已经完成。更新包仍明确 `restart_required: true`，不是任意脚本无重启替换。公开提交与 Release 发布由主任务统一处理，本地构建流程本身没有执行公开操作。


## 最终整合 QA 与一小时循环验证

最终整合结果见 `docs/QUALITY-v1.3.12-INTEGRATION-QA.md` 及该文引用的 SOAK.md 原始证据。相同冻结运行时执行 3602.175 秒、1531 轮、21180 项检查，零失败、exit 0，前后 64 文件哈希一致。每轮重置夹具、每 10 轮重建宿主，因此这仅是 headless 生命周期/状态循环稳定性验证，不是自然连续游玩、完整通关或原生 Windows/macOS 长测。RSS 增长 12.016 MiB，末 15 分钟斜率 +0.03444 MiB/min；不能宣称零内存增长或无泄漏。

最坏 CPU 同步 tick 为 128.023 ms，仍未达到正式版 33.3 ms 门槛；两个既有节奏断言保留。故本轮交付仍为 **1.3.12-test.1 测试包**，不标记正式稳定版。
