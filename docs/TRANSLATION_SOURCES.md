# 译文来源与核对方法

本说明对应官方 v2.0.3、汉化修订 `2026-10-21-console-usability`。界面说明的直接原文来自 MLX LoRA Studio；算法论文提供概念与术语依据。中文表述、必要澄清及新增交互提示由本项目借助 AI 工具翻译、整理并核对，维护账号为 inothing-cyber。原应用作者为 Gökdeniz Gülmez。

- 查某句中文的原文：[逐条来源索引](translation_sources/README.md)。
- 查算法和术语的研究来源：[18 篇论文与 9 项其他一手资料](REFERENCES.md)。
- 查实际实现与验证边界：[下方实现说明](#implementation-limits)、[验证范围](VALIDATION.md)。

## 英文原文固定到哪个版本

官方仓库为 [Goekdeniz-Guelmez/MLX-LoRA-Studio](https://github.com/Goekdeniz-Guelmez/MLX-LoRA-Studio)，本版原文固定到 commit [`69e34a31aca717b6d5a0a4f5306e25cf7c0b18f1`](https://github.com/Goekdeniz-Guelmez/MLX-LoRA-Studio/tree/69e34a31aca717b6d5a0a4f5306e25cf7c0b18f1)。原文索引链接均使用这个 commit，不会随官方 main 的更新漂移。

| 说明区域 | 直接原文与实现位置 | 中文记录 |
| --- | --- | --- |
| 训练参数、模型类型和提示 | 官方 `TrainingView.swift`、`TrainingModels.swift` 等对应源码 | 双语标签、界面说明和模型显示分类 |
| 算法指南：概述、直觉、数学、参数、数据、用法 | 官方 [AlgorithmGuideView.swift](https://github.com/Goekdeniz-Guelmez/MLX-LoRA-Studio/blob/69e34a31aca717b6d5a0a4f5306e25cf7c0b18f1/Sources/MLXLoRAStudio/Views/AlgorithmGuideView.swift) | 四个指南分类，逐条链接原文与译文 |
| 运行记录、实时指标、上传、设置和引导 | 官方对应的 Views、Services、Models 文件 | 通用、界面和动态状态分类 |
| 动态状态、通知及错误说明 | 官方相应字符串／插值模板；底层原始日志保留 | `dynamic-display.tsv`；生成显示查表 |
| 本项目新增交互说明 | 本项目源码和已记录的显示补丁 | 见[新增说明](#project-additions)，标明为项目整理 |

逐条索引覆盖现有目录中的 **971 处资源出现位置**，包含重复和保留原文的技术标签。每条列出原文件、原行、原列、完整译文所在 TSV 行，以及适用时的相关理论背景。算法指南中多段说明以同一字符串保存时，共用一个来源位置；打开原文／译文链接可查看完整段落。971 不是全文翻译覆盖率，也不包含所有新加辅助控件文字。

完整英文与中文另见 [entries.json](../localization/catalog/entries.json)。其中 `file`、`line`、`column` 指**官方原版位置**，不能直接当作中文版 Swift 文件的行号。`source_value` 是英文原文，`target_value` 是译文，`table` 是对应 TSV。旧的 `review_status` 是初筛记录字段，不是逐条专家签名；本版对应关系另由版本锁、目录一致性和源码复现检查约束。

## 算法说明与研究依据的对应

下表用于理解逐条索引中的论文编号。具体操作、字段和默认值仍来自应用／训练器实现。

| 指南主题 | 研究／官方资料 | 核对重点 |
| --- | --- | --- |
| LoRA / DoRA / full fine-tuning | [P01](REFERENCES.md#p01)、[P03](REFERENCES.md#p03)、[D05](REFERENCES.md#d05) | 冻结权重、rank、magnitude / direction；区分论文公式与实际参数 |
| QLoRA / quantization / QAT / MXFP4 | [P02](REFERENCES.md#p02)、[P18](REFERENCES.md#p18)、[D09](REFERENCES.md#d09) | 量化权重与可训练 adapter、fake quantization、具体格式差异 |
| SFT / RLHF 流程 | [P04](REFERENCES.md#p04) | 示范训练、偏好反馈与奖励阶段；此文不作为 SFT 首创来源 |
| DPO | [P05](REFERENCES.md#p05) | policy、reference、chosen / rejected 及偏好目标 |
| CPO | [P06](REFERENCES.md#p06) | 本应用指 Contrastive Preference Optimization |
| ORPO | [P07](REFERENCES.md#p07) | odds ratio 与无独立 reference 的目标结构 |
| GRPO / PPO | [P08](REFERENCES.md#p08)、[P09](REFERENCES.md#p09) | group-relative advantage 与 clipped objective |
| Online DPO | [P05](REFERENCES.md#p05)、[P12](REFERENCES.md#p12) | DPO 与迭代采样／评审背景；P12 不等同于本应用实现 |
| XPO | [P10](REFERENCES.md#p10)、[P05](REFERENCES.md#p05) | 在线探索与 exploration bonus；具体公式和 schedule 按本版本实现 |
| RLHF-REINFORCE | [P11](REFERENCES.md#p11)、[P04](REFERENCES.md#p04) | 策略梯度与反馈流程，保留 REINFORCE 名称 |
| FTPO / Antidoom | [P13](REFERENCES.md#p13)、[D06](REFERENCES.md#d06) | token 位置优化；Antidoom 格式按训练器实现 |
| Dynamic Fine-Tuning / DFT | [P14](REFERENCES.md#p14) | SFT 目标重加权，不解释为动态 learning rate |
| GSPO 相关说明 | [P15](REFERENCES.md#p15) | sequence 与 token 级 importance ratio 的区别；不借引用增添训练选项 |
| Adam / AdamW / Muon | [P16](REFERENCES.md#p16)、[P17](REFERENCES.md#p17)、[D01](REFERENCES.md#d01)、[D02](REFERENCES.md#d02) | 自适应矩估计、decoupled weight decay、正交化更新；Muon 作者说明归为技术博客与代码 |
| MLX 内存与执行 | [D03](REFERENCES.md#d03)、[D04](REFERENCES.md#d04) | unified memory、lazy evaluation 的含义 |
| SwiftUI 本地化方法 | [D07](REFERENCES.md#d07)、[D08](REFERENCES.md#d08) | 显示边界和界面核对方法，不是中文译文来源 |

<a id="implementation-limits"></a>

## 论文与实际实现需要分开的地方

1. **LoRA scale**：P01 的 α/r 是论文约定。本次核对的 mlx-lm 0.32.2 LoRA 层直接用 `scale` 乘以更新量；指南相关译文补充了这一差别，不对保存值或默认值做除以 rank 的换算。0.32.2 是本次观察的环境版本，其他用户需核对自己选用的版本。原文位置为官方指南 547、1287、1316 行，完整译文见参数和基础分类。
2. **量化格式**：P02 的 NF4、double quantization、paged optimizers 不代表每个 MLX 量化选项都采用相同机制。P18 提供 QAT 背景，也不证明本应用的 hook 时机、间隔与论文相同。MXFP4 的格式依据为 D09，不能套用普通对称整数公式；相关补充见原文 1470、1489、1524 行对应译文。
3. **版本背景**：官方指南仍以 mlx-lm-lora 3.0.0 为背景，本版已核对的内置后端为 3.1.2。指南开头译文说明了这一点；不根据旧版文案更换执行依赖。原文位置为官方指南 49 行。
4. **Online DPO / FTPO / XPO**：论文提供理论或相关研究背景；应用的 judge、Antidoom JSONL、正负号、loss 变体和 schedule 不能只凭相近算法名称判定与论文完全相同。字段、分发及输入要求应核对[本版 Backend](../Backend)和[原版应用内容清单](../localization/original-app-manifest.json)。D06 是官方训练器入口，当前 HEAD 不能替代本版 3.1.2 的具体内容。
5. **操作建议与资源估计**：指南的“适合何时使用”、起始参数、内存占用、训练速度和效果数字，直接来源可能是原作者的使用说明。逐条索引保留其原文位置，但背景论文链接不把这些建议变成本项目的实测保证。公式与论文／实现的逐项科学等价也未在本次文档补充中得到证明。
6. **“实时内存”**：这是本项目根据界面语义采用的 `Live memory` 译法；D03 解释的是 unified memory。此中文标签不宣称是 Apple 专门规定的官方名称。

<a id="project-additions"></a>

## 本项目新增说明的来源

这些文字描述本项目界面或维护工具的实际行为，来源归于本项目，不附会为论文译文。

| 新增／整理内容 | 对应记录 |
| --- | --- |
| 中文＋英文参数标签、专业名称与单位保留策略 | [术语与保护规则](../localization/terminology.json)、[双语标签目录](../localization/catalog/bilingual-labels.tsv) |
| 控制台空状态、等待输出和窄窗布局提示 | [StudioTrainingPanes.swift](../localization/native/StudioTrainingPanes.swift)、[显示改进补丁](../localization/ui-improvements.json)；说明仅显示由 Studio 启动的任务 |
| 无效数值输入时保留实际值的提示 | [StudioNumericInput.swift](../localization/native/StudioNumericInput.swift)、[数值输入反馈补丁](../localization/input-feedback.json) |
| 常驻参数标签与数值／图例显示 | [StudioLabeledTextField.swift](../localization/native/StudioLabeledTextField.swift)、[显示边界补丁](../localization/display-boundaries.json) |
| 动态翻译生成与查表规则 | [generate_display.py](../tools/generate_display.py)、[动态译文目录](../localization/catalog/dynamic-display.tsv)；英文模板本身仍对应原版源码 |
| 吞吐量读数修复说明 | [读数修复记录](../localization/metric-display-fixes.json)、[StudioMetricReadings.swift](../localization/native/StudioMetricReadings.swift)、[对应测试](../Tests/MLXLoRAStudioTests/MetricsReadingTests.swift)；属于显示修复，单列而非归为翻译 |
| 构建、验证、更新及许可证文档 | 本仓库的工具、工作流和[验证范围](VALIDATION.md)，外部方法链接在相应文档中标出 |

## 如何维护这些出处

参考书目保存在 [reference-sources.json](../localization/reference-sources.json)。[document_sources.py](../tools/document_sources.py) 根据已锁定的官方源码、现有译文目录和审查过的指南区段生成来源索引与书目。它只写文档，不修改应用、译文目录、模型、后端或环境。

```sh
python3 tools/document_sources.py --write
python3 tools/document_sources.py --check
```

官方 commit 改变时，工具会要求重新核对区段及引用关系。它检查原文和译文对应、引用编号、目录一致性与生成文档漂移，不替代人工判断论文是否支持某项科学结论。网络链接的访问核对记录按日期保存，持续维护网页的内容可能更新。

原应用和修改的许可见 [LICENSE](../LICENSE)、[NOTICE](../NOTICE) 与[第三方说明](THIRD_PARTY.md)。引用论文、规范或 Apple 文档不表示其作者为本项目背书。
