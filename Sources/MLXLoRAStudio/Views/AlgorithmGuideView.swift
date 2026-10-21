import SwiftUI

// MARK: - Algorithm Guide
//
// A long-form, wiki-style reference for every training loop that
// `mlx-lm-lora` (the package this app is built on) ships with.
// Tapping a card in the picker at the top selects the algorithm —
// the rest of the page is one continuous article covering it: what
// the loss is, what the knobs do, what dataset shape it expects,
// when to reach for it, and which settings are typically tuned.

struct AlgorithmGuideView: View {
    @Binding var config: TrainingConfig
    @State private var selection: GuideSelection = .mode(.sft)

    enum GuideSelection: Hashable {
        case mode(TrainMode)
        case adaptation
        case optimizers
        case quantization
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderView(
                    title: "算法指南",
                    subtitle: "mlx-lm-lora 各 training loop 的详细参考说明",
                    symbol: "book"
                )

                introCard
                trainingLoopPicker
                foundationsPicker
                article
            }
            .padding(24)
        }
        .navigationTitle("算法指南")
        .onAppear { selection = .mode(config.trainMode) }
    }

    // MARK: Intro

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("如何阅读本页")
                .font(.headline)
            Text("本页原版指南以 mlx-lm-lora 3.0.0 为背景，介绍十种训练算法，分为三类：**监督学习（supervised）**（SFT）、**偏好学习（preference）**（DPO、FTPO、CPO、ORPO）与 **强化学习／在线（reinforcement / online）**（GRPO、Online DPO、XPO、RLHF-REINFORCE、PPO）。点击下方 **训练循环** 中的卡片，可打开对应的完整说明文章。当前应用内置的后端版本请以设置页为准。")
                .fixedSize(horizontal: false, vertical: true)
            Text("**基础知识**涵盖不依赖于具体 loss 选择的四个部分：决定哪些 tensor 可训练的 **adaptation method**（LoRA / DoRA / full）；将 gradients 转换为更新的 **optimizer**（Adam、AdamW、Muon）；base model 的 **load-time quantisation**（4 / 6 / 8 / MXFP4 bit）；以及通过模拟 quantised forward pass，使训练后的 adapter 适应部署量化的 **Quantization-Aware Training**。")
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 12)
    }

    // MARK: Pickers

    private var trainingLoopPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("训练循环")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                ForEach(TrainMode.allCases) { mode in
                    Button {
                        selection = .mode(mode)
                        config.trainMode = mode
                        config.applyDefaultDataset(for: mode)
                    } label: {
                        algorithmCard(mode: mode, isSelected: selection == .mode(mode))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var foundationsPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("基础知识")
            HStack(spacing: 12) {
                foundationCard(
                    title: "Adaptation methods",
                    subtitle: "LoRA · DoRA · Full",
                    symbol: "square.stack.3d.up",
                    isSelected: selection == .adaptation
                ) { selection = .adaptation }

                foundationCard(
                    title: "Optimizers",
                    subtitle: "Adam · AdamW · Muon",
                    symbol: "function",
                    isSelected: selection == .optimizers
                ) { selection = .optimizers }

                foundationCard(
                    title: "Quantization & QAT",
                    subtitle: "4 / 6 / 8 / MXFP4 + QAT hook",
                    symbol: "cpu",
                    isSelected: selection == .quantization
                ) { selection = .quantization }
            }
        }
    }

    private func algorithmCard(mode: TrainMode, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(mode.title)
                    .font(.headline)
                Spacer()
                Text(mode.family)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(mode.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                if mode.needsReference {
                    InfoPill(text: "Reference", symbol: "person.2")
                }
                if mode.needsJudge {
                    InfoPill(text: "Judge", symbol: "scales")
                }
                if mode.supportsQAT {
                    InfoPill(text: "QAT", symbol: "cpu")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .liquidGlass(cornerRadius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
    }

    private func foundationCard(
        title: String,
        subtitle: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: symbol)
                        .font(.title3)
                        .frame(width: 32, height: 32)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    Text(title)
                        .font(.headline)
                    Spacer()
                }
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .liquidGlass(cornerRadius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Article router

    @ViewBuilder
    private var article: some View {
        switch selection {
        case .mode(let mode):
            AlgorithmArticle(mode: mode)
        case .adaptation:
            AdaptationArticle(config: $config)
        case .optimizers:
            OptimizerArticle(config: $config)
        case .quantization:
            QuantizationArticle(config: $config)
        }
    }
}

// MARK: - Article

/// One algorithm rendered as a long, scrollable article. The structure
/// is identical for every mode so the page reads as a wiki.
private struct AlgorithmArticle: View {
    let mode: TrainMode

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            section("概述", text: overview)
            section("直观理解", text: intuition)
            section("Objective（数学形式）", content: { mathView })
            section("设置会改变什么", content: { settingsTable })
            section("Dataset 格式", text: datasetFormat)
            section("适用场景", text: whenToUse)
            section("建议与注意事项", content: { tipsList })
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 14)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(mode.title)
                    .font(.system(.largeTitle, design: .rounded).bold())
                Spacer()
                Text(mode.family)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .liquidGlass(cornerRadius: 999, interactive: true)
            }
            Text(mode.summary)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Generic section helpers

    @ViewBuilder
    private func section(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
            Text(.init(MathTypesetter.richify(text)))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
            content()
        }
    }

    // MARK: Per-mode content

    private var overview: String {
        switch mode {
        case .sft:
            """
            **Supervised fine-tuning (SFT)** 是经典的“让 model 模仿 dataset”训练循环。每条示例是一个 `(prompt, completion)` 对，也可以是 chat 风格的 `messages` 列表或原始 `text`。训练旨在最大化 model 对 completion tokens 赋予的 log-probability；prompt tokens 会被 mask，使 loss 只计算回答部分。\n\n在 `mlx-lm-lora` 中，SFT trainer 是其他算法复用的基础。具体的 cross-entropy / NLL loss、gradient checkpointing、KV-cache 处理、QAT hooks，以及按 sequence 分块的 efficient-long-context forward pass 都位于 `sft_trainer.py`。各 preference 和 RL 算法继承这些机制，主要替换 loss function，有时也会改变 dataset 格式。
            """
        case .dpo:
            """
            **Direct Preference Optimisation (Rafailov et al., 2023)** 直接使用同一 prompt 的人类偏好对 `(chosen, rejected)` 训练 model。无需 reward model 或 sampling loop，而是通过 closed-form loss 提高 policy 对 chosen completion 的 log-probability、降低对 rejected completion 的 log-probability，并利用冻结的 **reference model** 进行 regularisation，限制 policy 漂移。\n\nReference 通常是起始 base model。加载其他 model（例如 instruction-tuned SFT checkpoint）会改变 implicit reward baseline，是调整最终行为的常用方式。
            """
        case .ftpo:
            """
            **Final Token Preference Optimisation (FTPO)** 使用 Antidoom 示例修复 reasoning doom loops。它不对整段回答进行优化，而是比较指定 context 后 policy 与冻结 reference 的 next-token distribution，提高多个可接受 next tokens 的 probability，并抑制 rejected token。\n\n两个 MSE regularizer 分别限制 target 和 non-target logits 的非预期漂移，因此 FTPO 适合定向修复，而非通用的 preference-tuning。
            """
        case .cpo:
            """
            **CPO (Contrastive Preference Optimisation)** 相当于移除 reference 项的 DPO。Chosen-rejected log-prob gap 与绝对目标比较，而非相对目标，因此无需 reference forward pass，policy 也可偏离 base model 更远。它训练更快、memory 占用更低，但对 `beta` / `delta` 的设置更敏感。
            """
        case .orpo:
            """
            **ORPO (Hong et al., 2024)** 将 SFT cross-entropy 和 odds-ratio preference 项合并为一个 loss。不需要 reference model 或单独的 SFT warm-up step；同一 gradient 既提高 chosen response、降低 rejected response，也改善 model 的 next-token log-likelihood。在 `mlx_lm_lora` 中，每条示例可提供可选的 `preference_score`，以便将不同强度的偏好（例如 UltraFeedback 风格的 0..10 分）作为 soft target。
            """
        case .grpo:
            """
            **GRPO (DeepSeekMath, 2024)** 是不需要 learned reward model 的 RL loop。对于每个 prompt，它从当前 policy 采样 `group_size` 个 completions，通过一个或多个用户提供的 **reward functions**（格式检查、准确性检查、int-format 等）评分，并计算 group-relative advantage：`A_i = (r_i − mean(r)) / (std(r) + ε)`。随后在 token 级别应用 PPO-style clipped objective。\n\n相对于 reference model 的 KL 项是可选的；如果 policy 开始向 reward 未惩罚的方向漂移，建议启用。
            """
        case .onlineDPO:
            """
            **Online DPO** 在训练时采样 `chosen` 和 `rejected` completions，而非从静态 dataset 中读取。对于每个 prompt，trainer 采样两个 completions，请 **judge**（LLM 或人类）判断哪个更好，将结果作为 preference pair，并即时计算 DPO loss。\n\nJudge 可以是 `human`（由你交互标注偏好对），也可以是 Hugging Face model identifier / 本地路径；runner 会加载相应 model，并使用 pairwise system prompt 进行评审。
            """
        case .xpo:
            """
            **XPO (Exploratory Preference Optimisation)** 在 online-DPO 类方法上添加显式的 **exploration bonus**，其大小与当前 policy 和 reference 之间的 KL divergence 成正比。设置 `alpha > 0` 会奖励 model 尝试不同于 reference 的 completions，缓解普通 online DPO“停留在 reference completion”的问题。`alpha` 可以是单个 float 或列表（每个 epoch 一个值），使 bonus 随训练逐渐衰减。
            """
        case .rlhfReinforce:
            """
            **RLHF-REINFORCE** 是经典的 policy-gradient RLHF loop。Trainer 从 policy 采样 completions，以 scalar reward 评分（通常由通过 `judge` 和 `judge_system` 配置的 LLM judge 提供），再应用 per-token REINFORCE objective，并可选用相对于 reference model 的 KL penalty 进行 regularisation。\n\n它是概念上最简单的 online 算法之一（无 clipping、无 value head），但 variance 最高，因此相较 DPO/PPO 更适合较小的 learning rates 和更长的 KL warm-up。
            """
        case .ppo:
            """
            **应用于 LMs 的 PPO (Schulman et al., 2017)** 使用经典的 clipped policy optimisation。对于每个 prompt，trainer 采样两个 completions，由 judge 选出更好的一个，组成 `(chosen, rejected)`。随后计算相对于 reference model 的 log-ratios，并在两个 sequences 上最小化 clipped surrogate objective，再加上 KL penalty。\n\n这是这些训练循环中能力很强、也很需要细调的一种：`epsilon` clip range、`beta` KL weight 和 judge 质量都很重要。
            """
        }
    }

    private var intuition: String {
        switch mode {
        case .sft:
            """
            • Model 接收问题，你提供正确答案，并要求它下一次对正确答案更有信心。\n• 对 prompt 应用 mask，意味着 loss 只惩罚或奖励 model 在回答中*生成*的 tokens，而非问题本身。\n• Iterations 是在 mini-batches 上执行的 stochastic gradient steps；validation set 是留出的数据，不应参与训练。\n• 本指南的其他方法都建立在 SFT 之上，因此 `grad_checkpoint`、`efficient_long_context`、`seq_step_size` 和 `qat_*` 也由 SFT trainer 实现。
            """
        case .dpo:
            """
            • DPO 由 KL-constrained RL objective 的 closed-form solution 推导而来，其 loss 在数学上对应使用 learned reward model 的 RLHF，但无需显式训练 reward model。\n• Implicit reward 为 `β · log(π_θ(chosen) / π_ref(chosen)) − β · log(π_θ(rejected) / π_ref(rejected))`。较大的 `β` 使 loss 更激进，较小的值更温和。\n• `loss_type = "sigmoid"` 是原始 DPO；`hinge` 是 margin-style loss；`ipo` 向固定目标 regularise，对噪声更稳健；`dpop` 添加由 `delta` 缩放的显式 reference-drift penalty。
            """
        case .ftpo:
            """
            • 每行提供应用了完整 chat template 的 context、一个 rejected continuation，以及一个或多个可接受 continuation。\n• FTPO 仅更新 next-token distribution，因而能针对 reasoning loop 开始的具体分支。\n• 冻结的 reference 和 MSE 项可限制无关 vocabulary logits 漂移。
            """
        case .cpo:
            """
            • 没有 reference 时，policy 可能漂移：model 只被告知“chosen 优于 rejected”，却没有锚点。\n• 设置 `loss_type = "dpop"` 会添加 hinge penalty `max(0, ref − π)`（在 drift penalty 中，CPO 用 policy log-prob 代替 reference），通过 `delta` 限制这种漂移。\n• 实践中 CPO 往往比 DPO 更快收敛，但需要更仔细地调整 `beta` 和 `delta`。
            """
        case .orpo:
            """
            • ORPO 的特点是 log-odds 项：`log σ( log π(chosen) − log π(rejected) )`。同一 gradient 既降低 chosen completion 上的 NLL，也增大两者差距。\n• `preference_score`（默认 1.0）使 trainer 能按示例缩放 chosen log-prob，因此 0.3 的 soft preference 所受推动小于 1.0 的 hard preference。\n• 可以传入 `reward_scaling`，但上游实现实际上未将其作为独立乘数使用，该项为未来变体保留。
            """
        case .grpo:
            """
            • Reward 由你提供的 functions 决定，例如字符串匹配准确率、integer/格式检查、XML-tag 计数。默认集合是 `r1_*` 系列（DeepSeek-R1 风格的 format + accuracy rewards）。\n• Advantages 按每个 prompt group 计算，因此 reward functions 的绝对 scale 不重要，重要的是同一 group 内的*相对*次序。这使 GRPO 不易受 reward function 数值大小影响。\n• Importance sampling 可选择让 PPO ratio 采用 per-token 数值（默认 `token`），或对整个 sequence 求平均（`sequence`；GSPO 论文认为其更稳定）。\n• KL 为可选项。设置 `beta = 0.0` 可将其关闭，此时 trainer 仅为日志记录使用 Schulman-style unbiased estimator。
            """
        case .onlineDPO:
            """
            • 每个 step 为：prompt → 两个 completions → judge 选择胜者 → DPO loss。\n• Completions 来自*当前* policy，数据分布随训练变化，从而避免普通 DPO 的“off-policy 数据过时”问题。\n• Judge system prompt 对结果影响很大，它决定评判标准。模糊的“哪个更好？”会产生有噪声的标签；具体要求“奖励简洁、事实准确、拒绝不安全内容”会更明确。\n• `loss_type` 和 `delta` 的行为与 DPO 完全相同。
            """
        case .xpo:
            """
            • XPO 的 bonus 项 `alpha · (KL(policy ‖ ref) on chosen + KL on rejected)` 奖励偏离 reference，其符号与 KL penalty 相反。\n• 因而 model 会在训练初期受到*尝试新行为*的激励，并在 bonus 衰减后进入稳定区域。\n• 使用单个 `alpha` 可保持探索强度不变，也可传入列表，使其逐个 epoch 衰减。
            """
        case .rlhfReinforce:
            """
            • Policy gradient 为 `−(reward − β · KL) · log π(action)`，沿采样 trajectory 求和。没有 clipping 和 value head，因此 variance 较高。\n• 在 `mlx_lm_lora` 中，reward 是由 LLM judge（`judge` 设置）产生的 scalar，没有单独的 value model。\n• KL 按 policy 与 reference 之间的每个 token 计算；`beta` 是 advantage（`reward − β · KL`）中 KL 项的系数。
            """
        case .ppo:
            """
            • Objective 为标准 PPO surrogate：`−min(ρ · A, clip(ρ, 1−ε, 1+ε) · A)`，其中 `ρ = π / π_ref`，`A` 来自 chosen-rejected reward gap。\n• Clip range `epsilon = 0.2` 是经典 Schulman 默认值；收紧到 0.1 等数值会使更新更保守，放宽到 0.3 等数值则允许 policy 在每个 step 中变化更多。\n• KL 作为 regulariser 加在 surrogate 之外，而非 advantage 的一部分。
            """
        }
    }

    private var mathView: some View {
        let parts = math
        return VStack(alignment: .leading, spacing: 10) {
            if !parts.prose.isEmpty {
                Text(.init(MathTypesetter.richify(parts.prose)))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(parts.equations.enumerated()), id: \.offset) { _, eq in
                MathBlock(source: eq)
            }
        }
    }

    private var math: (prose: String, equations: [String]) {
        switch mode {
        case .sft:
            return (
                prose: "每条示例的 next-token cross-entropy 经过 mask，仅计入 completion。实现位于 `sft_trainer.default_loss`：将输入平移一位形成 `(inputs, targets)`，可通过 cache offset 将 loss 限于 `[length_start, length_end]` 范围（用于 `efficient_long_context`），再按 mask 后的 token count 求平均。",
                equations: [
                    "**ℒ**ₛfₜ(θ) = − ∑ₜ  log *p*₍θ₎(*y*ₜ | prompt, *y*<sub>t</sub>)        for t ∈ completion tokens",
                ]
            )
        case .dpo:
            return (
                prose: "针对单个 preference pair `(*y*₍c₎, *y*₍r₎)` 与 prompt `*x*`。`β` 是 temperature：较高的 `β` 会使 policy 更强地向 implicit reward 推进。`delta` 仅用于 `dpop` loss，控制对偏离 reference 的惩罚强度。",
                equations: [
                    "logits  =  ( log π_θ(*y*₍c₎|*x*)  −  log π_θ(*y*₍r₎|*x*) )  −  ( log π_ref(*y*₍c₎|*x*)  −  log π_ref(*y*₍r₎|*x*) )",
                    "**ℒ**₍DPO₎   =  − log σ( β · logits )                                                  (sigmoid)\n=  max( 0,  1 − β · logits )                                                (hinge)\n=  ( logits − 1 ⁄ (2β) )²                                                  (ipo)\n=  − log σ( β · logits )  +  δ · max( 0,  log π_ref(*y*₍c₎|*x*) − log π_θ(*y*₍c₎|*x*) )    (dpop)",
                ]
            )
        case .ftpo:
            return (
                prose: "FTPO 将 chosen 与 rejected 的 next-token logits 上的 clipped preference loss，与相对于冻结 reference distribution 的 MSE penalties 结合。",
                equations: [
                    "Δ = logit_θ(chosen) − logit_θ(rejected)",
                    "ℒ_FTPO = softplus(ε − Δ) · clip((ε − Δ) / ε, 0, 1) + λ_mse MSE_non-target + λ_target MSE_target"
                ]
            )
        case .cpo:
            return (
                prose: "形式与 DPO 相同，但主 loss 中不含 reference 项。由于 reference 不参与 forward pass，`dpop` CPO 变体在 drift penalty 中用 policy log-prob 代替 reference。",
                equations: [
                    "logits  =  log π_θ(*y*₍c₎|*x*)  −  log π_θ(*y*₍r₎|*x*)",
                    "**ℒ**₍CPO₎   =  − log σ( β · logits )                                                  (sigmoid)\n=  max( 0,  1 − β · logits )                                                (hinge)\n=  ( logits − 1 ⁄ (2β) )²                                                  (ipo)\n=  − log σ( β · logits )  +  δ · max( 0,  log π_θ(*y*₍r₎|*x*) − log π_θ(*y*₍c₎|*x*) )    (dpop)",
                ]
            )
        case .orpo:
            return (
                prose: "同一 loss 也会降低 chosen completion 上的 NLL，因为 chosen log-prob 项出现在 gradient 的两部分中。可选的 `preference_score` 在相减前重新缩放 chosen log-prob，因此 `preference_score = 0.3` 的数据行所贡献的 gradient 约为 1.0 数据行的三分之一。",
                equations: [
                    "log_odds      =  log π_θ(*y*₍c₎|*x*)  −  log π_θ(*y*₍r₎|*x*)              (mean over tokens)",
                    "**ℒ**₍ORPO₎    =  − β · log σ( log_odds )",
                ]
            )
        case .grpo:
            return (
                prose: "对于具有 `*G*` 个采样 completions、reward functions `{*r*₍k₎}` 和 weights `{*w*₍k₎}` 的 prompt，`ε_low` 与 `ε_high`（`epsilon` 和 `epsilon_high`）是 DAPO 的非对称 clip bounds。`importance_sampling_level` 决定 `ratio` 是 per-token 还是对整个 sequence 求平均。",
                equations: [
                    "*R*<sub>i</sub>       =  ∑<sub>k</sub>  *w*₍k₎ · *r*₍k₎(prompt, *y*<sub>i</sub>)                              (total reward)",
                    "*A*<sub>i</sub>       =  ( *R*<sub>i</sub>  −  meanⱼ *R*<sub>j</sub> )  ⁄  ( stdⱼ *R*<sub>j</sub> + 1×10⁻⁴ )      (group-normalised advantage)",
                    "ratio<sub>i,t</sub>   =  π_θ(*y*<sub>i,t</sub>)  ⁄  π_ref(*y*<sub>i,t</sub>)                              (importance ratio)",
                    "**ℒ**₍clip₎    =  − min( ratio · *A*,  clip( ratio,  1−ε_low,  1+ε_high ) · *A* )",
                    "**ℒ**₍KL₎      =  β · ( ratio · (π_ref ⁄ π_θ)  −  log(π_ref ⁄ π_θ)  −  1 )                      (unbiased KL)",
                    "**ℒ**₍GRPO₎    =  ( **ℒ**₍clip₎  +  **ℒ**₍KL₎ )   averaged over valid tokens",
                ]
            )
        case .onlineDPO:
            return (
                prose: "对于每个 prompt `*x*`，采样两个 completions `(*y*<sub>1</sub>, *y*<sub>2</sub>)`，由 judge 选择胜者 `*w* ∈ {0, 1}`。Temperature 与 judge system prompt 共同决定标签的信息量；`beta` 和 `loss_type` 与 DPO 相同。",
                equations: [
                    "*y*<sub>chosen</sub>   =  *y*<sub>w</sub>",
                    "*y*<sub>rejected</sub> =  *y*<sub>1−w</sub>",
                    "**ℒ**          =  DPO loss on ( *y*<sub>chosen</sub>, *y*<sub>rejected</sub> )    — see DPO math",
                ]
            )
        case .xpo:
            return (
                prose: "XPO loss 是在 DPO 上添加与 KL 成比例的 exploration bonus。正 `alpha` 的含义是*奖励我与 reference 不同*。当 `alpha` 为列表时，`get_current_alpha(step, total, schedule)` 返回当前 step 对应的 schedule 项（每个 epoch 一项，最后一项保持到训练结束）。",
                equations: [
                    "bonus  =  α · ( KL(π_θ ∥ π_ref) on chosen  +  KL(π_θ ∥ π_ref) on rejected )",
                    "**ℒ**₍XPO₎  =  **ℒ**₍DPO₎  −  bonus",
                ]
            )
        case .rlhfReinforce:
            return (
                prose: "针对 prompt `*x*`、采样 completion `*y*` 与 judge reward `*R*`。没有 clipping 或 value head。`β` 是 advantage 中 KL 的 weight，不是独立 regulariser 中的系数。",
                equations: [
                    "*A*<sub>t</sub>         =  *R*  −  β · KL<sub>t</sub>                              (per-token advantage)",
                    "**ℒ**₍REINFORCE₎ =  − ∑<sub>t</sub>  *A*<sub>t</sub> · log π_θ(*y*<sub>t</sub> | *x*, *y*<sub><t</sub>)",
                ]
            )
        case .ppo:
            return (
                prose: "针对一个 prompt、两个 completions 与胜者 `*w*`。此处 advantage *不是* reward-model 的输出，而是在 judge 确定 chosen 和 rejected 后，从两者的 log-prob gap 推导而来。",
                equations: [
                    "*A*           =  log π_θ(*y*<sub>c</sub>)  −  log π_θ(*y*<sub>r</sub>)                              (per-sequence advantage)",
                    "*A*<sub>norm</sub>      =  ( *A*  −  mean )  ⁄  ( std + 1×10⁻⁸ )",
                    "ρ<sub>c</sub>         =  exp( log π_θ(*y*<sub>c</sub>)  −  log π_ref(*y*<sub>c</sub>) )",
                    "ρ<sub>r</sub>         =  exp( log π_θ(*y*<sub>r</sub>)  −  log π_ref(*y*<sub>r</sub>) )",
                    "**ℒ**₍surr₎      =  − min( ρ<sub>c</sub> · *A*<sub>norm</sub>,  clip( ρ<sub>c</sub>,  1−ε,  1+ε ) · *A*<sub>norm</sub> )\n=  − min( ρ<sub>r</sub> · (−*A*<sub>norm</sub>),  clip( ρ<sub>r</sub>,  1−ε,  1+ε ) · (−*A*<sub>norm</sub>) )",
                    "**ℒ**₍PPO₎       =  **ℒ**₍surr₎  +  β · ( mean( log π_θ  −  log π_ref ) )",
                ]
            )
        }
    }

    // MARK: Settings table

    private var settingsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("设置项")
                    .frame(width: 180, alignment: .leading)
                Text("默认值")
                    .frame(width: 110, alignment: .leading)
                Text("实际影响")
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.bottom, 6)

            Divider()
            ForEach(Array(settings.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top) {
                    Text(row.setting)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 180, alignment: .leading)
                    Text(row.defaultValue)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 110, alignment: .leading)
                    Text(row.explanation)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
        .padding(.top, 4)
    }

    private struct SettingRow {
        let setting: String
        let defaultValue: String
        let explanation: String
    }

    private var settings: [SettingRow] {
        // The first block is always the shared SFT substrate.
        let base: [SettingRow] = [
            .init(setting: "model", defaultValue: "Qwen/Qwen3-0.6B",
                  explanation: "Base model 的 Hugging Face id 或本地路径。加载时采用所选 quantisation，并配置 LoRA/DoRA/full-finetune adapters。"),
            .init(setting: "data", defaultValue: "auto",
                  explanation: "HF dataset id、本地目录或 JSONL。Trainer 的 `create_dataset` 会根据 `train_mode` 选择列名；对于内置默认 dataset，此过程自动完成。"),
            .init(setting: "train_type", defaultValue: "lora",
                  explanation: "可选 `lora`、`dora` 或 `full`。LoRA 为 attention/MLP projections 添加 low-rank adapters；DoRA 将 weight 分解为 magnitude 和 direction updates；`full` 对全部 parameter 进行 fine-tuning。"),
            .init(setting: "lora_parameters.rank", defaultValue: "8",
                  explanation: "LoRA adapters 的内部 rank。更高的 rank 意味着更大容量和更多 parameters。笔记本上常用 4–16；32+ 需要仔细规划 memory。"),
            .init(setting: "lora_parameters.scale", defaultValue: "20.0",
                  explanation: "原版指南采用论文约定描述 scaling factor：`(α/r) · B·A`。本机 mlx-lm 0.32.2 的 LoRA 层实际直接以 `scale` 乘以更新量；此处 `scale` 保持原值，不应再除以 `rank`。这是文档约定的区别，计算实现未改变。"),
            .init(setting: "lora_parameters.dropout", defaultValue: "0.0",
                  explanation: "LoRA 分支中的 Dropout。通常只在 dataset 很小，或 validation curve 出现 overfitting 时，才有必要设为大于 0。"),
            .init(setting: "num_layers", defaultValue: "16",
                  explanation: "为多少个 transformer layers 添加 LoRA adapters，从顶部开始计数。较小 model 可使用全部 layers；较大 model 可仅使用最后 N 个。"),
            .init(setting: "batch_size", defaultValue: "1",
                  explanation: "每个 device 的 minibatch size。实际 batch size 为 `batch_size · gradient_accumulation_steps`。"),
            .init(setting: "gradient_accumulation_steps", defaultValue: "1",
                  explanation: "在执行一次 optimiser step 前累积的 micro-batches 数量。Memory 紧张时，可增加此值模拟更大的 effective batch。"),
            .init(setting: "iters / epochs", defaultValue: "iters=1000",
                  explanation: "采用固定 iterations，或完整遍历 dataset 的次数。设置 `epochs > 0` 会将 runner 切换为按 epoch 计数的训练。"),
            .init(setting: "learning_rate", defaultValue: "1e-5",
                  explanation: "Peak learning rate。LoRA 常用范围为 1e-5 至 5e-5；full fine-tuning 通常采用 1e-6 至 5e-6。"),
            .init(setting: "steps_per_report", defaultValue: "10",
                  explanation: "每 N 个 optimiser steps 输出一行 loss/reward，同时驱动实时 metrics 更新。"),
            .init(setting: "steps_per_eval", defaultValue: "200",
                  explanation: "每 N 个优化器 steps 执行一次验证。必须为正整数；当前运行器不接受 -1。"),
            .init(setting: "val_batches", defaultValue: "25",
                  explanation: "每次评估使用的验证小批次数量。必须为非负整数；当前运行器不支持用 -1 表示整个验证集。"),
            .init(setting: "save_every", defaultValue: "100",
                  explanation: "每隔多少个 optimiser steps，将 adapter weights 保存为 `<adapter_path>/<iter>_adapters.safetensors` checkpoint。"),
            .init(setting: "max_seq_length", defaultValue: "2048",
                  explanation: "每条示例 token length 的硬性上限。超过上限的示例会被截断；此值影响 KV-cache 的 memory 预算。"),
            .init(setting: "grad_checkpoint", defaultValue: "true",
                  explanation: "将每个 transformer layer 的 forward 改为使用 `mx.checkpoint`。Activation memory 大致减半，代价是每层额外执行一次 recompute。"),
            .init(setting: "efficient_long_context", defaultValue: "false",
                  explanation: "将长 sequences 切分为 `seq_step_size` chunks，并在其间复用 KV-cache。当 `max_seq_length` 较大且出现 OOM 时可启用。"),
            .init(setting: "seq_step_size", defaultValue: "512",
                  explanation: "`efficient_long_context` 使用的 chunk size。256–1024 是常见范围；更小的值占用更少 memory，但需要更多 recompute。"),
            .init(setting: "mask_prompt", defaultValue: "false",
                  explanation: "为 true 时，仅在示例的 completion 部分计算 loss，prompt 被 mask。SFT 和 DPO 内部强制采用此行为；该 flag 用于自定义 dataset。"),
            .init(setting: "fuse", defaultValue: "true",
                  explanation: "训练后将 LoRA weights 合并回 base model，并保存独立 checkpoint。关闭时将 adapter 文件分开保留。"),
            .init(setting: "lm_studio_name", defaultValue: "—",
                  explanation: "填写后，会在 LM Studio models 目录下使用该名称写入 merged model，作为 `adapter_path` 输出的补充或替代。"),
            .init(setting: "resume_adapter_file", defaultValue: "—",
                  explanation: "此前保存的 `adapters.safetensors` 路径，用于 warm-start。适合继续长时间运行，或构建先 SFT 后 DPO 的 pipeline。"),
            .init(setting: "seed", defaultValue: "0",
                  explanation: "`numpy` 和 `mlx.core` 的 Seed。固定此值有助于复现运行；但不同 driver 版本的 MLX GPU kernels 不保证 bit-exact。"),
            .init(setting: "load_in_4bits / 6 / 8 / mxfp4", defaultValue: "4-bit",
                  explanation: "加载 base model 时使用的 Quantisation。`4-bit` 和 `MXFP4` 最激进；8-bit 是 preference training 较稳妥的默认选择。"),
            .init(setting: "qat_enable", defaultValue: "false",
                  explanation: "在首次 optimiser step 后（可配置）为每个 `nn.Linear` 安装 symmetric fake-quantise hook。Gradients 通过 straight-through estimator 传播，使 model 在训练时模拟 inference quantisation。"),
            .init(setting: "qat_bits / group_size / start_step / interval", defaultValue: "8 / 64 / 1 / 1",
                  explanation: "依次为 bit-width、group size（0 表示 per-tensor）、首次启用的 optimiser step，以及重新 projection 的间隔。默认值对应 MLX 的 affine quantiser scheme。"),
            .init(setting: "test / test_batches", defaultValue: "false / 100",
                  explanation: "当 `test` 为 true 时，runner 在训练结束后评估留出的 test split，并将结果写入运行记录。"),
        ]
        return base + modeSpecific
    }

    private var modeSpecific: [SettingRow] {
        switch mode {
        case .sft:
            return [
                .init(setting: "prompt_feature / completion_feature", defaultValue: "auto",
                      explanation: "覆盖 `(prompt, completion)` schema 的列名。留空时使用 trainer 默认值。"),
                .init(setting: "messages_feature / system_feature", defaultValue: "auto",
                      explanation: "覆盖 chat-template `messages` schema 的列名，适用于包含 multi-turn conversations 的 dataset。"),
                .init(setting: "text_feature", defaultValue: "auto",
                      explanation: "覆盖 raw-pretraining `text` schema 的列名。"),
            ]

        case .dpo:
            return [
                .init(setting: "beta", defaultValue: "0.1",
                      explanation: "DPO sigmoid 中的 Temperature。较低时更新更温和，较高时偏离 reference 的力度更大。"),
                .init(setting: "dpo_cpo_loss_type", defaultValue: "sigmoid",
                      explanation: "Loss 变体：`sigmoid`（普通 DPO）、`hinge`（margin loss）、`ipo`（围绕 `1/(2β)` 的 squared error）、`dpop`（带 reference-drift penalty 的 DPO）。"),
                .init(setting: "delta", defaultValue: "50.0",
                      explanation: "`dpop` reference-drift penalty 的系数。仅在 `dpo_cpo_loss_type = dpop` 时使用。"),
                .init(setting: "reference_model_path", defaultValue: "—",
                      explanation: "冻结 reference model 的路径或 HF id。留空时，trainer 创建 base model 的第二份副本，因此 GPU memory 占用增加。"),
                .init(setting: "prompt_feature / chosen_feature / rejected_feature", defaultValue: "auto",
                      explanation: "覆盖 preference schema 的列名。"),
            ]

        case .ftpo:
            return [
                .init(setting: "lambda_mse_target", defaultValue: "0.05", explanation: "对 chosen 和 rejected 的 target logits 过度漂移施加的 penalty。"),
                .init(setting: "tau_mse_target", defaultValue: "1.0", explanation: "触发 target MSE penalty 前允许的 target-logit 绝对漂移幅度。"),
                .init(setting: "lambda_mse", defaultValue: "0.4", explanation: "使全部 non-target vocabulary logits 保持接近 reference 的 penalty。"),
                .init(setting: "clip_epsilon_logits", defaultValue: "2.0", explanation: "Logit 空间中的 preference margin 和 clipping threshold，必须为正。"),
                .init(setting: "reference_model_path", defaultValue: "—", explanation: "冻结的 reference model；留空时使用 base model 的冻结副本。"),
            ]

        case .cpo:
            return [
                .init(setting: "beta", defaultValue: "0.1",
                      explanation: "CPO sigmoid 中的 Temperature。"),
                .init(setting: "dpo_cpo_loss_type", defaultValue: "sigmoid",
                      explanation: "Loss 变体。CPO 支持与 DPO 相同的四个选项；此处 `dpop` 表示 policy-side drift penalty。"),
                .init(setting: "delta", defaultValue: "50.0",
                      explanation: "CPO drift penalty 的系数。仅在 `loss_type = dpop` 时使用。"),
                .init(setting: "chosen_feature / rejected_feature", defaultValue: "auto",
                      explanation: "覆盖列名。CPO 的 dataset 格式与 DPO 相同，不需要单独的 `prompt` 列。"),
            ]

        case .orpo:
            return [
                .init(setting: "beta", defaultValue: "0.1",
                      explanation: "ORPO log-odds 项的乘数。"),
                .init(setting: "reward_scaling", defaultValue: "1.0",
                      explanation: "为未来变体保留；当前 ORPO loss 不将它作为独立乘数使用。"),
                .init(setting: "chosen_feature / rejected_feature / preference_score_feature", defaultValue: "auto",
                      explanation: "覆盖列名。ORPO trainer 需要 `chosen`、`rejected`，并可选用 `preference_score`。"),
            ]

        case .grpo:
            return [
                .init(setting: "group_size", defaultValue: "4",
                      explanation: "每个 prompt 采样的 completions 数量。更高时 advantage estimates 的 variance 更低，但每个 step 的计算量更大。"),
                .init(setting: "beta", defaultValue: "0.1",
                      explanation: "相对于 reference model 的 KL penalty 系数。设为 0 时完全禁用 KL。"),
                .init(setting: "epsilon / epsilon_high", defaultValue: "1e-4 / —",
                      explanation: "非对称 PPO clip range（`epsilon_low`、`epsilon_high`）。`epsilon_high` 留空时，两侧均采用 `epsilon`，即经典 PPO。"),
                .init(setting: "max_completion_length", defaultValue: "512",
                      explanation: "每个 completion 最多采样的 tokens 数量，影响每个 step 的耗时预算。"),
                .init(setting: "temperature / top_p / top_k / min_p", defaultValue: "0.8 / 0.95 / 20 / 0.0",
                      explanation: "训练循环内 generation 的 Sampler 设置。`temperature=0` 无效；提高此值可增加多样性，降低则更接近确定性的 completions。"),
                .init(setting: "reward_functions", defaultValue: "—",
                      explanation: "要使用的 reward function names，以逗号分隔。留空时加载默认 DeepSeek-R1 系列：`r1_accuracy`、`r1_int`、`r1_strict_format`、`r1_soft_format`、`r1_count_xml`。"),
                .init(setting: "reward_functions_file", defaultValue: "—",
                      explanation: "自定义奖励函数的 Python 文件路径。文件应通过 `@register_reward_function()` 注册函数，并在 `reward_functions` 中填写注册名称；`load_reward_functions_from_file` 会导入该文件。"),
                .init(setting: "reward_weights", defaultValue: "—",
                      explanation: "与 reward function 列表对应的 weights，以逗号分隔。留空时全部 weights 均为 1.0。"),
                .init(setting: "importance_sampling_level", defaultValue: "—",
                      explanation: "可选 `token`（默认）、`sequence` 或留空。`sequence` 按每个 sequence 对 log-ratio 求平均；GSPO 论文建议用它改善稳定性。"),
                .init(setting: "grpo_loss_type", defaultValue: "grpo",
                      explanation: "可选 `grpo`（对全部 tokens 求 mean）、`bnpo`（按实际 token count 归一化）或 `dr_grpo`（除以 `batch_size · max_tokens`）。"),
                .init(setting: "reference_model_path", defaultValue: "—",
                      explanation: "Reference model 的路径或 HF id，用于 KL，以及 `importance_sampling_level != none` 时的 importance ratio。"),
            ]

        case .onlineDPO:
            return [
                .init(setting: "beta", defaultValue: "0.1",
                      explanation: "DPO 的 temperature。"),
                .init(setting: "dpo_cpo_loss_type", defaultValue: "sigmoid",
                      explanation: "Loss 变体，与 DPO 的四个选项相同。"),
                .init(setting: "delta", defaultValue: "50.0",
                      explanation: "`dpop` loss 的 drift-penalty 系数。"),
                .init(setting: "judge", defaultValue: "Qwen/Qwen3-0.6B",
                      explanation: "Judge LLM 的 Hugging Face id / 本地路径，或原文字串 `human`。使用 `human` 时，runner 会暂停，请你标注每个 pair。"),
                .init(setting: "judge_system", defaultValue: "—",
                      explanation: "发给 LLM judge 的 System prompt，应作为评判标准。简短、具体、明确通常效果最好。"),
                .init(setting: "max_completion_length", defaultValue: "512",
                      explanation: "训练循环内 generation 时，每个 completion 最多采样的 tokens 数量。"),
                .init(setting: "temperature", defaultValue: "0.8",
                      explanation: "Policy 的 Sampling temperature。较低时两个 completions 更相似，judge 面临的比较也更困难。"),
                .init(setting: "reference_model_path", defaultValue: "—",
                      explanation: "冻结 reference model 的路径或 HF id。留空时使用 base model 的第二份副本。"),
            ]

        case .xpo:
            return [
                .init(setting: "beta", defaultValue: "0.1",
                      explanation: "DPO 的 temperature。"),
                .init(setting: "alpha", defaultValue: "1e-5",
                      explanation: "Exploration-bonus 系数。单个 float 表示固定值；列表（如 `[1e-4, 1e-5, 1e-6]`）可提供按 epoch 随训练衰减的 schedule。"),
                .init(setting: "dpo_cpo_loss_type", defaultValue: "sigmoid",
                      explanation: "基础 DPO loss 的变体。"),
                .init(setting: "delta", defaultValue: "50.0",
                      explanation: "`dpop` 的 drift-penalty 系数。"),
                .init(setting: "judge", defaultValue: "Qwen/Qwen3-0.6B",
                      explanation: "用于 pairwise judge 的 LLM 或 `human`。"),
                .init(setting: "judge_system", defaultValue: "—",
                      explanation: "Judge 使用的评判标准 system prompt。"),
                .init(setting: "max_completion_length", defaultValue: "512",
                      explanation: "采样 completion 的最大 length。"),
                .init(setting: "temperature", defaultValue: "0.8",
                      explanation: "Policy 的 Sampling temperature。"),
                .init(setting: "reference_model_path", defaultValue: "—",
                      explanation: "冻结 reference model 的路径或 HF id。"),
            ]

        case .rlhfReinforce:
            return [
                .init(setting: "beta", defaultValue: "0.1",
                      explanation: "Per-token advantage（`A = R − β · KL`）中 KL 项的系数。设为 0 时禁用 KL regularisation。"),
                .init(setting: "judge", defaultValue: "Qwen/Qwen3-0.6B",
                      explanation: "产生 scalar reward 的 LLM judge。Judge 只加载一次，每个 (prompt, completion pair) 调用一次。"),
                .init(setting: "max_completion_length", defaultValue: "128",
                      explanation: "每个 completion 最多采样的 tokens 数量。RLHF-REINFORCE 对 variance 敏感，因此较短的 completions 通常更有帮助。"),
                .init(setting: "reference_model_path", defaultValue: "—",
                      explanation: "用于计算 per-token KL 的冻结 reference model。留空时使用 base model 的第二份副本。"),
            ]

        case .ppo:
            return [
                .init(setting: "beta", defaultValue: "0.1",
                      explanation: "加在 clipped surrogate 之外的 KL regulariser weight。"),
                .init(setting: "epsilon", defaultValue: "0.2",
                      explanation: "Importance ratio 的 PPO clip range。使用经典值起步；降低此值可使更新更保守。"),
                .init(setting: "dpo_cpo_loss_type", defaultValue: "sigmoid",
                      explanation: "Loss 变体。Chosen/rejected 的划分相同，只改变内部 objective；runner 会原样传递该选项。"),
                .init(setting: "delta", defaultValue: "50.0",
                      explanation: "`dpop` 的 drift-penalty 系数。"),
                .init(setting: "judge", defaultValue: "Qwen/Qwen3-0.6B",
                      explanation: "Pairwise judge，可用 LLM 或 `human`。"),
                .init(setting: "judge_system", defaultValue: "—",
                      explanation: "Judge 使用的评判标准 system prompt。"),
                .init(setting: "max_completion_length", defaultValue: "512",
                      explanation: "采样 completion 的最大 length。"),
                .init(setting: "temperature", defaultValue: "0.8",
                      explanation: "Policy completions 的 Sampling temperature。"),
                .init(setting: "reference_model_path", defaultValue: "—",
                      explanation: "用于 importance ratio 的冻结 reference model。"),
            ]
        }
    }

    // MARK: Dataset format

    private var datasetFormat: String {
        switch mode {
        case .sft:
            """
            SFT 支持三种格式，优先级依次为：\n\n1. **chat messages**：由包含 `"role"`、`"content"` 的 dict 组成的 `messages` 列表，可带可选的 `system` 字段。Trainer 会应用 tokenizer 的 chat template。\n2. **prompt / completion**：明确的 `(prompt, completion)` 字符串；当 `mask_prompt = true` 时，prompt 不计入 loss。\n3. **text**：单个 `text` 字符串，用于原始 next-token pretraining 风格的 fine-tuning。\n\nSFT 的内置默认 dataset 是 `mlx-community/JOSIE-v2-Instruct-5K`，包含 5K 行 messages 格式的 instruction-tuning 数据。
            """
        case .dpo:
            """
            DPO 需要每行对应一个 preference 的 dataset，至少包含 `chosen` 和 `rejected`。`prompt` 列可选但建议提供；若存在，会在 tokenisation 前添加到两个 completions 的开头。\n\n内置默认值为 `mlx-community/Human-Like-DPO`，采用 prompt/chosen/rejected 格式。
            """
        case .ftpo:
            """
            FTPO 接受 Hugging Face dataset repo 或本地 Antidoom JSONL 文件：`train.jsonl`，以及可选的 `valid.jsonl` 和 `test.jsonl`。每行必须包含 `context_with_chat_template`、`rejected_decoded` 和 `multi_chosen_decoded`。最后一个字段包含一个或多个可接受的 next-token continuations。
            """
        case .cpo:
            """
            与 DPO 相同：每个 preference 一行，包含 `chosen` 和 `rejected`。CPO 不使用 `prompt` 列。
            """
        case .orpo:
            """
            ORPO 需要 `chosen` 和 `rejected`，且**不需要** `prompt` 列。Chosen 与 rejected 字符串会原样使用，由 model 自行学习 prompt–completion 的边界。可选的 `preference_score`（float）列用于缩放每条示例的 gradient。\n\n内置默认值为 `mlx-community/Josiefied-Qwen3-dpo-v1-flat`，是展平后的 DPO dataset。
            """
        case .grpo:
            """
            GRPO 至少需要 `prompt` 字段；使用默认 `r1_*` reward functions 时还需要 `answer` 字段。Trainer 为每行生成的 4-tuple 是 `(prompt_tokens, answer_tokens, prompt_text, answer_text)`；可选的第 5 个元素是 `type`，用于按类别切换 reward functions。\n\n内置默认值为 reasoning dataset `mlx-community/Dolci-Think-RL-7B-2k`。
            """
        case .onlineDPO, .xpo, .rlhfReinforce, .ppo:
            """
            这些 online loops 在训练时只需要 `prompt` 字段。Completions 由 policy 自身采样，(chosen, rejected) pair 或 scalar reward 来自 judge，而非 dataset。\n\n内置默认值为 `mlx-community/Human-Like-DPO`，因为它体积较小且带有标准 prompt 列。
            """
        }
    }

    // MARK: When to use

    private var whenToUse: String {
        switch mode {
        case .sft:
            """
            **通常应当首先进行。** SFT 建立 model 的基本行为，包括语气、格式、拒绝方式和领域知识。本列表中的其他算法一般假设你已有大致适合任务的 SFT checkpoint，并在其上进一步 fine-tune alignment。\n\n常用起始值：`lr=1e-5`、`batch_size=1`、`grad_accum=8`、`iters=1000`、`rank=8`、`scale=20.0`。
            """
        case .dpo:
            """
            适合在 SFT 后、已有静态 preference dataset（如 UltraFeedback、HelpSteer、Anthropic HH）时使用。原指南将 DPO 描述为计算开销较低的 preference 算法：每个 completion 在 policy 上一次 forward pass，在 reference 上一次 forward pass。\n\n标签有噪声或相互矛盾时可用 `loss_type=ipo`；若 policy 出现 SFT loss 未能约束的 reference 漂移，可用 `loss_type=dpop`。
            """
        case .ftpo:
            """
            当 reasoning model 反复进入已知的不良 continuation loops，且已有 Antidoom 数据行标明 rejected 分支和可接受替代项时，可使用 FTPO 定向修复。它不能替代广泛的 SFT 或 DPO alignment。
            """
        case .cpo:
            """
            适用场景与 DPO 类似，但尤其适合 GPU 放不下第二个 reference model，或希望更新更激进的情况。通常应搭配比 DPO 略小的 `beta`。
            """
        case .orpo:
            """
            希望用单阶段方案替代“先 SFT 后 DPO”时使用。ORPO 在小型 chat models 上已有良好效果，也适合带每条示例 preference score 的 dataset，例如 UltraFeedback 风格的 `score_chosen - score_rejected`。
            """
        case .grpo:
            """
            适用于拥有*可验证* reward（数学正确性、代码执行、格式合规等），而非标注 preference dataset 的情况。GRPO 是近期 reasoning models（DeepSeek-R1、Qwen3-Instruct reasoning mode）使用的重要方法。其 completions 可能与 SFT 输出明显不同，这正是训练目的。
            """
        case .onlineDPO:
            """
            适用于有较强 LLM judge 或人类参与评审，并能持续从基础 prompt distribution 采样的情况。Online DPO 可避免静态 DPO 的 off-policy gap，适合同一 model 的迭代改进。
            """
        case .xpo:
            """
            当 online DPO 向 reference completion 收缩，而你希望引入可控探索时使用。可先尝试 `alpha=1e-4`，再保持固定或随 epochs 逐步降低。
            """
        case .rlhfReinforce:
            """
            适合教学或简化版 RLHF。使用现代 LLM judge 时，REINFORCE 在较短 completions 上可与 PPO 竞争，且更容易调试。它对 judge 质量和 learning rate 也很敏感，可从 `lr=5e-6`、`beta=0.05` 开始。
            """
        case .ppo:
            """
            PPO 是经典、表达能力强、也需要细调的方法。其他 loops 在 judge 能可靠衡量的 metric 上表现不足，且你有时间共同调整 `epsilon` 和 `beta` 时，可考虑使用。始终记录 `clip_fraction`：若持续为 0%，policy 可能没有变化；若持续 >30%，则每个 step 的变化可能过大。
            """
        }
    }

    // MARK: Tips

    private var tipsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.tint)
                        .padding(.top, 2)
                    Text(.init(MathTypesetter.richify(tip)))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var tips: [String] {
        switch mode {
        case .sft:
            [
                "先用内置默认 dataset 运行少量 iters，通常应在 100 steps 内看到 `loss` 下降。若没有，可能是 dataset 列名不符合 SFT 要求，此时 trainer 会报 `Unsupported data format`。",
                "出现 OOM 时，先启用 `grad_checkpoint`，再降低 `max_seq_length`，然后尝试 `efficient_long_context`，并将 `seq_step_size` 设为 256。",
                "计划为 LM Studio 发布 4-bit 或 8-bit adapter 时，QAT 最有用。开发阶段可先关闭，因为它会增加明显的 per-step 开销。",
                "Trainer 中 SFT 的默认行为是 `mask_prompt=true`；提供此 flag 是为了支持混合 masked 与 unmasked 数据行的自定义 dataset。",
            ]
        case .dpo:
            [
                "可将 `reference_model_path` 设为 SFT checkpoint，而非原始 base model，使 implicit reward 反映 `Δ log-prob vs the SFT model`，与标签所描述的相对偏好对应。",
                "观察实时 metrics 中的 `accuracies` 和 `margins`。`accuracies > 0.7` 且 `margins > 0` 表示 loss 正在产生效果；若 `margins` 进入平台期，可略微提高 `beta`。",
                "出现 NaNs 时，常见原因是在当前 `lr` 下使用 `loss_type=dpop` 且 `delta` 过大，可先将 `delta` 降至 10。",
                "这里也支持 `efficient_long_context`。回答较长的 preference dataset（例如完整文档 diffs）可受益于分块 forward passes。",
            ]
        case .ftpo:
            [
                "长时间运行前先核对 Antidoom 字段名；FTPO 不接受普通 DPO chosen/rejected 数据行。",
                "从上游默认值和较小 learning rate 开始，MSE 项旨在限制修复影响的范围。",
                "保持 `clip_epsilon_logits` 为正。值较低时，chosen token 达到较小 margin 后就会停止更新。",
                "除非有意采用其他锚点，否则冻结 reference 应使用与 Antidoom 生成目标相同的 checkpoint。",
            ]
        case .cpo:
            [
                "使用比 DPO 更小的 `beta`，可从 0.05 开始。没有 reference 项时 gradient 缺少锚点，较大的 `beta` 容易更新过度。",
                "原指南认为 CPO 适合无法容纳 base model 第二份副本的 integrated Apple Silicon GPU 场景；具体 reference 需求以所选算法和本机后端实现为准。",
                "若 validation reward 很早进入平台期，可切换到 `dpop` loss 并添加 `delta` 以限制漂移。",
            ]
        case .orpo:
            [
                "确认 dataset 中没有 `prompt` 列。如果提供它，ORPO 可能将 prompt 拼接到 chosen/rejected 中，这通常不是预期行为。",
                "训练前应将 `preference_score` 大致归一化到 0..1；分数过大会将 loss 推入 `log_sigmoid` 的饱和区域。",
                "ORPO 不需要独立的 SFT warm-up，同一 loss 也会改善 NLL。若原计划为“先 SFT 后 DPO”，可使用这一单阶段方案。",
            ]
        case .grpo:
            [
                "可从默认 DeepSeek-R1 reward 系列开始。它们面向 `<reasoning>...</reasoning><answer>...</answer>` 格式的 completions；数据不符合此结构时，应编写自定义 reward function。",
                "常见失败情况是 `hit_max_tokens_ratio = 1.0`：model 一直生成到上限，始终无法到达 answer tag。可降低 `max_completion_length`，或加强 format reward。",
                "原指南建议 `clip_ratio_total` 在 0.05–0.2 范围。低于此范围时 advantage 信号可能较弱；高于此范围时 policy 的每个 step 可能过于激进。",
                "对于包含较长 completions 的 reasoning 任务，`importance_sampling_level = sequence` 可帮助改善稳定性。",
                "GRPO 的每个 step 都包含 generation pass，因此较慢。原指南估计，相同 `batch_size` 下耗时可能为 SFT step 的 4–8x；实际速度取决于配置与 model。",
            ]
        case .onlineDPO:
            [
                "Judge system prompt 是整个 config 中影响很大的文字。应写成具体的条目式评判标准，而不是模糊地询问“哪个更好？”。",
                "Policy 可采用 `temperature ≈ 0.8`、`top_p=0.95`。过低会使两个 completions 相同，过高可能使 judge 的标签近似随机。",
                "设置 `judge = \"human\"` 后，runner 会暂停并要求你标注每个 pair；请预留相应时间，或将 `batch_size` 降为 1。",
            ]
        case .xpo:
            [
                "默认 `alpha = 1e-5` 很小。若 completions 与 reference 几乎无法区分，可将 `alpha` 提高到 `1e-4`，并观察实时 metrics 中的 `exploration_bonus`。",
                "对于 3-epoch 运行，可尝试 `alpha = [1e-4, 1e-5, 1e-6]`：前期探索较强，在最后一个 epoch 逐步衰减。",
            ]
        case .rlhfReinforce:
            [
                "使用较小的 `max_completion_length`，128 是一个起点。REINFORCE variance 会随 trajectory length 增长。",
                "可优先尝试 `lr=5e-6` 而非 `1e-5`；REINFORCE 没有 clipping 来限制过度激进的 step。",
                "始终记录 `rewards` 和 `kl_penalty`。若 `kl_penalty` 上升而 `rewards` 进入平台期，policy 可能在向 judge 无法察觉的方向漂移。",
            ]
        case .ppo:
            [
                "记录 `clip_fraction`。如果持续 > 0.3，则每个 step 的 policy 变化过大，可降低 `lr` 或将 `epsilon` 收紧至 0.1。",
                "`epsilon = 0.2` 是原始 PPO 默认值，也是合理起点。至少观察 policy 完成一次完整遍历后，再考虑降低。",
                "过小的 KL weight（`beta`）会让 policy 远离 reference；过大的 `beta` 则可能在学到内容前就抑制 policy。可从 0.1 开始，依据 `kl_penalty` 日志调整。",
                "Judge 对效果的影响可能大于算法。PPO 会放大 judge 奖励的行为，无论这些行为是否符合你的真实目标。",
            ]
        }
    }
}

