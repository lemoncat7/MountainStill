# 连续交锋验证：当前结果与历史录像边界

## 2026-11-23：修复过时的 QA 准备流程，不发布新包

v1.3.43 游戏代码未改。旧准备器在新档默认手动成长下没有调用突破，赢完青竹关后仍为境界0，因而正确被听泉桥的境界1门槛拦住。正式修行页已有明确的手动突破按钮；首通奖励不会代玩家突破。修复准备器逐阶支付真实灵气/灵草，必要时真实采药或静坐，并记录目标、路线和扣费。奖励使用正式尸体搜寻接口，检查提前搜寻与重复领取均不付款。心法已装备时不重复要求切换报价。

本轮准备两条各9战的路线，18战均胜利，6次突破逐次扣费、两份存档有效。准备过程通过生产 State/Duel API 推进，**不是从新档开始的全程 UI 录像**。现有完整手动旅程经济/存档测试1613项通过；另有39个真实指针目标的2475项检查通过，均为Linux headless，不等于原生GUI。

显式 `--headless-audit` 只记录正式 host 的连续事件和姿态，不等待绘制完成、不写截图。两场原生气血首领均胜利，记录123个事件、2517个姿态采样，源文件运行前后一致且time_scale=1。总模拟片段43.4333秒；各场13.70/28.25秒。伤害/气血守恒、反击因果、三种普攻和敌方动作检查通过，**旧50–90秒录像时长断言仍失败（分析器exit1）**，未放宽以制造全绿。固定60步长不是实时性能成绩。

分析器新增空场次、错误目标顺序、缺事件/姿态与headless标记矛盾的拒绝检查；四项空证据/标记专项通过。历史两条剑节奏断言原文件未改，本轮没有重复跑该未改动的平衡测试。Windows/macOS原生安装、绘制、音频、透明度、GPU和长期混合负载仍未验收。无需为这些工具修复更换v1.3.43正式包。

复现命令（先将三个XDG目录设置为本机可写、隔离目录；输出路径亦由消费方自行选择）：

```sh
godot --headless --path . --script tests/prepare_continuous_combat_demo.gd -- \
  --output=/tmp/mountain-current/checkpoints
godot --headless --fixed-fps 60 --path . --script tests/show_continuous_combat_demo.gd -- \
  --demo --headless-audit --checkpoints=/tmp/mountain-current/checkpoints \
  --output=/tmp/mountain-current/events
python3 tools/qa_analyze_continuous_capture.py \
  /tmp/mountain-current/events/continuous-combat-events.json \
  --output=/tmp/mountain-current/analysis.json
```

下方59.900秒图形片段、56秒采集/22秒切换及旧三条平衡失败均为**此前历史记录**，不得归给本轮源码或现行包。当前准备可能已正常装备止水，故本次切换成本为零；这不等于游戏免除了原有学习或切换成本。

---

# 历史连续交锋记录（不是 2026-11-23 的验收）

本轮 QA 使用两个连续实战片段，不延长首领气血，不强制格挡、闪避、命中、反击或胜利。每场由正式 `cultivation.gd` 主循环、`DuelTimeline` 和正式绘制／声音代码推进。两个片段之间停留 0.75 秒；每场内部不剪辑、不重排事件，不修改 `Engine.time_scale`。

## 可复现准备

```sh
mkdir -p /tmp/mountain-continuous/checkpoints /tmp/mountain-continuous/capture
# 在受限环境中，将 XDG_DATA_HOME / XDG_CONFIG_HOME / XDG_CACHE_HOME 指向可写隔离目录。
godot --headless --path . --script tests/prepare_continuous_combat_demo.gd -- \
  --output=/tmp/mountain-continuous/checkpoints
# 第二条命令必须从真正有图形显示的桌面终端运行；不要加 --headless。
godot --path . --audio-driver Dummy --script tests/show_continuous_combat_demo.gd \
  --write-movie /tmp/mountain-continuous/capture/continuous.avi --fixed-fps 60 -- \
  --demo --checkpoints=/tmp/mountain-continuous/checkpoints \
  --output=/tmp/mountain-continuous/capture
```

`--fixed-fps 60` 保持输出片段的模拟步长与播放速度，不是实时渲染性能成绩。Movie Maker 仍从正式音频混音器写出音轨；工具可检查音轨、响度和削波，但不能据此声称已经人耳试听完整片段。

