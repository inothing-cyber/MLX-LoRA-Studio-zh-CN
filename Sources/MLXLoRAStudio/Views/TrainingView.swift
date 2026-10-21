import SwiftUI
import UniformTypeIdentifiers

struct TrainingView: View {
    @Bindable var store: AppStore
    // When the window gets narrow, the user can collapse the Run Console
    // to a thin strip and bring it back later with a single click. We
    // also auto-collapse it if the available width drops below a
    // comfortable threshold (see the GeometryReader below).
    @State private var consoleCollapsed: Bool = false
    @State private var manualConsoleCollapsed: Bool? = nil

    var body: some View {
        GeometryReader { proxy in
            let shouldAutoCollapse = proxy.size.width < 900
            let isCollapsed = effectiveCollapsed(shouldAutoCollapse: shouldAutoCollapse)
            StudioTrainingPanes(available: proxy.size, collapsed: isCollapsed) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HeaderView(
                            title: "训练",
                            subtitle: "\(store.training.trainMode.title) 使用 \(store.training.trainType.title)",
                            symbol: "cpu"
                        )

                        ModeStrip(config: $store.training)
                        ModelDataSection(config: $store.training)
                            .environment(store)
                        OutputSection(config: $store.training, outputRoot: store.outputRoot, lastRunFolder: store.trainingRunner.lastRunFolder)
                        CoreTrainingSection(config: $store.training)
                        FTPOSection(config: $store.training)
                        PreferenceSection(config: $store.training)
                        GRPOSection(config: $store.training)
                        OnlinePreferenceSection(config: $store.training)
                        QATSection(config: $store.training)
                        DatasetMappingSection(config: $store.training)
                    }
                    .padding(24)
                }
                .trainSettingsPane(cornerRadius: 18)
                .padding(16)
            } console: {
                LiveRunPanel(
                    runner: store.trainingRunner,
                    collapsed: Binding(
                        get: { isCollapsed },
                        set: { manualConsoleCollapsed = $0 }
                    )
                )
            }
        }
        .navigationTitle("训练")
    }

    /// Resolves the final collapse state, taking both the manual
    /// user toggle and the auto-collapse rule into account. A manual
    /// override always wins; if the user hasn't touched it, the
    /// console hides itself below 900pt so the form stays readable.
    private func effectiveCollapsed(shouldAutoCollapse: Bool) -> Bool {
        if let manual = manualConsoleCollapsed { return manual }
        return shouldAutoCollapse
    }
}