// MARK: - Foundation Articles
//
// The training-loop articles above describe *what loss to minimise*.
// These three foundation articles describe the orthogonal pieces that
// are configured separately on the Train page: which tensors are
// trainable, how the optimiser turns gradients into updates, and how
// (or whether) the forward pass is quantised.

/// Shared scaffolding for a long-form article. Mirrors the
/// AlgorithmArticle layout (header → overview → intuition → math →
/// settings table → tips) so the page reads as a single wiki.
private struct FoundationArticle<Body: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    @ViewBuilder let content: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: symbol)
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.largeTitle, design: .rounded).bold())
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 14)
    }
}

/// Reusable section header / text block for a wiki-style article.
private struct ArticleSection: View {
    let title: String
    let text: String

    init(_ title: String, _ text: String) {
        self.title = title
        self.text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
            Text(.init(MathTypesetter.richify(text)))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ArticleTips: View {
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("建议与注意事项")
                .font(.title3.bold())
            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.tint)
                        .padding(.top, 2)
                    Text(.init(MathTypesetter.richify(tip)))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct SettingsTable: View {
    struct Row {
        let setting: String
        let defaultValue: String
        let explanation: String
    }

    let rows: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("设置项")
                    .frame(width: 200, alignment: .leading)
                Text("默认值")
                    .frame(width: 110, alignment: .leading)
                Text("实际影响")
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.bottom, 6)

            Divider()
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top) {
                    Text(row.setting)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 200, alignment: .leading)
                    Text(row.defaultValue)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 110, alignment: .leading)
                    Text(row.explanation)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Math rendering