准备器从新档开始，通过正式战斗与首通奖励完成前两章，支付真实研习成本和计时。止水已学会但切换缺少灵草时，使用实际采集活动补足，然后支付报价并等待调息计时。基线所需补采为 56 秒，切换另需 22 秒，实际支付 9 灵草、3 晨露、116 灵气。没有直接赋值资源、功法等级、装备、境界或胜场。

## 主片段配装

- 已赢得的青锋剑
- 止水内功心法
- 唯一主动栏：护元诀
- 武式与辅修栏正常卸下，保留剑自带的破风刺
- 青苔兽王：原生 220 气血，前两章之后重游青竹关
- 白羽鹤王：原生 550 气血，第三章首次挑战

两场都保留同一段山路前两场战斗后的气血、真气与各技能冷却。准备器保存经过校验的存档，并另存场地、剩余气血、出招种子和完整获得过程。录制器从这些明确标识的复现场地切入正式战斗；它没有把片段描述为从新档开始的完整无剪辑旅程。

## 记录与验收

输出 `continuous-combat-events.json` 包含：

- 全部正式引擎事件，包括出招、接触、破势、结束事件
- 每帧动作阶段、局部停顿、双方姿态和气血
- 两场的起止时间、正式战斗时间、实际配装与资源
- 录制前后源文件一致性与 `Engine.time_scale`

运行时的 `RefCounted` 姿态／攻击提供者不写入 JSON。只保存可复查的值数据。

应逐项检查：两个原生首领真正获胜；伤害与气血增减相等；三种剑普攻和双方各三种怪物动作出现；唯一主动按成本与冷却施放；止水反击能回溯至真实格挡接触；动作衔接与恢复过程在密集帧中连续。画面必须保留已接受的侧身头身比例、短颈和实物兵器接触；行囊独立悬浮兵器另由原有回归测试保护。

## 已知基线范围

独立复跑原始平衡测试得到 4522 项检查、3 项失败，180 场均胜利。失败仍为两个种子的辅助流白羽鹤王 42.3868 秒略超 42 秒上限，以及 60 场首领中仅 50 场在 35 秒内（83.33%，要求 85%）。本验证没有放宽这些断言，也不将其称为全绿。

普通归息心法旧版对照片段已实际录制：69.0333 秒、1200×320、60fps。它覆盖自然格挡，但没有玩家闪避／反击，因此不能替代本轮止水反击片段。连续音画的主观观感仍需人类完整播放验收；自动记录与密集帧检查不能冒充完整观看／试听。

## 本轮已完成的图形记录

首轮整合候选片段为 59.900 秒、1200×320、60fps，含 H.264 画面与 AAC 音轨。青苔兽王实机片段 13.9333 秒、白羽鹤王 44.4167 秒，两场都正常胜利；气血分别从 111 到 110、107 到 83。全片保留 37 次免费剑普攻（三形齐全）、5 次护元、5 次剑自带技、六种怪物攻击形态、26 次真实格挡、1 次零伤害闪避、22 次可追溯格挡接触的反击与 9 次破势。

18.30–19.30 秒的 60 帧接触复核使用正式的角色实心头部轮廓、受击前保留身体包络和怪物实心轮廓，最小头部间隙约 3.000 像素；独立重算与原记录之差小于 0.000016 像素。18.5167 秒格挡的接触间隙为 4.4896 像素，在原定 16 像素触达范围内。18.5833 秒反击已经开始，此时怪物仍处接触停留；19.1500 秒在其恢复阶段命中 40 点伤害，没有等双方重新站定。

音频数值检查：48kHz 双声道，峰值 −15.44dBFS，RMS −33.49dBFS，没有削波样本。图形验收采用真实桌面截图和密集帧检查；没有声称完整观看／试听连续音画。角色衔接在所检帧中连续，鹤的斜向俯冲与抬身之间仍为少量绘制关键帧，近距离羽饰与头发的外观轮廓仍可能拥挤。首轮录制期间源码固定；其后仅对异常模块 ID 的防御性校验做了不影响该正常配装路径的调整。

复核已录制数据的命令：

```sh
python3 tools/qa_analyze_continuous_capture.py \
  /tmp/mountain-continuous/capture/continuous-combat-events.json \
  --output=/tmp/mountain-continuous/capture/analysis.json
godot --headless --path . --script tools/qa_audit_recorded_contact.gd -- \
  --events=/tmp/mountain-continuous/capture/continuous-combat-events.json \
  --output=/tmp/mountain-continuous/capture/guard-contact-audit.json
```

第二条仅复核本片已标识的 18.30–19.30 秒窗口。若未来动作时长或片段顺序改变，应重新选取真实接触窗口，不能把固定时间窗口通过当作所有战斗均无穿透的证明。
