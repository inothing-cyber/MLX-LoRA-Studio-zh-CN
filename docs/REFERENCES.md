# 论文与一手参考资料

[译文来源说明](TRANSLATION_SOURCES.md) · [逐条来源索引](translation_sources/README.md)

核对日期：2026-10-21。一手页面的标题、作者、首发年、摘要或官方章节与引用用途核对；不代表所有指南公式与后端实现已逐行证明等价。

本页记录本次中文解释的术语核对依据。中文表述由本项目 AI 辅助翻译、整理，维护账号 inothing-cyber；引用不表示原作者提供中文译文或为本项目背书。不收录论文全文。

P 为论文／预印本，年份按首发年；D 为官方文档、作者说明、实现或规范。网页及代码入口可能更新，应用原文则固定到已审定 commit。

## 论文与预印本

<a id="p01"></a>

### P01 · LoRA

Hu 等，2021。[LoRA: Low-Rank Adaptation of Large Language Models](https://arxiv.org/abs/2106.09685)。

区分预训练权重、可训练低秩矩阵、rank 和 scale；专业标签保留原文。

<a id="p02"></a>

### P02 · QLoRA

Dettmers 等，2023。[QLoRA: Efficient Finetuning of Quantized LLMs](https://arxiv.org/abs/2305.14314)。

区分量化基础模型与训练 adapter；原论文中的 NF4、双重量化和分页优化器不能直接等同于本机所有 MLX 量化选项。

<a id="p03"></a>

### P03 · DoRA

Liu 等，2024。[DoRA: Weight-Decomposed Low-Rank Adaptation](https://arxiv.org/abs/2402.09353)。

核对 magnitude 与 direction 的区别；不能将 DoRA 的结构和训练行为直接等同于 LoRA。

<a id="p04"></a>

### P04 · SFT / RLHF

Ouyang 等，2022。[Training language models to follow instructions with human feedback](https://arxiv.org/abs/2203.02155)。

区分示范数据训练、偏好数据和奖励反馈。此文是相关流程依据，并非 SFT 概念的首创论文。

<a id="p05"></a>

### P05 · DPO

Rafailov 等，2023。[Direct Preference Optimization: Your Language Model is Secretly a Reward Model](https://arxiv.org/abs/2305.18290)。

区分 policy model、frozen reference model、chosen response 和 rejected response。

<a id="p06"></a>

### P06 · CPO

Xu 等，2024。[Contrastive Preference Optimization: Pushing the Boundaries of LLM Performance in Machine Translation](https://arxiv.org/abs/2401.08417)。

本应用中的 CPO 指 Contrastive Preference Optimization，避免误用同缩写的其他优化算法名称。

<a id="p07"></a>

### P07 · ORPO

Hong 等，2024。[ORPO: Monolithic Preference Optimization without Reference Model](https://arxiv.org/abs/2403.07691)。

odds ratio 与 advantage 均保留原文并区分含义；保留其无需独立 reference model 的概念。

<a id="p08"></a>

### P08 · GRPO

Shao 等，2024。[DeepSeekMath: Pushing the Limits of Mathematical Reasoning in Open Language Models](https://arxiv.org/abs/2402.03300)。

区分采样组、组相对奖励和逐个 token 的指标。

<a id="p09"></a>

### P09 · PPO

Schulman 等，2017。[Proximal Policy Optimization Algorithms](https://arxiv.org/abs/1707.06347)。

区分裁剪、概率比、策略更新和奖励。

<a id="p10"></a>

### P10 · XPO

Xie 等，2024。[Exploratory Preference Optimization: Harnessing Implicit Q*-Approximation for Sample-Efficient RLHF](https://arxiv.org/abs/2405.21046)。

保留在线探索、探索奖励与普通 DPO 的区别；参数含义仍以本版本后端为准。

<a id="p11"></a>

### P11 · REINFORCE

Williams，1992。[Simple statistical gradient-following algorithms for connectionist reinforcement learning](https://doi.org/10.1007/BF00992696)。

REINFORCE 是算法名，保持原文。

<a id="p12"></a>

### P12 · 在线 DPO 的相关研究背景

Yuan 等，2024。[Self-Rewarding Language Models](https://arxiv.org/abs/2401.10020)。

说明训练中生成样本、评审及迭代偏好学习；此文与本应用 Online DPO 不能简单视为同一实现。

<a id="p13"></a>

### P13 · FTPO

Paech 等，2025。[Antislop: A Comprehensive Framework for Identifying and Eliminating Repetitive Patterns in Language Models](https://arxiv.org/abs/2510.15061)。

区分在指定上下文后的单个续接位置优化与整段回答偏好优化；应用的 Antidoom 数据格式必须按本机后端保留。

<a id="p14"></a>

### P14 · Dynamic Fine-Tuning / DFT

Wu 等，2025。[On the Generalization of SFT: A Reinforcement Learning Perspective with Reward Rectification](https://arxiv.org/abs/2508.05629)。

DFT 是 SFT 目标函数选项之一，不能描述成通用动态 learning rate 策略。

<a id="p15"></a>

### P15 · GSPO

Zheng 等，2025。[Group Sequence Policy Optimization](https://arxiv.org/abs/2507.18071)。

为指南中 sequence / token 级重要性比的区别提供术语依据，不因此给应用增加新算法选项。

<a id="p16"></a>

### P16 · Adam：保留名称

Kingma、Ba，2014。[Adam: A Method for Stochastic Optimization](https://arxiv.org/abs/1412.6980)。

核对 Adam 的一阶与二阶矩、自适应更新等概念。2014 为预印本首发年，会议发表为 ICLR 2015。

<a id="p17"></a>

### P17 · AdamW

Loshchilov、Hutter，2017。[Decoupled Weight Decay Regularization](https://arxiv.org/abs/1711.05101)。

核对 decoupled weight decay 与一般 L2 regularization 的区别。2017 为预印本首发年，会议发表为 ICLR 2019。

<a id="p18"></a>

### P18 · Quantization-Aware Training / QAT

Jacob 等，2017。[Quantization and Training of Neural Networks for Efficient Integer-Arithmetic-Only Inference](https://arxiv.org/abs/1712.05877)。

为量化和训练过程的关系提供基础术语；此文不能当作本机所有 QAT hook 的逐行实现说明。

## 官方文档、作者说明与格式规范

<a id="d01"></a>

### D01 · Muon 作者技术说明

Keller Jordan，2024。[Muon: An optimizer for hidden layers in neural networks](https://kellerjordan.github.io/posts/muon/)。

核对动量、矩阵正交化和 Newton–Schulz 迭代。属于作者技术博客，不能标为已发表论文；其中速度结果不构成本项目的性能保证。

<a id="d02"></a>

### D02 · Muon 作者实现

KellerJordan/Muon，持续维护资料，版本以页面为准。[Muon implementation](https://github.com/KellerJordan/Muon)。

作者实现入口，作为算法说明补充；当前分支不代表本版 MLX 优化器逐行实现。

<a id="d03"></a>

### D03 · MLX 内存术语

Apple MLX，持续维护资料，版本以页面为准。[Unified Memory](https://ml-explore.github.io/mlx/build/html/usage/unified_memory.html)。

用于理解 unified memory；“实时内存”是本项目对 Live memory 的显示译法，不宣称为 Apple 专门规定的术语。

<a id="d04"></a>

### D04 · MLX 执行术语

Apple MLX，持续维护资料，版本以页面为准。[Lazy Evaluation](https://ml-explore.github.io/mlx/build/html/usage/lazy_evaluation.html)。

核对 lazy evaluation 的含义；文档网址可能随官方版本更新。

<a id="d05"></a>

### D05 · MLX-LM 实现入口

ml-explore，持续维护资料，版本以页面为准。[MLX-LM official repository](https://github.com/ml-explore/mlx-lm)。

具体 LoRA scale 定义应以用户选择的 mlx-lm 版本源码为准；当前 HEAD 不是所有安装环境的版本锁。

<a id="d06"></a>

### D06 · 训练器实现入口

Gökdeniz Gülmez，持续维护资料，版本以页面为准。[mlx-lm-lora official repository](https://github.com/Goekdeniz-Guelmez/mlx-lm-lora)。

本版已核对内置训练器 3.1.2；链接为官方入口，不能把当前 HEAD 视作本版逐行实现。精确分发内容见本仓库原版应用清单。

<a id="d07"></a>

### D07 · Apple 本地化方法

Apple，2023。[Discover String Catalogs](https://developer.apple.com/videos/play/wwdc2023/10155/)。

SwiftUI/Xcode 本地化方法参考，不提供本项目中文译文，也不表示本项目采用 .xcstrings 或获得 Apple 认证。

<a id="d08"></a>

### D08 · Apple 本地化方法

Apple，2025。[Code-along: Explore localization with Xcode](https://developer.apple.com/videos/play/wwdc2025/225/)。

本地化边界和界面验收方法参考；不作为算法、中文术语或性能结论来源。

<a id="d09"></a>

### D09 · MXFP4 格式

Open Compute Project，2023。[OCP Microscaling Formats (MX) Specification, Version 1.0](https://www.opencompute.org/documents/ocp-microscaling-formats-mx-v1-0-spec-final-pdf)。

见 5.2–5.4 节（10–14 页），核对具体 MX 格式、block size 与 E8M0 scale；不能把 MXFP4 等同于普通对称整数 4-bit。

## 引用范围

算法论文用于核对概念。应用的字段、默认值、数据集要求、分发逻辑、QAT hook 与执行参数，以对应版本代码和所选环境为准；操作建议、资源占用估算和速度比较不能仅凭本页引用变成已验证结论。具体差异见[来源说明](TRANSLATION_SOURCES.md#implementation-limits)。