//
// Math equations are written in the article source as plain strings
// of Unicode math (∑, β, ², ₁, →, ‖·‖, ≈, ε, λ, …) with optional
// Markdown emphasis for variables (`*x*`) and vectors (`**v**`).
// Authors may also wrap sub/superscript runs in `<sub>…</sub>` and
// `<sup>…</sup>` tags; `MathTypesetter.richify` translates those
// into Unicode glyphs before the string is handed to SwiftUI's
// Markdown renderer (which does not understand HTML-style tags).
// `MathBlock` typesets the result with a serif font inside a tinted
// panel; `MathInline` does the same in-line for prose paragraphs.

/// Translates author-friendly `<sub>…</sub>` / `<sup>…</sup>` markup
/// into Unicode subscript/superscript glyphs, so a Markdown `Text`
/// renders it correctly. Multi-character content inside the tags is
/// passed through to the inner run (no Unicode glyph exists for "ₖₜ"),
/// which preserves the readable shape in serif italics and avoids the
/// confusing raw-tag leak users were seeing on screen.
enum MathTypesetter {
    /// Maps ASCII/digit runs to Unicode subscript glyphs where a
    /// single character exists; otherwise returns the input unchanged.
    private static let subscripts: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
        "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ",
        "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "o": "ₒ",
        "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ",
        "v": "ᵥ", "x": "ₓ",
    ]

    private static let superscripts: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
        "n": "ⁿ", "i": "ⁱ",
    ]

    /// Translates `<sub>…</sub>` / `<sup>…</sup>` / `<super>…</super>`
    /// runs into Unicode glyphs. The parser accepts both `<sup>` and
    /// `<super>` as opening forms and uses the matching closer
    /// (`</sup>` or `</super>`) — they all map to the superscript
    /// glyph table. Nested tags are not supported (they are uncommon
    /// in this codebase and the parser would just get fragile).
    static func richify(_ source: String) -> String {
        // Quick exit: nothing to translate.
        guard source.contains("<sub>") || source.contains("<sup>") || source.contains("<super>") else { return source }
        var output = ""
        output.reserveCapacity(source.count)
        var i = source.startIndex
        while i < source.endIndex {
            if let sub = parseTag(source, at: i, open: "sub>", close: "</sub>") {
                output.append(contentsOf: translate(sub, table: subscripts))
                i = source.index(i, offsetBy: "<sub>".count + sub.count + "</sub>".count)
                continue
            }
            if let sup = parseSuper(source, at: i) {
                output.append(contentsOf: translate(sup.inner, table: superscripts))
                i = source.index(i, offsetBy: sup.openCount + sup.inner.count + sup.closeCount)
                continue
            }
            output.append(source[i])
            i = source.index(after: i)
        }
        return output
    }

    /// Result of `parseSuper`: the inner content plus how many
    /// characters the matching open and close tags each consumed,
    /// so the caller's index arithmetic stays accurate for both
    /// `<sup>` (4 chars) and `<super>` (7 chars).
    private struct SupHit {
        let inner: String
        let openCount: Int
        let closeCount: Int
    }

    /// Matches `<sup>…</sup>` and `<super>…</super>` at the given
    /// index and returns the inner content. Returns nil if neither
    /// opener appears at `i`.
    private static func parseSuper(_ source: String, at i: String.Index) -> SupHit? {
        let openers: [(String, String)] = [("<super>", "</super>"), ("<sup>", "</sup>")]
        for (open, close) in openers {
            guard source[i...].hasPrefix(open) else { continue }
            let afterOpen = source.index(i, offsetBy: open.count)
            guard let closeRange = source.range(of: close, range: afterOpen..<source.endIndex) else { continue }
            return SupHit(
                inner: String(source[afterOpen..<closeRange.lowerBound]),
                openCount: open.count,
                closeCount: close.count
            )
        }
        return nil
    }

    /// If `source` starting at `i` opens a `<sub>…</sub>` tag,
    /// returns the inner content. Returns nil if no tag starts here.
    private static func parseTag(_ source: String, at i: String.Index, open: String, close: String) -> String? {
        let openFull = "<" + open
        guard source[i...].hasPrefix(openFull) else { return nil }
        let afterOpen = source.index(i, offsetBy: openFull.count)
        guard let closeRange = source.range(of: close, range: afterOpen..<source.endIndex) else { return nil }
        return String(source[afterOpen..<closeRange.lowerBound])
    }

    private static func translate(_ inner: String, table: [Character: Character]) -> String {
        var out = ""
        out.reserveCapacity(inner.count)
        for ch in inner {
            if let mapped = table[ch] {
                out.append(mapped)
            } else {
                out.append(ch)
            }
        }
        return out
    }
}



