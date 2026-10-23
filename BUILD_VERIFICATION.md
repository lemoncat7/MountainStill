# v1.3.13-test.1 换装比较：构建验证

本轮为测试包，不是已达到正式性能门槛的稳定版。功能范围见 [换装比较说明](docs/EQUIPMENT-COMPARISON-v1.3.13.md)。

## 本轮全新导出

2026-10-23 在 Linux / Godot 4.6.3.stable.official.7d41c59c4 使用此前已核对官方 SHA-512 的官方模板完整重导。首次候选随后因小数显示修复作废，最终载荷包含微增/微降及装备吐纳35%上限说明：equipment_comparison_pages.gd SHA-256 `ab8cd40ff8a52c70bfc563de4e23d997a42bf18b9d80b4a17a2438f5f0a17ae5`。未复用旧应用产物。

- 运行时/项目/导出与入口场景共66文件在构建前后逐哈希一致。
- 导出依赖核对63源码文件、105依赖路径均存在并与当前源码一致。
- Windows PE AMD64、macOS Universal x86_64/arm64、版本1.3.13、可执行权限与ad-hoc资源结构通过。
- 两PCK均为78300384 bytes，SHA-256 `ce299ccc96bad5a0f9fc69e258825a4c6858d3954f516433a31724eec889d8d2`；manifest分别绑定平台，实际大小/哈希及policy/guard通过。

## 实际发行载荷测试

使用空项目目录，从新Windows EXE和macOS app内实际PCK加载，不以源码补运行依赖。两平台各334资源审计项通过；各运行装备状态153、UI12166、重绘缓存5项，全部零失败。满行箧开页计算一次、180次实际CanvasItem重绘不重复计算、显式翻页计算一次；仅为Linux headless观察，不是原生GPU或帧预算保证。

两平台各通过宝物状态228、真实host19项；外部host测试仅把extends改为同一测试base绝对路径以保持测试文件不进入PCK，断言不变、diff/base哈希留证。两实际载荷各通过启动健康标记删除失败注入：预期exit1且只允许明确的注入ERROR，失败游戏暂停/释放。正常路径不允许SCRIPT ERROR、ERROR、ObjectDB/资源退出残留。

## 真实旧安装升级与存档

实际公开1.3.10、已发布1.3.12的Windows/macOS包合计四种旧安装，分别以旧State创建schema4存档，经旧不可变bootstrap挂载本轮真实PCK，并再次启动，共8次升级/重启验证。旧bootstrap/store字节和builtin版本不变，ABI1/schema4保留。

herbs777、dew333、暂停设置与完整gear账本保留；新版本写入herbs779后重启读回。1.3.12非默认frugal战术及合法战报保留；1.3.10缺战术字段，正确迁移balanced。每次实际执行试招20 ticks并结束，正式State快照/存档SHA不变，试招保存被拒绝。active健康提交且pending/booting清除。

## 发行边界

七资产包括两平台完整ZIP、干净源码ZIP、两PCK、manifest和SHA256SUMS。共用发行过滤规则排除cache/fontconfig、isolated目录、日志、用户数据与凭据类型；合法windup-isolated美术原图保留。最终必须审查每个ZIP成员（包括二进制），核对CRC、大小、SHA、源文件一致性及敏感模式。

上述不是原生Windows/macOS测试，不宣称Apple公证或开发者签名。包更新仍需重启，不是任意脚本无重启替换。本轮没有重新做一小时soak或正式CPU/GPU性能验收；上版128.023ms最坏同步tick及既有两项节奏断言不能被本次UI功能解决，不能沿用上版长测冒充本轮证据。


## 整合与原生界面证据分层

本轮整合回归、180场/10798事件基线对照及原生界面证据见 [本轮QA](docs/QA-v1.3.13-COMPARISON.md)。100入口中99成功，既有节奏2断言保留；微差最终显示版另以实际载荷UI12166/cache5验证。原生Linux主13图/战斗锁/34页为显示修正前候选；仅吐纳微差与装备35%说明修订后，最终ab8cd40…ae5版追加2图原生960页2验证。不能把全部13图说成最终hash拍摄，也不能外推原生Windows/macOS或真实音频设备验收。
