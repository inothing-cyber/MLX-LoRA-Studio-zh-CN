import SwiftUI

@MainActor
struct SyntheticDataView: View {
    @Bindable var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeaderView(title: "合成数据", subtitle: "\(store.synthetic.kind.title) 生成器", symbol: "sparkles")

                // The long pill at the top is the **only** way to
                // start *and* cancel a synthetic-data run from this
                // page. While the run is in flight it switches to a
                // red Cancel pill so the user can stop the job from
                // the same place they launched it — the upper-right
                // toolbar pair is reserved for the training runner
                // and no longer intercepts the synthetic cancel
                // action.
                let isRunning = store.syntheticRunner.isRunning
                Button {
                    if isRunning {
                        store.syntheticRunner.stop()
                    } else {
                        Task { await store.startSynthetic() }
                    }
                } label: {
                    Label(
                        isRunning ? "取消生成" : generateButtonTitle,
                        systemImage: isRunning ? "xmark.circle.fill" : "sparkles"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRunning ? .red : .accentColor)
                .controlSize(.large)

                SyntheticRunConsolePill(runner: store.syntheticRunner)

                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle("Dataset 类型")
                    Picker("Kind", selection: $store.synthetic.kind) {
                        ForEach(SyntheticKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: store.synthetic.kind) { _, kind in
                        store.synthetic.applyDefaultDataset(for: kind)
                    }
                }
                .formBlock()

                SyntheticSourceSection(config: $store.synthetic)
                    .environment(store)
                SyntheticSystemPromptSection(config: $store.synthetic)
                    .environment(store)
                SyntheticOutputSection(
                    config: $store.synthetic,
                    outputRoot: store.outputRoot,
                    lastRunFolder: store.syntheticRunner.lastRunFolder,
                    outputs: store.syntheticRunOutputs,
                    onRefresh: { Task { await store.refreshLocalRunOutputs() } },
                    onSelectResume: { path in store.loadSyntheticConfig(fromGeneratedDataPath: path) }
                )
                SyntheticSamplingSection(config: $store.synthetic)
                SyntheticSplitSection(config: $store.synthetic)
            }
            .padding(24)
        }
        .frame(minWidth: 360, idealWidth: 620, maxWidth: .infinity)
        .liquidGlass(cornerRadius: 18)
        .padding(16)
        .navigationTitle("合成数据")
    }

    private var generateButtonTitle: String {
        store.synthetic.resumeOutputDir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "生成 Synthetic Dataset"
            : "继续生成 Synthetic Dataset"
    }
}

@MainActor
private struct SyntheticRunConsolePill: View {
    @Bindable var runner: PythonJobRunner