/// Block-level equation: a tinted panel with a left accent rule and
/// the equation body rendered as rich text. Selectable so the user
/// can copy a formula.
struct MathBlock: View {
    let source: String
    var caption: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(LinearGradient(
                    colors: [.accentColor.opacity(0.85), .accentColor.opacity(0.20)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(.init(MathTypesetter.richify(source)))
                    .font(.system(.body, design: .serif))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                if let caption {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.tint.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.tint.opacity(0.20), lineWidth: 0.5)
        )
    }
}

/// Inline math: same serif font, no panel chrome. Used inside the
/// prose paragraphs of "Intuition" / "Overview" sections.
struct MathInline: View {
    let source: String

    var body: some View {
        Text(.init(MathTypesetter.richify(source)))
            .font(.system(.body, design: .serif).italic())
            .textSelection(.enabled)
    }
}

// MARK: Adaptation Article

/// Covers the three `train_type` values: `lora` (low-rank adapters on
/// the attention/MLP projections), `dora` (the same with an extra
/// magnitude-direction decomposition), and `full` (every weight is
/// trainable). Backed by `mlx_lm_lora.utils.from_pretrained`, which
/// wraps the base model with `linear_to_lora_layers` and applies the
/// chosen quantisation.
private struct AdaptationArticle: View {
    @Binding var config: TrainingConfig