private struct ModeStrip: View {
    @Binding var config: TrainingConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("算法（Algorithm）")
            Text("模型类型（Model family）")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Picker("模型类型（Model family）", selection: $config.modelFamily) {
                ForEach(ModelFamily.allCases) { family in
                    Text(family.title).tag(family)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if config.modelFamily == .visionLanguage {
                Text("VLM 模式只微调语言模型，再把训练后的文本权重合并回原始 VLM，导出完整的视觉语言模型（vision-language model）。")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label {
                    Text("支持 Transformer、线性模型（linear）和混合循环模型（hybrid recurrent）。会自动识别 Qwen3.5/Next、Kimi Linear、Mamba、Jamba、Falcon H1 等 SSM 架构，并使用节省内存的分块检查点机制（checkpointed blocks）训练。")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "memorychip")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            // The 8-mode segmented picker (SFT/DPO/CPO/ORPO/GRPO/Online
            // DPO/XPO/RLHF Reinforce/PPO). We use the original
            // segmented style — the wide rows make it easy to scan all
            // available algorithms at a glance, and a dropdown menu
            // hides the choice set behind a click. The user explicitly
            // asked to keep the segmented control, so the picker now
            // wraps in a `ScrollView(.horizontal)` on narrow windows
            // instead of falling back to a menu — at worst the row
            // scrolls; the indicator and hint keep the extra choices discoverable.
            ScrollView(.horizontal, showsIndicators: true) {
                Picker("训练模式（Mode）", selection: $config.trainMode) {
                    ForEach(TrainMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .onChange(of: config.trainMode) { _, mode in
                config.applyDefaultDataset(for: mode)
            }
            Label("可横向滚动查看全部训练模式", systemImage: "arrow.left.and.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 12) {
                InfoPill(text: config.trainMode.family, symbol: "tag")
                InfoPill(text: config.trainMode.datasetHint, symbol: "tray")
            }

            Text(config.trainMode.summary)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // The Fine-tune picker sits right under the algorithm
            // list so the user can see all three training shapes
            // (LoRA, DoRA, full) at once and pick one. Same
            // horizontal-scrolling segmented style as the algorithm
            // picker, for the same reasons.
            SectionTitle("微调方式（Fine-tune）")
            ScrollView(.horizontal, showsIndicators: false) {
                Picker("微调方式（Fine-tune）", selection: $config.trainType) {
                    ForEach(TrainType.allCases) { type in
                        Text(StudioL10n.display(type.title)).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // LoRA / DoRA configuration. The "adapter" controls
            // (rank, scale, dropout) and the layer count are only
            // meaningful for parameter-efficient methods — full
            // fine-tuning trains every weight, so the same knobs
            // would be dead UI. We render them only when the user
            // picks LoRA or DoRA, and they animate in/out as the
            // fine-tune selection changes so the card's height
            // stays honest.
            if config.trainType == .lora || config.trainType == .dora {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle("LoRA 设置")
                    HStack {
                        NumberField("训练层数（Layers）", value: $config.numLayers)
                        NumberField("秩（Rank）", value: $config.rank)
                    }
                    HStack {
                        FloatingField("缩放系数（Scale）", value: $config.scale)
                        FloatingField("丢弃率（Dropout）", value: $config.dropout)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Quantization is always visible but as a dropdown
            // menu — it has 5 cases and the user only ever changes
            // it once per run, so the segmented-list treatment that
            // fits algorithms + fine-tune doesn't add value here.
            Picker("量化（Quantization）", selection: $config.quantization) {
                ForEach(Quantization.allCases) { quant in
                    Text(quant.title).tag(quant)
                }
            }
        }
        .formBlock()
        .animation(.easeInOut(duration: 0.2), value: config.trainType)
        .animation(.easeInOut(duration: 0.2), value: config.trainMode)
        .animation(.easeInOut(duration: 0.2), value: config.modelFamily)
        .animation(.easeInOut(duration: 0.2), value: config.test)
    }
}

private struct ModelDataSection: View {
    @Binding var config: TrainingConfig
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("模型与数据")
            HFAssetPicker(
                text: $config.model,
                kind: .model,
                placeholder: config.modelFamily == .visionLanguage ? "可训练的文本模型或 HF 仓库" : "模型名称或 Hugging Face 仓库",
                footer: cacheFooter
            )
            if config.modelFamily == .visionLanguage {
                HFAssetPicker(
                    text: $config.vlmModel,
                    kind: .model,
                    placeholder: "原始 VLM 仓库或本地目录",
                    footer: "保留此模型的视觉编码器（vision tower）、处理器（processor）和 VLM 配置。"
                )
                Text("请选择与 VLM 中语言模型相匹配的文本模型。训练完成后，Studio 会导出完整的 MLX-VLM 模型。")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HFAssetPicker(
                text: $config.data,
                kind: .dataset,
                placeholder: "数据集路径或本地数据目录",
                footer: nil
            )
            TextField("LM Studio 导出名称", text: $config.lmStudioName)
            // Fine-tune (LoRA / DoRA / full) and Quantization moved
            // into the Algorithm card directly under the algorithm
            // picker, so they sit next to the controls they modify.
        }
        .formBlock()
        .animation(.easeInOut(duration: 0.2), value: config.trainMode)
        .animation(.easeInOut(duration: 0.2), value: config.modelFamily)
    }

    /// Footer line that summarises what the dropdown is showing, so the
    /// user knows whether the cache has been scanned yet.
    @MainActor private var cacheFooter: String? {
        if store.isScanningHFCache { return "正在扫描本地 HF 缓存…" }
        let n = store.cachedModels.count
        let d = store.cachedDatasets.count
        let s = store.syntheticRunOutputs.count
        return "本地 HF 缓存：\(n) 个模型 · \(d) 个数据集 · 合成数据运行记录：\(s)"
    }
}

private struct OutputSection: View {
    @Binding var config: TrainingConfig
    let outputRoot: String
    let lastRunFolder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("输出")
            TextField("运行目录名称", text: $config.runFolderName)
            HStack(alignment: .top, spacing: 12) {
                InfoPill(
                    text: runFolderDisplayName,
                    symbol: "folder",
                    openPath: lastRunFolder.isEmpty ? plannedRunFolderPath : lastRunFolder
                )
                InfoPill(text: "根目录：\(outputRoot)", symbol: "externaldrive", openPath: outputRoot)
            }
            Text("权重保存在本次运行目录的 adapters 子目录中。可在设置里指定上一级输出目录。")
                .foregroundStyle(.secondary)
                .font(.callout)
            if config.modelFamily == .visionLanguage {
                TextField("完整 VLM 导出目录（可选）", text: $config.vlmOutputPath)
                ToggleRow("导出 VLM 时对文本权重反量化（Dequantize）", isOn: $config.vlmDequantize)
                Text("导出目录留空时，合并后的 VLM 会保存在运行目录的 full-vlm 子目录中。")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            if !lastRunFolder.isEmpty {
                Text(lastRunFolder)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formBlock()
        .animation(.easeInOut(duration: 0.2), value: config.qatEnable)
        .animation(.easeInOut(duration: 0.2), value: config.modelFamily)
    }

    private var runFolderDisplayName: String {
        config.runFolderName.isEmpty ? config.automaticRunFolderName() : config.resolvedRunFolderName()
    }

    private var plannedRunFolderPath: String {
        let expandedRoot = NSString(string: outputRoot).expandingTildeInPath
        return URL(fileURLWithPath: expandedRoot, isDirectory: true)
            .appending(path: runFolderDisplayName, directoryHint: .isDirectory)
            .path
    }
}

private struct CoreTrainingSection: View {
    @Binding var config: TrainingConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("训练参数")
            HStack {
                NumberField("迭代次数（Iterations）", value: $config.iters)
                NumberField("数据轮次（Epochs）", value: $config.epochs)
                NumberField("批大小（Batch）", value: $config.batchSize)
            }
            Text(config.epochs > 0
                 ? "当前按数据轮次（Epochs）训练（\(config.epochs) 轮）；迭代次数（Iterations）在本次运行中不生效。"
                 : "当前按迭代次数（Iterations）训练（\(config.iters) 次）；数据轮次（Epochs）大于 0 时优先生效。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                NumberField("最大序列长度（Max Seq）", value: $config.maxSeqLength)
                NumberField("随机种子（Seed）", value: $config.seed)
            }
            HStack {
                FloatingField("学习率（Learning Rate）", value: $config.learningRate)
                Picker("优化器（Optimizer）", selection: $config.optimizer) {
                    ForEach(OptimizerKind.allCases) { Text($0.title).tag($0) }
                }
            }
            Picker("学习率计划（LR Schedule）", selection: $config.learningRateSchedule) {
                ForEach(LearningRateScheduleKind.allCases) { Text($0.title).tag($0) }
            }
            if config.learningRateSchedule == .cosineDecay {
                HStack {
                    NumberField("预热步数（Warmup）", value: $config.lrWarmupSteps)
                    FloatingField("预热初值（Warmup Init）", value: $config.lrWarmupInit)
                    FloatingField("衰减比例（Decay Fraction）", value: $config.lrDecayFraction)
                    FloatingField("最终学习率（Final LR）", value: $config.lrFinal)
                }
                Text("余弦衰减（Cosine decay）以上方学习率为峰值，再在所选的总 iterations 占比内逐渐衰减。")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                NumberField("报告间隔（Report）", value: $config.stepsPerReport)
                NumberField("评估间隔（Eval）", value: $config.stepsPerEval)
                NumberField("保存间隔（Save）", value: $config.saveEvery)
                NumberField("验证批数（Val Batches）", value: $config.valBatches)
            }
            ToggleRow("梯度检查点（Gradient checkpointing）", isOn: $config.gradCheckpoint)
            if config.gradCheckpoint {
                NumberField("梯度累积步数（Gradient accumulation steps）", value: $config.gradientAccumulationSteps)
            }
            ToggleRow("高效长上下文（Efficient long context）", isOn: $config.efficientLongContext)
            if config.efficientLongContext {
                NumberField("序列分块长度（Sequence step size）", value: $config.seqStepSize)
            }
            ToggleRow("屏蔽提示部分的 loss（Mask prompt loss）", isOn: $config.maskPrompt)
            if config.trainMode == .sft {
                Picker("SFT 损失函数（SFT loss）", selection: $config.sftLossType) {
                    ForEach(SFTLossType.allCases) { loss in Text(loss.title).tag(loss) }
                }
                Text(config.sftLossType == .dft
                     ? "Dynamic fine-tuning 降低模型已经很有把握的 tokens 的权重，使学习更关注困难的 tokens。"
                     : config.sftLossType == .chunkedNLL
                     ? "Chunked NLL 将词表的 loss 分块计算，以限制峰值内存。"
                     : "标准的下一 token 负对数似然（next-token negative log-likelihood）。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ToggleRow(config.modelFamily == .visionLanguage ? "训练后导出完整 VLM" : "训练后合并模型权重（Fuse）", isOn: $config.fuse)
            if config.fuse, config.modelFamily == .text {
                ToggleRow("对合并模型反量化（Dequantize）", isOn: $config.fuseDequantize)
                ToggleRow("合并后移除 adapters", isOn: $config.fuseRemoveAdapters)
            }
            ToggleRow("评估测试数据（test split）", isOn: $config.test)
            if config.test {
                NumberField("测试批数（Test Batches）", value: $config.testBatches)
            }
        }
        .formBlock()
        .animation(.easeInOut(duration: 0.2), value: config.gradCheckpoint)
        .animation(.easeInOut(duration: 0.2), value: config.efficientLongContext)
        .animation(.easeInOut(duration: 0.2), value: config.learningRateSchedule)
        .animation(.easeInOut(duration: 0.2), value: config.fuse)
        .animation(.easeInOut(duration: 0.2), value: config.modelFamily)
    }
}

private struct FTPOSection: View {
    @Binding var config: TrainingConfig

    var body: some View {
        if config.trainMode == .ftpo {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("FTPO / Antidoom")
                Text("使用包含 context_with_chat_template、rejected_decoded 和 multi_chosen_decoded 字段的 Hugging Face 数据集或本地 JSONL 数据。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack {
                    FloatingField("目标 MSE 系数（Target MSE λ）", value: $config.lambdaMSETarget)
                    FloatingField("目标 MSE 阈值（Target MSE τ）", value: $config.tauMSETarget)
                }
                HStack {
                    FloatingField("非目标 MSE 系数（Non-target MSE λ）", value: $config.lambdaMSE)
                    FloatingField("Logit 裁剪阈值（Logit clip ε）", value: $config.clipEpsilonLogits)
                }
                TextField("参考模型路径（Reference model，可选）", text: $config.referenceModelPath)
            }
            .formBlock()
        }
    }
}

private struct PreferenceSection: View {
    @Binding var config: TrainingConfig

    var body: some View {
        // SFT never reads the preference/judge knobs (it has no reward
        // signal and no reference model), and the online-preference
        // modes (online DPO, XPO, PPO, REINFORCE) get their own
        // `OnlinePreferenceSection` with the per-mode temperature /
        // judge-system-prompt / epsilon fields. Hide the whole block
        // for those modes so the trainer view stays free of dead
        // controls; the offline preference algorithms (DPO / CPO /
        // ORPO) and GRPO still use Beta / Delta / Loss below.
        let mode = config.trainMode
        if mode != .sft
            && mode != .ftpo
            && mode != .onlineDPO
            && mode != .xpo
            && mode != .ppo
            && mode != .rlhfReinforce
        {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("偏好与评审（Preference / Judge）")
                HStack {
                    FloatingField("系数（Beta）", value: $config.beta)
                    FloatingField("惩罚系数（Delta）", value: $config.delta)
                    FloatingField("奖励缩放（Reward Scale）", value: $config.rewardScaling)
                }
                Picker("损失函数（Loss）", selection: $config.dpoCpoLossType) {
                    Text("Sigmoid").tag("sigmoid")
                    Text("Hinge").tag("hinge")
                    Text("IPO").tag("ipo")
                    Text("DPOP").tag("dpop")
                }
                if config.trainMode.needsReference {
                    TextField("参考模型路径（Reference model）", text: $config.referenceModelPath)
                }
                if config.trainMode.needsJudge {
                    TextField("评审模型（Judge）或 human", text: $config.judge)
                }
            }
            .formBlock()
        }
    }
}

private struct GRPOSection: View {
    @Binding var config: TrainingConfig
    @State private var showingRewardFileImporter = false

    var body: some View {
        if config.trainMode == .grpo {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("GRPO 生成与奖励")
                HStack {
                    NumberField("组大小（Group）", value: $config.groupSize)
                    NumberField("回答长度（Completion）", value: $config.maxCompletionLength)
                    FloatingField("采样温度（Temp）", value: $config.temperature)
                    FloatingField("裁剪阈值（Epsilon）", value: $config.epsilon)
                }
                HStack {
                    FloatingField("Top P 阈值（Top P）", value: $config.topP)
                    NumberField("Top K 数量（Top K）", value: $config.topK)
                    FloatingField("Min P 阈值（Min P）", value: $config.minP)
                    TextField("裁剪上界（Epsilon high）", text: $config.epsilonHigh)
                }
                HStack {
                    Picker("GRPO 损失函数（GRPO Loss）", selection: $config.grpoLossType) {
                        Text("GRPO").tag("grpo")
                        Text("BNPO").tag("bnpo")
                        Text("DR GRPO").tag("dr_grpo")
                    }
                    Picker("重要性比粒度（Importance）", selection: $config.importanceSamplingLevel) {
                        Text("默认").tag("")
                        Text("Token").tag("token")
                        Text("序列级（Sequence）").tag("sequence")
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionTitle("默认奖励函数（Reward Functions）")
                        Spacer()
                        Button("使用全部默认项") {
                            config.useDefaultGRPORewardFunctions()
                        }
                        .buttonStyle(.borderless)
                        .help("清除自定义选择，让 GRPO 使用后端默认的奖励函数集合。")
                    }
                    ForEach(GRPORewardFunction.defaults) { reward in
                        GRPORewardFunctionRow(
                            reward: reward,
                            isSelected: config.selectedGRPORewardFunctionNames.contains(reward.name)
                        ) {
                            config.toggleDefaultGRPORewardFunction(reward.name)
                        }
                    }
                    Text("自定义列表留空时使用全部默认项。选择条目后，会将对应的函数名传给训练器。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                TextField("自定义奖励函数名（reward function names），以逗号分隔", text: $config.rewardFunctions)
                    .font(.system(.body, design: .monospaced))
                TextField("奖励权重（Reward weights），例如 [2.0, 0.5, 0.5, 0.5, 0.5]", text: $config.rewardWeights)
                    .font(.system(.body, design: .monospaced))
                HStack(alignment: .top, spacing: 10) {
                    TextField("奖励函数的 Python 文件", text: $config.rewardFunctionsFile)
                        .font(.system(.body, design: .monospaced))
                    Button {
                        showingRewardFileImporter = true
                    } label: {
                        Label("导入", systemImage: "doc.badge.plus")
                    }
                }
                Text("自定义 Python 文件应通过 @register_reward_function() 注册函数，再在上方填写对应名称。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .formBlock()
            .fileImporter(
                isPresented: $showingRewardFileImporter,
                allowedContentTypes: [.pythonScript, .plainText],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                config.rewardFunctionsFile = url.path
            }
        }
    }
}

private struct GRPORewardFunctionRow: View {
    let reward: GRPORewardFunction
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(iconStyle)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(reward.title)
                            .font(.callout.weight(.semibold))
                        Text(reward.name)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Text(reward.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 8, interactive: true)
        }
        .buttonStyle(.plain)
    }

    private var iconStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
    }
}

private struct OnlinePreferenceSection: View {
    @Binding var config: TrainingConfig

    var body: some View {
        if config.trainMode == .onlineDPO || config.trainMode == .xpo || config.trainMode == .ppo || config.trainMode == .rlhfReinforce {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("在线偏好（Online Preference）")
                HStack {
                    NumberField("回答长度（Completion）", value: $config.maxCompletionLength)
                    if config.trainMode == .onlineDPO || config.trainMode == .xpo || config.trainMode == .ppo {
                        FloatingField("采样温度（Temp）", value: $config.temperature)
                    }
                    if config.trainMode == .ppo {
                        FloatingField("裁剪阈值（Epsilon）", value: $config.epsilon)
                    }
                }
                Picker("评审方式（Judge）", selection: $config.judgeKind) {
                    ForEach(JudgeKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: config.judgeKind) { _, kind in
                    applyJudgeKind(kind)
                }
                if config.judgeKind == .llm {
                    TextField("评审模型（Judge model）", text: $config.judge)
                }
                HStack(alignment: .top, spacing: 12) {
                    InfoPill(text: "评审模型：\(judgeDisplayName)", symbol: "scales")
                    if config.trainMode == .onlineDPO || config.trainMode == .xpo {
                        InfoPill(text: config.trainMode.title, symbol: "arrow.triangle.2.circlepath")
                    }
                }
                if config.judgeKind == .llm && (config.trainMode == .onlineDPO || config.trainMode == .xpo || config.trainMode == .ppo) {
                    TextField("评审系统提示词（Judge system prompt）", text: $config.judgeSystem, axis: .vertical)
                        .lineLimit(2...5)
                }
                if config.trainMode == .xpo {
                    TextField("Alpha 计划（Alpha schedule）", text: $config.alpha)
                }
            }
            .formBlock()
        }
    }

    private var judgeDisplayName: String {
        let trimmed = config.judge.trimmingCharacters(in: .whitespacesAndNewlines)
        if config.judgeKind == .user { return "用户／人工（User / human）" }
        return trimmed.isEmpty ? "默认" : trimmed
    }

    private func applyJudgeKind(_ kind: JudgeKind) {
        switch kind {
        case .user:
            config.judge = "human"
        case .llm:
            let trimmed = config.judge.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.localizedCaseInsensitiveCompare("human") == .orderedSame {
                config.judge = "Qwen/Qwen3-0.6B"
            }
        }
    }
}

private struct DatasetMappingSection: View {
    @Binding var config: TrainingConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("数据集字段映射")
            if config.trainMode == .ftpo {
                TextField("上下文（Context）", text: $config.ftpoContextFeature)
                    .studioFieldLabel("上下文（Context）")
                HStack {
                    TextField("被拒绝的回答（Rejected）", text: $config.ftpoRejectedFeature)
                        .studioFieldLabel("被拒绝的回答（Rejected）")
                    TextField("多个优选回答（Multiple chosen）", text: $config.ftpoChosenFeature)
                        .studioFieldLabel("多个优选回答（Multiple chosen）")
                }
            }
            HStack {
                TextField("提示（Prompt）", text: $config.promptFeature)
                    .studioFieldLabel("提示（Prompt）")
                TextField("回答（Completion）", text: $config.completionFeature)
                    .studioFieldLabel("回答（Completion）")
            }
            HStack {
                TextField("优选回答（Chosen）", text: $config.chosenFeature)
                    .studioFieldLabel("优选回答（Chosen）")
                TextField("被拒绝的回答（Rejected）", text: $config.rejectedFeature)
                    .studioFieldLabel("被拒绝的回答（Rejected）")
            }
            HStack {
                TextField("对话（Chat）", text: $config.chatFeature)
                    .studioFieldLabel("对话（Chat）")
                TextField("文本（Text）", text: $config.textFeature)
                    .studioFieldLabel("文本（Text）")
            }
            HStack {
                TextField("系统（System）", text: $config.systemFeature)
                    .studioFieldLabel("系统（System）")
                TextField("答案（Answer）", text: $config.answerFeature)
                    .studioFieldLabel("答案（Answer）")
                TextField("类型（Type）", text: $config.typeFeature)
                    .studioFieldLabel("类型（Type）")
            }
            TextField(
                "备用系统提示词（Fallback system prompt，system 字段缺失或为空时使用）",
                text: $config.datasetSystemPrompt,
                axis: .vertical
            )
            .lineLimit(2...6)
            TextField("偏好分数（Preference score）", text: $config.preferenceScoreFeature)
                .studioFieldLabel("偏好分数（Preference score）")
        }
        .formBlock()
    }
}

private struct TrainSettingsPaneModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.72), in: shape)
            .clipShape(shape)
            .contentShape(shape)
            .overlay {
                shape.strokeBorder(.quaternary.opacity(0.28), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .compositingGroup()
    }
}

private extension View {
    func trainSettingsPane(cornerRadius: CGFloat) -> some View {
        modifier(TrainSettingsPaneModifier(cornerRadius: cornerRadius))
    }
}

private struct QATSection: View {
    @Binding var config: TrainingConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("QAT")
            ToggleRow("启用 QAT 投影（projection）", isOn: qatEnableBinding)
            if config.qatEnable {
                HStack {
                    NumberField("位宽（Bits）", value: $config.qatBits)
                    NumberField("分组大小（Group）", value: $config.qatGroupSize)
                    NumberField("起始 step（Start）", value: $config.qatStartStep)
                    NumberField("执行间隔（Interval）", value: $config.qatInterval)
                }
            }
        }
        .formBlock()
    }

    private var qatEnableBinding: Binding<Bool> {
        Binding(
            get: { config.qatEnable },
            set: { isEnabled in
                config.qatEnable = isEnabled
                if isEnabled {
                    config.fuseDequantize = false
                }
            }
        )
    }
}
