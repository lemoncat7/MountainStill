> 2026-10-22 整合候选：未公开发布；以下发行步骤仅为准备说明，本轮实际验证以 BUILD_VERIFICATION.md 为准。

# 公开测试版源码说明

本目录是 MountainStill v1.3.12-test.1 敌情与无奖励试招测试版，更新 ABI 和存档结构沿用 v1.3.9；原第一版发布不变。公开仓库不等于授予开源许可证：当前未为本项目原创代码、美术或声音添加 MIT、Apache 等新的许可授权；第三方组件仍适用各自许可。若后续希望允许他人修改、再发行，应由项目权利人明确选择许可。

## 第三方与素材来源

- Godot 4.6.3 的 MIT 许可及依赖版权文件保留在 `docs/licenses/`。
- Noto Sans CJK、Noto Serif CJK、Ma Shan Zheng 的 OFL，以及 DejaVu Sans 的字体声明均已保留。Noto 的同一发行包版权文件覆盖 Sans / Serif。
- 项目图像的已有来源说明记录为 AI 生成，见 `docs/ASSET_PROVENANCE.md`；程序合成声音的说明见 `assets/audio/SOURCE_LICENSE.txt`。这些是随源码提供的来源记录，不构成独立版权鉴定，也不替权利人补发授权。
- 原始用户风格参考图片未作为本次公开发布素材加入。

## 公开目录清理

已移除历史运行日志、录像/音频录制、截图、原生运行事件明细、存档式 QA 快照及其他生成报告。保留历史 Markdown 验证结论与复现指令；其中指向已移除证据附件的链接可能不再可打开，这些历史结论不代表本次 Windows/macOS 真机测试通过。为现有测试程序保留了三份非个人测试基线：`before.json`、`encounter-balance-after.json`、`baseline-pose-samples.bin`（见各自 `docs/qa/` 子目录）。

个人工作区绝对路径已移除或改为项目相对路径；历史来源记录中的 `archived-workspace/` 是脱敏后的档案定位标签，不是本机可访问目录。素材重生成脚本可能仍需其原始工具环境；运行游戏和普通导出不依赖重生成步骤。

`.godot/`、导出产品、签名证书、环境文件和本地日志被 `.gitignore` 排除。发布源码归档也应排除这些文件；仅有 `.gitignore` 并不能清除已经暂存或已跟踪的文件。

检查未发现常见 GitHub/OpenAI 令牌或私钥模式；这只是静态模式扫描，不是完整安全审计。

## 更新发布边界

更新清单仅绑定固定 GitHub 仓库的版本、引擎/启动 ABI、平台和 SHA256。SHA256 是完整性校验，不是独立发布者签名。更新源码和测试说明见 `docs/UPDATING.md`、`BUILD_VERIFICATION.md`；没有宣称任意脚本可无重启热换。源码包保留本页、`.gitignore`、用户说明及验证记录；不包含运行日志、缓存、个人存档或代理环境值。