    var body: some View {
        FoundationArticle(
            title: "Adaptation methods",
            subtitle: "哪些 tensor 接收 gradients",
            symbol: "square.stack.3d.up"
        ) {
            ArticleSection("概述", """
                mlx-lm-lora 的每个 trainer 都使用由 `mlx_lm_lora.utils.from_pretrained` 加载的同一 base model。`lora`、`dora` 与 `full` 的区别在于哪些 tensor **可训练**，以及如何计算 gradients。LoRA 冻结 base model，为每个目标 linear layer 学习 low-rank update；DoRA 保留相同的 low-rank update，但将组合 weight 分解为 magnitude vector 与 direction matrix，使两者可独立调整；`full` 则解冻整个 model。
                """)

            ArticleSection("直观理解", """
                • **LoRA** 假设最优 weight change `ΔW` 可由低 rank 表达：`ΔW = (α/r) · B · A`，其中 `A ∈ R^{r×in}`、`B ∈ R^{out×r}`，且 `r ≪ min(in, out)`。对于 `r=8` 的 7B model，可训练 parameters 可从约 7B 降至约 4M。\n• **DoRA** 将 frozen + LoRA weight 分解为 unit-norm direction `V` 和可学习的 magnitude `m`，写作 `W' = m · V / ‖V‖`。其经验依据是 full fine-tuning 对 direction 与 magnitude 的更新幅度通常不同，DoRA 在接近 LoRA parameter count 的条件下模拟这一行为。\n• **`full` fine-tuning** 对每个 weight 都进行训练。Optimiser state 与 parameter count 成正比，原指南估计 fp16 的 7B model 约需 28 GB 的 activation + optimiser memory；笔记本上超过 1B 规模时通常较难使用。\n• 三者共用 forward pass 的基础机制，变化主要是传给 `nn.value_and_grad(model, …)` 的 parameter 列表。因此上方各算法可搭配不同 adaptation method。
                """)

            VStack(alignment: .leading, spacing: 10) {
                Text("Objective（数学形式）")
                    .font(.title3.bold())
                Text(.init(MathTypesetter.richify("令 *W*<sub>0</sub> ∈ ℝ<sup>out × in</sup> 为冻结的 base weight，*x* 为输入，*y* 为目标 `nn.Linear` layer 的输出。")))
                    .fixedSize(horizontal: false, vertical: true)

                Text("**LoRA** (Hu et al., 2021)")
                    .font(.body.bold())
                MathBlock(source: """
                    *A*  ~  𝒩( 0,  σ² )           (initialised)
                    *B*   =  **0**                 (initialised — first step is a no-op)
                    Δ*W*  =  ( α ⁄ *r* )  ·  *B* · *A*
                    *y*   =  ( *W*<sub>0</sub> + Δ*W* ) · *x*  +  dropout( Δ*W* · *x* )       (if dropout > 0)
                """)
                Text(.init(MathTypesetter.richify("原版指南按论文中的 *α ⁄ r* 描述 *scaling factor*。本机 mlx-lm 0.32.2 的 LoRA 层实际直接使用 `scale` 作为更新乘数，并不在层内再除以 `rank`。这里保留论文公式用于说明，界面参数沿用本机实现，不进行 α/r 换算。")))
                    .fixedSize(horizontal: false, vertical: true)

                Text("**DoRA** (Liu et al., 2024)")
                    .font(.body.bold())
                MathBlock(source: """
                    *W*′        =  *W*<sub>0</sub>  +  ( α ⁄ *r* )  ·  *B* · *A*
                    **V**        =  *W*′                                       (frozen after each step)
                    *m*         =  ‖*W*<sub>0</sub>‖<sub>c</sub>               (per-column magnitude, learnable)
                    *W*<sub>dora</sub>  =  *m*  ·  **V**  ⁄  ‖**V**‖
                    *y*         =  *W*<sub>dora</sub> · *x*
                """)
                Text(.init(MathTypesetter.richify("对 **V** 进行 unit-norm rescaling，是 DoRA 区别于“LoRA 加上 magnitude multiplier”的关键。")))
                    .fixedSize(horizontal: false, vertical: true)

                Text("**Full fine-tuning**")
                    .font(.body.bold())
                MathBlock(source: "*y*  =  *W*  ·  *x*")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("设置会改变什么")
                    .font(.title3.bold())
                SettingsTable(rows: [
                    .init(setting: "train_type", defaultValue: "lora",
                          explanation: "可选 `lora`（默认）、`dora` 或 `full`。切换到 `full` 会完全移除 adapter wrapper；该配置下 `num_layers` 不生效。"),
                    .init(setting: "lora_parameters.rank", defaultValue: "8",
                          explanation: "Low-rank update 的内部 rank。4 较小、8 常用、16 容量较高，32+ 在笔记本上通常偏大。提高 rank 会按相同比例增加 memory 和 adapter 文件大小。"),
                    .init(setting: "lora_parameters.scale", defaultValue: "20.0",
                          explanation: "原版指南将此项与论文中的 α 对应，并以 `(rank=8, scale=20.0)` 说明 2.5x 的 α/r 比值。实际本机 MLX LoRA 层直接以 `scale` 乘以更新量；请保持参数原值，不按 `rank` 再除一次。许多论文采用 1x 的公式约定，与此参数的定义需分开理解。"),
                    .init(setting: "lora_parameters.dropout", defaultValue: "0.0",
                          explanation: "在 `ΔW · x` 加入 `W_0 · x` 之前应用 Dropout。通常仅在小 dataset 训练或 loss curve 显示 overfitting 时，才有必要设为大于 0。"),
                    .init(setting: "num_layers", defaultValue: "16",
                          explanation: "为顶部多少个 transformer layers 添加 LoRA/DoRA adapters。Trainer 从顶部计数，因此 32-layer model 的 `num_layers = 8` 对应 layers 24–31。"),
                    .init(setting: "resume_adapter_file", defaultValue: "—",
                          explanation: "此前保存的 `adapters.safetensors` 路径。适用于不同 `train_type`，但文件必须与新运行的 layer names 匹配。"),
                    .init(setting: "fuse", defaultValue: "true",
                          explanation: "为 true 时，训练后将 LoRA/DoRA updates 合并回 `W_0`，并把 merged model 保存到 `adapter_path`。关闭时将 adapter 文件分开保留。"),
                ])
            }

            ArticleSection("如何选择", """
                • **LoRA** 是本应用常用的默认选择。约 4M 可训练 parameters，可放入 CPU RAM，便于快速迭代。\n• 当 LoRA 在风格或格式相关 metric 上进入平台期时，可尝试 **DoRA**。研究报告其 instruction-following 效果更接近 full fine-tuning，memory 与耗时通常相近，adapter 文件会略大。\n• **Full** 适用于 LoRA / DoRA 表达能力不足的情况，例如在领域语料上从头训练小 model。原指南估计，在 16 GB Apple Silicon 机器上，fp16 的实际规模上限约为 1B parameters。
                """)

            ArticleTips(tips: [
                "可从 `rank=8, scale=20.0, dropout=0.0` 开始。Loss 进入平台期时，可先将 `rank` 提高到 16，再调整 learning rate；瓶颈可能是容量而非 step size。",
                "DoRA 的 magnitude vector 按 output-column 保存，因此 output dim 较大的 layer，在相同 rank 下会比 LoRA 存储更多 parameters。差异较小，通常每层几百个 floats，但会反映在 adapter 文件大小上。",
                "两次运行之间改变 `train_type` 时，应先处理旧的 `adapters.safetensors`。不同类型的 layer name 约定不同，旧文件可能无法正确加载。",
                "进行 `full` fine-tuning 时，建议一开始就设置 `grad_checkpoint = true`；对于笔记本上的 7B model，仅 activation memory 就可能导致 OOM。",
            ])
        }
    }
}

// MARK: Optimizer Article

/// Covers the three optimizers the runner exposes through
/// `optim.Adam`, `optim.AdamW` and `optim.Muon`. The runner picks the
/// class from `args.optimizer` and forwards the matching
/// `optimizer_config[args.optimizer]` dict to its constructor.
private struct OptimizerArticle: View {
    @Binding var config: TrainingConfig

