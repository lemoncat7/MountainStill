# 当前素材与制作来源

本项目的山居背景、成年男性 Q 版基础人物、独立服饰图层、兵器、术法、灵兽及木箱，使用内置图像生成工具为本项目生成。用户提供的插画只作为风格参考。画面采用暖色中国幻想插画风格；不宣称这些素材由真人手绘。

## 当前运行素材

- `assets/cultivation/sanctuary-warm.png`：1040 × 280 山居背景。最新原图与布局提示词在 `sources/sanctuary-warm-layout-*`；最终图使用 Lanczos 缩放，场景锚点记录于 `sanctuary-warm-layout.json`。
- `assets/cultivation/sanctuary-diorama.png`：1040 × 280 透明山居小景，天空使用图像生成工具产生的真实 alpha，地面保留不透明落脚区域。最终原图、提示词、来源记录及 alpha 测量随源码保存在 `sources/sanctuary-diorama-*`；没有用程序抠掉或重绘背景。
- `assets/ui/ink/`：宣纸与墨刷两张原始透明纹理，由图像生成工具为本项目生成。PNG 本身就是保留的原始素材，运行时由 `InkPaper` 选择采样区域；同目录 README 保存生成提示词。`InkHotspot` 提供场景入口，`InkPages` 绘制墨色册页文字与内容。
- `assets/cultivation/equipment/`：512 × 512 的基础人物与八件服饰图层。基础人物始终穿不透明白色短裤；头饰、上衣、下装、鞋履可独立叠加。原图、分层图集、制作说明及坐标随源码保留。`tools/crop_equipment_assets.py` 可复现裁切、缩放及对齐。
- `assets/cultivation/avatars/`：仅使用剑、扇、雾气斩痕、花瓣四个图层。原始道具图集及 `props-anchors.json` 随源码保留；`tools/crop_props_assets.py` 可复现。旧版整套服装人物不包含在当前源码包或运行包中。
- `assets/cultivation/encounters/`：玉狐与云猪各有静止、出招两帧，木箱有关闭、打开两帧。六张原图、生成提示词、缩放和地面锚点记录在 `sources/` 与 `metadata.json`；`tools/crop_encounter_assets.py` 可复现裁切与对齐。
- `assets/audio/`：背景音乐和装备、突破、收获提示音由 `tools/generate_audio.py` 程序合成。声音来源说明见同目录 `SOURCE_LICENSE.txt`。

- `assets/cultivation/sidewalk/`：真实右侧身基础头、躯干、四肢，以及独立头饰、上衣/袖口、裤装、鞋履。原图和生成提示、裁切坐标、来源哈希随目录保留；`tools/prepare_sidewalk_assets.py` 复现对齐。运行时以定长关节和着地约束变换图层，使用 mipmap 减少小尺寸碎边；原始图片不因缩放滤镜改变。
- `assets/cultivation/routes/`：六种透明关卡山景，每关均使用独立原画的有限2080×280长幅山径，运行时不反射重复。v1.3新生成溪桥、云坡、旧炉、月泽、天门五条连续全景；原图、提示词、哈希与透明地面QA随源码保留，`tools/prepare_campaign_routes.py` 可复现裁切对齐。旧版镜像条仅作历史资源保留，不用于本版六关运行镜头。
- `assets/cultivation/beasts/`：苔兽、溪石灵、云鹤、炉心炎灵、镜月灵、镇山守灵六种独立物种，各有普通与首领的静立、蓄势、攻击画，共36张；另有石龛机缘原画。v1.3增加20张新阶段图，原始图集和单独生成的首领画均保留。均为本项目生成，无第三方游戏素材提取。各目录的 `sources/`、`provenance.json`、提示词和 `tools/route_prepare_*.py` 和 `tools/prepare_campaign_beasts.py` 保存来源及整理过程。

图像整理脚本需要 Python 3 + Pillow，声音生成脚本需要 Python 3 + NumPy。运行游戏及普通导出不需要这些 Python 依赖。源码包保留当前素材的原始输入、坐标与工具，排除历史方向、旧版整套换装、缓存和录屏。

Godot 与字体的第三方许可见 [THIRD_PARTY.md](THIRD_PARTY.md)。