    private var recentLines: [String] {
        Array(runner.logLines.suffix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(runner.isRunning ? .green : .secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(runner.isRunning ? 1.12 : 0.9)

                Text(runner.isRunning ? "实时运行" : "运行控制台")
                    .font(.headline)

                Text(StudioL10n.display(commandSummary))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    runner.clearTerminal()
                } label: {
                    Label("清空", systemImage: "eraser")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .disabled(runner.logLines.isEmpty)
            }

            RunProgressBar(runner: runner)

            if recentLines.isEmpty {
                Text("就绪")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(recentLines.enumerated()), id: \.offset) { _, line in
                        Text(StudioL10n.log(line))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(line.contains("[Studio]") ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.quaternary.opacity(0.45), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: runner.isRunning)
        .animation(.easeInOut(duration: 0.18), value: runner.logLines.count)
    }

    private var commandSummary: String {
        runner.currentCommand.isEmpty ? "就绪" : runner.currentCommand
    }
}

@MainActor
private struct SyntheticSourceSection: View {
    @Binding var config: SyntheticConfig
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("来源")
            HFAssetPicker(
                text: $config.datasetPath,
                kind: .dataset,
                placeholder: "Prompt dataset"
            )
            Picker("Backend", selection: $config.backend) {
                ForEach(SyntheticBackend.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            .onChange(of: config.backend) { _, backend in
                config.applyBackendDefaults(for: backend)
            }
            if config.kind == .sft {
                if config.backend == .mlx {
                    HFAssetPicker(
                        text: $config.model,
                        kind: .model,
                        placeholder: "Generator model"
                    )
                } else {
                    SyntheticProviderModelPicker(
                        text: $config.model,
                        backend: config.backend
                    )
                }
                ToggleRow("最终记录中包含 system prompt", isOn: $config.includeSystemPrompt)
                ToggleRow("将 ground-truth 部分作为 generation context", isOn: $config.useGroundTruth)
            } else {
                Picker("生成", selection: $config.dpoGenerationTarget) {
                    ForEach(SyntheticDPOGenerationTarget.allCases) { target in
                        Text(target.title).tag(target)
                    }
                }
                .pickerStyle(.segmented)
                Text(config.dpoGenerationTarget.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HFAssetPicker(
                    text: $config.baseModel,
                    kind: .model,
                    placeholder: "Base model"
                )
                if config.backend == .mlx {
                    HFAssetPicker(
                        text: $config.teacherModel,
                        kind: .model,
                        placeholder: "Teacher model"
                    )
                } else {
                    SyntheticProviderModelPicker(
                        text: $config.teacherModel,
                        backend: config.backend
                    )
                }
            }
            if config.backend != .mlx {
                if config.backend == .custom {
                    CustomProviderPicker(config: $config, store: store)
                }
                TextField("Base URL", text: $config.baseURL)
                if config.backend != .custom || config.customProviderID == nil {
                    SyntheticProviderKeyField(store: store, backend: config.backend)
                }
                if config.kind == .sft {
                    ToggleRow("生成 multi-turn conversations", isOn: $config.multiturn)
                }
                if config.kind == .sft && config.multiturn {
                    HStack {
                        NumberField("Turns", value: $config.maxTurns)
                        NumberField("Concurrent", value: $config.maxConcurrent)
                        FloatingField("Multi-turn %", value: $config.multiturnPercentile)
                    }
                    TextField("Human-role model（可选）", text: $config.humanRoleModel)
                } else {
                    NumberField("Concurrent", value: $config.maxConcurrent)
                }
                Text("\(config.backend.title) 的同时进行 API requests 数量。此项控制所有非 MLX 后端（OpenAI / OpenRouter / Ollama / LM Studio / oMLX / Custom）的并行度；下方的 Batch 对这些后端均无效，只影响本地 MLX 后端。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formBlock()
        .animation(.easeInOut(duration: 0.2), value: config.kind)
        .animation(.easeInOut(duration: 0.2), value: config.backend)
    }
}

@MainActor
private struct CustomProviderPicker: View {
    @Binding var config: SyntheticConfig
    @Bindable var store: AppStore
    @State private var name = ""
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var isCreating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("已保存的 provider", selection: Binding(
                get: { config.customProviderID },
                set: { selectProvider($0) }
            )) {
                Text("尚未保存的自定义 provider").tag(UUID?.none)
                ForEach(store.customProviders) { provider in
                    Text(provider.name).tag(Optional(provider.id))
                }
            }
            .pickerStyle(.menu)

            DisclosureGroup("新建自定义 provider", isExpanded: $isCreating) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Provider 名称", text: $name)
                    TextField("Base URL", text: $baseURL)
                    SecureField("API key", text: $apiKey)
                    Button("保存 Provider") {
                        guard let provider = store.saveCustomProvider(
                            name: name,
                            baseURL: baseURL,
                            apiKey: apiKey
                        ) else { return }
                        selectProvider(provider.id)
                        name = ""
                        baseURL = ""
                        apiKey = ""
                        isCreating = false
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines))?.scheme == nil)
                }
                .padding(.top, 8)
            }
        }
    }

    private func selectProvider(_ id: UUID?) {
        config.customProviderID = id
        guard let provider = store.customProviders.first(where: { $0.id == id }) else { return }
        config.backend = .custom
        config.baseURL = provider.baseURL
    }
}