    var body: some View {
        FoundationArticle(
            title: "Optimizers",
            subtitle: "Gradients 如何转换为 weight updates",
            symbol: "function"
        ) {
            ArticleSection("概述", """
                本节介绍 mlx-lm-lora 的三种 optimizers：**Adam**、**AdamW** 和 **Muon**。前两者较常用；Muon（Jordan et al., 2024）相对较新，已有 transformer hidden weights 更快收敛的实验结果。选择由 `config.optimizer` 提供，trainer 在构建时从 `mlx.optimizers` 选取对应 class。
                """)

            ArticleSection("直观理解", """
                • **Adam** 为每个 parameter 维护 gradient 的 first moment `m` 和 second moment `v` 的 exponential moving average，并执行 bias-corrected update。默认 `betas = (0.9, 0.999)` 适用于较广范围的 LR。\n• **AdamW** 在 Adam 基础上使用 **decoupled weight decay**，将 regularisation `λ · W` 直接加入 update，而非放入 gradient 内部。这将 adaptive optimizers 的 weight decay 与 gradient 更新分开，是 transformer fine-tuning 的常见选择。\n• 原指南以“用 momentum 的 Newton-Schulz orthogonalisation 替换 second moment”概括 **Muon**。具体而言，每个 tensor 的 update 会先投影为近似 orthogonal matrix，再进行 scaling。在 hidden 2D weights（transformer blocks 内的 QKV 和 MLP projections）上已有较快收敛的经验结果，但 1D weights（biases、norms）更适合配合 AdamW 等方法，因此常见实现会组合使用。\n• 三者在 mlx-lm-lora 中均以 `opt = OptClass(learning_rate=lr, **optimizer_config[opt_name])` 调用，因此各 optimizer 的 hyperparameters，例如 `betas`、`eps`、`weight_decay`、`momentum`，会从 spec 的 `optimizer_config` dict 原样传入。
                """)

            VStack(alignment: .leading, spacing: 10) {
                Text("Objective（数学形式）")
                    .font(.title3.bold())
                Text(.init(MathTypesetter.richify("令 *g*<sub>t</sub> = ∇**ℒ**(θ<sub>t−1</sub>) 为 step *t* 的 gradient，*lr* 为 learning rate。三种 optimizers 在 `optimizer.state` 中维护各自 state；trainer 使用 `mx.random.state` 初始化相关 state，以支持确定性执行。")))
                    .fixedSize(horizontal: false, vertical: true)

                Text("**Adam** (Kingma & Ba, 2014)")
                    .font(.body.bold())
                MathBlock(source: """
                    *m*<sub>t</sub>   =  β₁ · *m*<sub>t−1</sub>  +  ( 1 − β₁ ) · *g*<sub>t</sub>               (first moment)
                    *v*<sub>t</sub>   =  β₂ · *v*<sub>t−1</sub>  +  ( 1 − β₂ ) · *g*<sub>t</sub>²              (second moment)
                    *m̂*<sub>t</sub>  =  *m*<sub>t</sub> ⁄ ( 1 − β₁<super>t</super> )                          (bias correction)
                    *v̂*<sub>t</sub>  =  *v*<sub>t</sub> ⁄ ( 1 − β₂<super>t</super> )                          (bias correction)
                    θ<sub>t</sub>    =  θ<sub>t−1</sub>  −  *lr*  ·  *m̂*<sub>t</sub> ⁄ ( √*v̂*<sub>t</sub> + ε )
                """)
                Text(.init(MathTypesetter.richify("`mlx.optimizers` 的默认值：β₁ = 0.9、β₂ = 0.999、ε = 1×10⁻⁸。不应用 L2 regularisation；需要 weight decay 时可使用 AdamW。")))
                    .fixedSize(horizontal: false, vertical: true)

                Text("**AdamW** (Loshchilov & Hutter, 2019)")
                    .font(.body.bold())
                MathBlock(source: """
                    ( *m*<sub>t</sub>,  *v*<sub>t</sub>,  *m̂*<sub>t</sub>,  *v̂*<sub>t</sub> )  ←  Adam update as above
                    θ<sub>t</sub>    =  θ<sub>t−1</sub>  −  *lr*  ·  (  *m̂*<sub>t</sub> ⁄ ( √*v̂*<sub>t</sub> + ε )  +  λ · θ<sub>t−1</sub>  )
                """)
                Text(.init(MathTypesetter.richify("*λ · θ* 项是 decoupled weight decay。默认 `weight_decay = 0.01`，调整它可控制将 model 拉向零的强度，也影响对较小 LoRA / DoRA adapters 的偏好。")))
                    .fixedSize(horizontal: false, vertical: true)

                Text("**Muon** (Jordan et al., 2024)")
                    .font(.body.bold())
                MathBlock(source: """
                    *m*<sub>t</sub>   =  μ · *m*<sub>t−1</sub>  +  *g*<sub>t</sub>                       (momentum buffer, μ ≈ 0.95)
                    **O**<sub>t</sub>   =  NewtonSchulz5( *m*<sub>t</sub> )                                (≈ orthogonalise the momentum)
                    scale    =  √( out · in )                                                              (spectral-norm-preserving scale)
                    θ<sub>t</sub>    =  θ<sub>t−1</sub>  −  *lr*  ·  scale  ·  **O**<sub>t</sub>
                """)
                Text(.init(MathTypesetter.richify("Newton–Schulz iteration 是一个较小的 fixed-point loop，原说明采用 5 steps，将 matrix 映射为近似 semi-orthogonal matrix。它使用 matrix multiplications；具体耗时取决于实现与 tensor 大小。")))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("设置会改变什么")
                    .font(.title3.bold())
                SettingsTable(rows: [
                    .init(setting: "optimizer", defaultValue: "adamw",
                          explanation: "可选 `adam`、`adamw` 或 `muon`。从 `mlx.optimizers` 加载对应 class，以 `learning_rate=lr` 和匹配的 `optimizer_config` dict 构建。"),
                    .init(setting: "learning_rate", defaultValue: "1e-5",
                          explanation: "Peak learning rate。LoRA/DoRA 可参考：AdamW 为 1e-5 至 5e-5，Muon 为 5e-4 至 5e-3。Muon 的参数定义不同，通常采用更大的 LR；full fine-tuning 搭配 AdamW 时通常使用 1e-6 至 5e-6。"),
                    .init(setting: "lr_schedule", defaultValue: "—",
                          explanation: "可选的 schedule 来自 `mlx_lm.tuner.utils.build_schedule`。非空时 runner 用 schedule 包装 `learning_rate`，否则按固定 `learning_rate` 使用。"),
                    .init(setting: "optimizer_config.adam", defaultValue: "{}",
                          explanation: "传给 `optim.Adam(...)` 的额外 kwargs。支持 `betas`、`eps`，默认采用 `mlx.optimizers.Adam` 的默认值。"),
                    .init(setting: "optimizer_config.adamw", defaultValue: "{}",
                          explanation: "传给 `optim.AdamW(...)` 的额外 kwargs。支持 `betas`、`eps`、`weight_decay`。默认 `weight_decay=0.01`；若训练中 LoRA magnitudes 持续增大，可考虑提高到 0.05。"),
                    .init(setting: "optimizer_config.muon", defaultValue: "{}",
                          explanation: "传给 `optim.Muon(...)` 的额外 kwargs。支持 `momentum`、`nesterov`、`weight_decay`，默认采用 Muon 默认值：momentum=0.95、nesterov=True。"),
                ])
            }

            ArticleSection("如何选择", """
                • **AdamW** 是本应用较稳妥的默认选择，没有明确原因时可优先采用。\n• 希望显式关闭 regularisation 时，可选择不含 weight decay 的 **Adam**，例如 base model 已有 regularisation，且不希望进一步惩罚 LoRA adapters。\n• 原指南报告 **Muon** 在部分 1B+ model 的 LoRA/DoRA hidden weights 上可用更少 iterations 达到相近 loss，但并非所有负载的保证。可搭配较高 learning rate（5e-3 至 1e-2）；若不需要 regularise LoRA magnitudes，可保持 `weight_decay=0.0`。
                """)

            ArticleTips(tips: [
                "从 AdamW 切换到 Muon 时，原指南建议将 learning rate 提高约 100x。Muon update 的参数定义不同，直接沿用 AdamW 的 1e-5 可能训练不足。",
                "切换 optimizer 后，观察前 50 steps 的实时 loss curve。突然发散通常提示 LR 不合适，应结合运行结果检查。",
                "在 `full` fine-tuning 中为 AdamW 设置 `weight_decay` 后，regulariser 将 weights 拉向零，前 100 steps 可能出现小幅 loss 上升，通常在一个 epoch 内恢复。",
                "`lr_schedule` 是上游 mlx-examples 的小型 DSL。常见写法包括 `cosine:<iters>:<min_lr>`，以及先 warm-up 后 decay 的 `warmup_cosine:<warmup>:<iters>:<min_lr>`。",
            ])
        }
    }
}

// MARK: Quantization & QAT Article

/// Covers the four load-time quantisation modes (`load_in_4bits`,
/// `load_in_6bits`, `load_in_8bits`, `load_in_mxfp4`) and the
/// in-training Quantization-Aware Training (QAT) hook installed by
/// `_install_qat_hooks` in the SFT trainer. Backed by
/// `mlx.nn.quantize` (load time) and the straight-through-estimator
/// fake-quantise hook (train time).
private struct QuantizationArticle: View {
    @Binding var config: TrainingConfig

