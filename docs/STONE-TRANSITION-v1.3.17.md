# v1.3.17-test.1 石灵首领中段收势

新增 `creek_bridge_boss_retract.png`；全体旧 PNG 保留。仅 boss river_stone 的 recovery .20≤p<.34 使用retract，.34≤p<.78使用已有settle，之后idle。动作基础时长参数/伤害公式/RNG实现不变，实际轮廓会影响命中/避让/战斗结果。不是连续骨骼动画，头抬高仍略早。

原始生成PNG保存在 `assets/cultivation/beasts/sources/creek-bridge-boss-retract-original.png`。用内置image_gen对既有参考作忠实编辑，candidate01被独立拒绝，不进生产；candidate02针对右足膝髋中段收步修正后通过原生同尺度/步进初筛。技术导入仅矩形crop、单一等比LANCZOS和透明画布placement，无重绘/拉伸/alpha阈值修复；`tools/prepare_stone_retract.py`可逐字节复现运行PNG。

脚锚115,232来自左右足底中点的共同配准，非仅移动头部；`head_landmark`沿用脸/上身接触窗口语义，不是完整头壳量测。绘制与接触同pose、同rect、同像素源，提前预热新纹理与alpha缓存。所有3个export preset显式包含新PNG，导出审计需强制加载并验证其256²尺寸及脚锚。

保留更新schema4/ABI1、v16不可变更新器边界、正式/测试频道、透明桌面与等比渲染。最新验证与限制见 BUILD_VERIFICATION.md；本文件不能替代实际发布或实包回执。

## 候选A被否决，B前移收势

初版A把retract放在原settle时段，导致真实追击前摇级联变化，正式boss≤35秒的85%门槛从54/60降至50/60，不发布。B仅将短中段帧提前替换recovery早段attack：charge/sweep约.084秒、burst约.0798秒，不改动作基础时长参数/伤害公式/RNG实现，也不在不可见段预留retract轮廓。B正式earned重获54/60，仅保留既有两条summit剑式失败。真实低余量carry12组双方全过，守标准/低经脉余血57/28维持，火低经脉1→15，不能宣称战斗完全等价。

轮廓仍会通过真实追击规划改变前摇与战斗时序，不宣称实际总战斗时间不变。B 300对固定earned快照种子双方全胜，无非法接触伤害/超时；剑/火/守平均余血变化+.18/+.09/−.28，守最低47→45、个体−11..+7，不能推广为所有种子或自然流程完全等价。