/// Text field + dropdown + refresh button for picking a generator
/// model from a synthetic-data provider backend (OpenAI, OpenRouter,
/// Ollama, LM Studio, oMLX, Custom).
///
/// Unlike the model picker on the Train page — which lists whatever
/// is already in the local HF cache — the providers don't have a
/// "cache" we can walk, so the picker live-scrapes the provider's
/// `GET /models` (or Ollama's `GET /api/tags`) endpoint to populate
/// the dropdown. The scrape fires automatically when the picker
/// first appears and again whenever the user switches to a
/// different backend; the refresh button next to the picker
/// triggers a manual rescrape for the rare case where a new model
/// shows up mid-session.
///
/// The user can always type a model id directly into the text
/// field — the dropdown is just a convenience. Whatever the user
/// types is what the trainer receives, scraped list or not.
@MainActor
private struct SyntheticProviderModelPicker: View {
    @Binding var text: String
    let backend: SyntheticBackend
    @Environment(AppStore.self) private var store

    /// Tracks whether we've already kicked off a first-time scrape
    /// for the currently-mounted picker instance. The picker gets
    /// a fresh identity per backend (`.id(backend)` on its parent
    /// container), so this is reset every time the user switches
    /// providers.
    @State private var didAutoScrape = false

    private var scrapedModels: [String] {
        store.providerModels[backend] ?? []
    }

    private var isScanning: Bool {
        store.isScanningProviderModels.contains(backend)
    }