    var body: some View {
        FoundationArticle(
            title: "Quantization & QAT",
            subtitle: "以低 precision 加载 base model，并针对 quantised weights 训练",
            symbol: "cpu"
        ) {
            ArticleSection("概述", """
                mlx-lm-lora 支持容易混淆的**两类 quantisation**：\n\n1. **Load-time quantisation**：从磁盘读取 base model 时，`mlx.nn.quantize` 将 `nn.Linear` 替换为保存 quantised weights 和 per-group scale 的 `QuantizedLinear`。Base model 在后续运行中保持这种 memory 表示，LoRA / DoRA adapters 在其上以 full precision 训练。\n2. **Quantization-Aware Training (QAT)**：在首次 optimiser step 后，为相关 `nn.Linear` 安装 hook，在进入 forward pass 时对 weight 进行 fake quantisation（straight-through estimator），以模拟 inference quantisation。Optimiser 仍使用 full-precision weights 进行更新。\n\n两者分别通过 `quantization` 和 `qat_*` 设置暴露，也可以组合。例如“QLoRA + QAT”先以 4-bit 加载 base model，再启用 QAT hook，使 LoRA updates 更适应部署 precision。
                """)

            ArticleSection("直观理解", """
                • **Load-time quantisation** 用于 QLoRA 类 pipeline。原指南以分组对称整数 quantisation 公式作示意：将 `W ∈ R^{out×in}` 按最后一轴分为 `group_size` 个连续 columns 的 groups，采用 scale `s_g = max(|W_g|) / qmax`，得到 `Q_g = round(W_g / s_g)`，再以 `Q_g · s_g ≈ W_g` 表示 dequantised weight。具体格式仍由 MLX quantisation mode 决定。\n• **QAT** 让 model 在训练时模拟较低 precision 的部署，而非只在 fp16 训练后直接转为 4-bit。Hook 作用于相关 `nn.Linear` 的 forward；完成后恢复 full-precision weights，供 optimiser 更新。\n• **Straight-through estimator** 使 forward 使用 quantised weight，而 backward 采用 identity 近似，让 gradients 继续传播。若直接对 quantise-then-round 求导，gradient 在大部分位置会为零。\n• mlx-lm-lora 的 QAT hook 由 `qat_start_step` 延迟启用，并按 `qat_interval` steps 重新应用，避免一开始便对接近初始化状态的 LoRA 更新进行投影。
                """)

            VStack(alignment: .leading, spacing: 10) {
                Text("Objective（数学形式）")
                    .font(.title3.bold())

                Text("**Affine quantisation** (load-time, all four modes)")
                    .font(.body.bold())
                MathBlock(source: """
                    # Per group of *group_size* consecutive columns of *W*:
                    *s*<sub>g</sub>     =  max(| *W*<sub>g</sub> |) ⁄ *q*<sub>max</sub>                 (positive scale)
                    *Q*<sub>g</sub>     =  clip( round( *W*<sub>g</sub> ⁄ *s*<sub>g</sub> ),  *q*<sub>min</sub>,  *q*<sub>max</sub> )    (N-bit signed int)
                    *Ŵ*<sub>g</sub>     =  *Q*<sub>g</sub>  ·  *s*<sub>g</sub>                          (dequantised)
                """)
                Text(.init(MathTypesetter.richify("示意公式中 *q*<sub>max</sub> = 2<sup>N − 1</sup> − 1，*q*<sub>min</sub> = −*q*<sub>max</sub> − 1。N = 4 时，*q*<sub>max</sub> = 7、*q*<sub>min</sub> = −8。MXFP4 使用 group size 32 和 8-bit E8M0 scale，是 *microscaling* 格式；具体数值编码不能简单等同于该整数示意公式。")))
                    .fixedSize(horizontal: false, vertical: true)

                Text("**Symmetric fake quantise** (QAT, applied inside the forward)")
                    .font(.body.bold())
                MathBlock(source: """
                    # Same arithmetic, but the quantise+dequantise pair happens
                    # at runtime on the current weight tensor:
                    *Ŵ*   =  *s*  ·  clip( round( *W* ⁄ *s* ),  *q*<sub>min</sub>,  *q*<sub>max</sub> )

                    # The forward uses *Ŵ*; the backward uses an STE:
                    ∂**ℒ** ⁄ ∂*W*   =  ∂**ℒ** ⁄ ∂*Ŵ*                                  (identity — gradient flows through)
                """)
                Text("Hook 的示意实现如下")
                    .font(.body.bold())
                MathBlock(source: """
                    self.weight  =  *w*  +  stop_gradient( quantize(*w*)  −  *w* )        # forward sees *Ŵ*
                    out          =  original_forward(self, *x*)
                    self.weight  =  *w*                                                  # restore for optimiser
                """)
                Text(.init(MathTypesetter.richify("注意 `( quantize(*w*) − *w* )` 外的 `stop_gradient`，它实现 STE。外部的 `+ *w*` 使 forward 值为 *Ŵ*，backward 的对应导数为 1，而 optimiser 只更新 full-precision *w*。")))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("设置会改变什么")
                    .font(.title3.bold())
                SettingsTable(rows: [
                    .init(setting: "load_in_4bits", defaultValue: "false",
                          explanation: "加载时将 base model quantise 为 4-bit，group size 128。这是较激进的选项，常与 LoRA/DoRA 搭配。相对于 8-bit，它降低 weights memory，使相同机器上可留出更多 adapter 容量。"),
                    .init(setting: "load_in_6bits", defaultValue: "false",
                          explanation: "6-bit quantisation，group size 128。通常优先比较更小的 4-bit 或质量更稳妥的 8-bit，再决定是否使用。"),
                    .init(setting: "load_in_8bits", defaultValue: "false",
                          explanation: "8-bit quantisation，group size 128。适合 preference training，以及需要在长 context 中保留较精确数值的运行。"),
                    .init(setting: "load_in_mxfp4", defaultValue: "false",
                          explanation: "MXFP4（microscaling 4-bit），group size 32。近期 NVIDIA/Microscaling 硬件使用此格式；在 Apple Silicon 上同样提供低 precision 表示，但分组和 E8M0 scale 编码与常规 4-bit 不同。"),
                    .init(setting: "qat_enable", defaultValue: "false",
                          explanation: "在首次 optimiser step 后，为相关 `nn.Linear` 安装 STE fake-quantise hook。仅对调用 `_install_qat_hooks` 的 SFT/DPO/ORPO trainers 生效。"),
                    .init(setting: "qat_bits", defaultValue: "8",
                          explanation: "QAT hook 的 Bit-width。应与计划的 inference quantisation 匹配：部署为 4-bit 时可用 `qat_bits=4`，部署为 8-bit 时可用 `qat_bits=8`。"),
                    .init(setting: "qat_group_size", defaultValue: "64",
                          explanation: "QAT hook 的 Group size。0 或负值表示 per-tensor。尽量匹配部署 group size；64 或 128 较常见。"),
                    .init(setting: "qat_start_step", defaultValue: "1",
                          explanation: "安装 hook 的首个 optimiser step。若最初几个 steps 出现 NaN gradients，可考虑提高该值，因为接近初始化状态的 weights 可能难以适应投影。"),
                    .init(setting: "qat_interval", defaultValue: "1",
                          explanation: "每 N 个 optimiser steps 重新应用 QAT projection。默认 `1` 表示每个 step 都应用；若性能分析显示 projection 开销明显，可考虑提高至 `4` 等值。"),
                ])
            }

            ArticleSection("如何选择", """
                • **Default（不启用 quantisation 或 QAT）**：适合拥有 ≥32 GB unified memory 的机器上较小的 models（≤1B），也较便于调试。\n• **4-bit load + LoRA + QAT (8-bit)**：原指南列出的低 memory 方案，面向在有限 memory 下训练 7B–13B models；能否容纳仍取决于配置。QAT hook 用于改善 adapter 对合并和部署 quantisation 的适应性。\n• **8-bit load + LoRA + QAT (8-bit)**：比 4-bit 方案使用更多 memory，但 quantisation 较温和，loss curve 可能更稳定。\n• **MXFP4**：适合部署目标采用 MXFP4，或明确希望在训练时使用 microscaling 4-bit 的情况。实际 throughput 应在本机测量。\n• **No load quantisation + QAT (4-bit)**：适合希望 base model 保持 fp16，同时让 adapter 适应 4-bit 部署的情况；效果需要针对实际 model 验证。
                """)

            ArticleTips(tips: [
                "原指南主要从 LoRA/DoRA adapter 的训练角度介绍 QAT。`train_type=full` 的作用范围应以当前后端 hook 与导出实现为准，不能将 adapter 场景的结论直接推广到 full fine-tuning。",
                "运行几百 steps 后，若 loss 开始振荡或出现 NaN，可检查 QAT 的 `qat_bits` 与当前 learning rate 是否过于激进，并尝试 8-bit 设置。",
                "Group size 32（MXFP4 默认值）对 outliers 更敏感，128 通常更宽松。存在疑问时，可先增加 group size，再考虑降低 bit-width。",
                "Load-time quantisation 会改变已加载的 model object；修改 base precision 需要重新加载 model。更改 `load_in_*` flags 后应重新启动 runner。",
            ])
        }
    }
}