    private var lastError: String? {
        store.providerModelError[backend]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "network")
                    .foregroundStyle(.secondary)
                TextField("Generator model", text: $text)
                    .textFieldStyle(.roundedBorder)
                Menu {
                    pickerMenuContent
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.down")
                        Text("选择")
                            .font(.callout)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Button {
                    Task { await store.scrapeProviderModels(backend: backend) }
                } label: {
                    if isScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .help("重新获取 \(backend.title) 的最新 model 列表")
            }
            footer
        }
        // The picker gets a fresh identity per backend so the
        // auto-scrape `didAutoScrape` flag is automatically reset on
        // provider switch — no leftover state from the previous
        // backend can leak through.
        .id(backend)
        .task {
            // `task` fires on first appearance AND every time the
            // view's identity changes (e.g. backend switch, since
            // `.id(backend)` re-mounts the subtree). Combined with
            // the `didAutoScrape` guard, this gives us a single
            // auto-scrape per appearance, exactly the behavior we
            // want.
            guard !didAutoScrape else { return }
            didAutoScrape = true
            await store.scrapeProviderModels(backend: backend)
        }
    }

    // MARK: - Menu

    @ViewBuilder
    private var pickerMenuContent: some View {
        if isScanning && scrapedModels.isEmpty {
            Text("正在获取 \(backend.title) 的 model…")
                .foregroundStyle(.secondary)
        } else if scrapedModels.isEmpty {
            if let lastError {
                Text(StudioL10n.display(lastError))
                    .foregroundStyle(.secondary)
            } else {
                Text("尚未获取 model，请点击刷新按钮")
                    .foregroundStyle(.secondary)
            }
        } else {
            Section("\(backend.title) models (\(scrapedModels.count))") {
                ForEach(scrapedModels, id: \.self) { model in
                    Button {
                        text = model
                    } label: {
                        Label(model, systemImage: "sparkles")
                    }
                }
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 6) {
            if let lastError {
                Label(StudioL10n.display(lastError), systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            } else if isScanning {
                Text("正在从 \(backend.title) 获取实时 model 列表…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if !scrapedModels.isEmpty {
                Text("已从 \(backend.title) 获取 \(scrapedModels.count) 个 model")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("点击刷新按钮，从 \(backend.title) 获取 model")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }
}

/// Password-style field for the synthetic-data provider API key.
///
/// Mirrors `HuggingFaceTokenField` in the Settings view: the field
/// never holds the secret in its own state. Instead, it shows a
/// placeholder ("••• set" when a key is already in the Keychain for
/// the current provider, "Paste key…" when not) and only switches
/// into a real text editor once the user clicks "Set…" or
/// "Replace…" — at which point the new value is committed to the
/// per-provider Keychain slot on save and the draft is cleared from
/// memory.
///
/// Each provider has its own Keychain slot (see
/// `AppStore.syntheticProviderKeyIsSet`), so the saved-key indicator
/// automatically updates to reflect the *currently selected*
/// backend's state when the user switches providers in the picker
/// above. We force a re-render of the field with `.id(backend)` so a
/// pending "in edit" state for one provider is discarded the moment
/// the user picks another provider.
@MainActor
private struct SyntheticProviderKeyField: View {
    @Bindable var store: AppStore
    let backend: SyntheticBackend

    /// `true` while the user is in the middle of typing a new key.
    /// When `false`, the field renders the placeholder, never the
    /// real stored value.
    @State private var isEditing = false
    @State private var draft = ""

    private var isSet: Bool {
        store.syntheticProviderKeyIsSet[backend] ?? false
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill")
                .foregroundStyle(.secondary)
            Group {
                if isEditing {
                    SecureField("sk-…", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(commit)
                } else {
                    // The placeholder is the only thing visible when
                    // not editing. We intentionally never read the
                    // key back from the Keychain into the field —
                    // that would defeat the point of a secret field.
                    Text(placeholder)
                        .foregroundStyle(isSet ? .primary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.quaternary.opacity(0.3))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                }
            }
            if isEditing {
                Button("保存") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("取消") {
                    draft = ""
                    isEditing = false
                }
            } else {
                Button(isSet ? "替换…" : "设置…") {
                    draft = ""
                    isEditing = true
                }
                if isSet {
                    Button {
                        store.clearSyntheticProviderKey(for: backend)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("移除为 \(backend.title) 保存的 key")
                }
            }
        }
        // Discard a pending "in edit" state and draft the moment the
        // user picks a different provider — otherwise typing a key
        // for OpenRouter, then switching to OpenAI, would briefly
        // show the OpenRouter draft in the OpenAI field.
        .id(backend)
        .onChange(of: backend) { _, _ in
            draft = ""
            isEditing = false
        }
    }

    private var placeholder: String {
        isSet
            ? "••• \(backend.title) key 已保存在 Keychain 中"
            : "未设置 key，\(backend.title) 可不填写"
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        store.setSyntheticProviderKey(trimmed, for: backend)
        draft = ""
        isEditing = false
    }
}

@MainActor
private struct SyntheticSystemPromptSection: View {
    @Binding var config: SyntheticConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("System Prompt")
            SystemPromptPicker(
                text: $config.systemPrompt,
                placeholder: "System prompt 文本或文件"
            )
        }
        .formBlock()
    }
}

@MainActor
private struct SyntheticOutputSection: View {
    @Binding var config: SyntheticConfig
    let outputRoot: String
    let lastRunFolder: String
    let outputs: [LocalRunOutput]
    let onRefresh: () -> Void
    let onSelectResume: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("输出")
            TextField("运行目录名称", text: $config.runFolderName)
            SyntheticResumeRunPicker(
                selection: $config.resumeOutputDir,
                outputs: outputs,
                onRefresh: onRefresh,
                onSelectResume: onSelectResume
            )
            HStack(alignment: .top, spacing: 12) {
                InfoPill(
                    text: runFolderDisplayName,
                    symbol: "folder",
                    openPath: preferredRunFolderPath
                )
                InfoPill(text: "根目录：\(outputRoot)", symbol: "externaldrive", openPath: outputRoot)
            }
            Text("生成的 dataset 保存在运行目录的 generated-data 子目录中。要继续未完成的运行，请在此选择已有记录，并将 Samples 保持为所需的最终总数。")
                .foregroundStyle(.secondary)
                .font(.callout)
            if !lastRunFolder.isEmpty {
                Text(lastRunFolder)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formBlock()
    }

    private var runFolderDisplayName: String {
        if !config.resumeOutputDir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: config.resumeOutputDir).deletingLastPathComponent().lastPathComponent
        }
        return config.runFolderName.isEmpty ? config.automaticRunFolderName() : config.resolvedRunFolderName()
    }

    private var preferredRunFolderPath: String {
        let resumeOutput = config.resumeOutputDir.trimmingCharacters(in: .whitespacesAndNewlines)
        if !resumeOutput.isEmpty {
            return URL(fileURLWithPath: NSString(string: resumeOutput).expandingTildeInPath, isDirectory: true)
                .deletingLastPathComponent()
                .path
        }
        if !lastRunFolder.isEmpty {
            return lastRunFolder
        }
        let expandedRoot = NSString(string: outputRoot).expandingTildeInPath
        return URL(fileURLWithPath: expandedRoot, isDirectory: true)
            .appending(path: runFolderDisplayName, directoryHint: .isDirectory)
            .path
    }
}

@MainActor
private struct SyntheticResumeRunPicker: View {
    @Binding var selection: String
    let outputs: [LocalRunOutput]
    let onRefresh: () -> Void
    let onSelectResume: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Picker("继续运行", selection: $selection) {
                    Text("重新开始").tag("")
                    ForEach(outputs) { output in
                        Text(output.name).tag(output.path)
                    }
                    if !selection.isEmpty && !outputs.contains(where: { $0.path == selection }) {
                        Text("自定义：\(URL(fileURLWithPath: selection).deletingLastPathComponent().lastPathComponent)")
                            .tag(selection)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selection) { _, path in
                    guard !path.isEmpty else { return }
                    onSelectResume(path)
                }

                Button {
                    onRefresh()
                } label: {
                    Label("刷新运行记录", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .help("刷新合成数据运行记录")
            }

            if outputs.isEmpty {
                Text("输出根目录中尚未找到 generated-data 目录。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !selection.isEmpty {
                Text(selection)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
    }
}

@MainActor
private struct SyntheticSamplingSection: View {
    @Binding var config: SyntheticConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Sampling")
            HStack {
                NumberField("Samples", value: $config.numSamples)
                NumberField("Batch", value: $config.batchSize)
                NumberField("Seed", value: $config.seed)
            }
            // `batchSize` only affects the local MLX backend —
            // it's the number of examples the local generator
            // processes in parallel per step. Cloud / server
            // providers (OpenAI / OpenRouter / Ollama / LM Studio /
            // oMLX / Custom) ignore it and use the `Concurrent`
            // field in the Source section above as their
            // in-flight request count. We surface a short
            // explainer so the user doesn't have to guess which
            // knob is the live one for the currently selected
            // backend.
            Text(batchExplainer)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ToggleRow("使用自定义 generation 设置", isOn: $config.useGenerationSettings)
            if config.useGenerationSettings {
                HStack {
                    NumberField("Tokens", value: $config.maxTokens)
                    FloatingField("Temp", value: $config.temperature)
                    FloatingField("Top P", value: $config.topP)
                    FloatingField("Min P", value: $config.minP)
                }
                HStack {
                    NumberField("Top K", value: $config.topK)
                    NumberField("Min Keep", value: $config.minTokensToKeep)
                    FloatingField("XTC Prob", value: $config.xtcProbability)
                    FloatingField("XTC Threshold", value: $config.xtcThreshold)
                }
            } else if config.backend != .mlx {
                Text("API requests 将不携带 generation 设置，由 provider 或本地服务器使用其默认值。")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .formBlock()
        .animation(.easeInOut(duration: 0.2), value: config.useGenerationSettings)
    }

    /// Short explainer under the Samples / Batch / Seed row that
    /// tells the user which of the two parallelism knobs (Batch
    /// here vs Concurrent in the Source section) is actually
    /// driving the run for the currently selected backend.
    private var batchExplainer: String {
        if config.backend == .mlx {
            return "Batch 控制本地 MLX 生成器的并行度。来源区域的 Concurrent 字段在使用 MLX 时隐藏，仅对下方非 MLX 后端显示。"
        }
        return "\(config.backend.title) 会忽略 Batch，其他所有非 MLX 后端也一样（OpenAI / OpenRouter / Ollama / LM Studio / oMLX / Custom 均使用相同的 OpenAI-compatible 路径）。Batch 只影响本地 MLX 后端。请使用上方来源区域的 Concurrent 字段控制此 provider 的并行度。"
    }
}

@MainActor
private struct SyntheticSplitSection: View {
    @Binding var config: SyntheticConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Splits")
            HStack {
                TextField("Validation split", text: $config.validSplit)
                TextField("Test split", text: $config.testSplit)
            }
            Text("Split 字段留空时，全部生成样本将写入 train parquet。")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .formBlock()
    }
}
