import AppKit
import SwiftUI

/// The Runs page. Two stacked regions:
///
/// 1. **Active runs** — a slim list of in-memory `RunRecord`s the
///    store has appended during this session. Shows what the user
///    kicked off and what is still in flight.
/// 2. **Previous runs** — a card grid of every run discovered on disk
///    in the output root. Newest first. Click a card to open a
///    `RunDetailSheet` modal with the loss curve, the auto-discovered
///    metrics cards, the metrics table, and the full training settings
///    panel for that run.
struct RunsView: View {
    @Bindable var store: AppStore
    @State private var selectedRun: PersistedRun?
    @State private var runPendingDelete: PersistedRun?
    @State private var showingClearAllConfirmation = false
    @State private var deleteErrorTitle = "无法删除运行记录"
    @State private var deleteErrorMessage = ""
    @State private var showingDeleteError = false

    private var activeSessionRuns: [RunRecord] {
        store.runs.filter { $0.endedAt == nil && ["Running", "Paused"].contains($0.status) }
    }

    private var deletablePersistedRuns: [PersistedRun] {
        store.persistedRuns.filter { !isCurrentRun($0) }
    }

    private var protectedActiveRunCount: Int {
        store.persistedRuns.count - deletablePersistedRuns.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                activeRunsSection
                previousRunsSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlass(cornerRadius: 18)
        .padding(16)
        .navigationTitle("运行记录")
        .sheet(item: $selectedRun) { run in
            RunDetailSheet(
                run: run,
                canDelete: !isCurrentRun(run),
                continuationCandidate: store.continuationCandidate(for: run),
                onResume: {
                    selectedRun = nil
                    Task { await store.resumeTraining(from: run) }
                },
                onDelete: {
                    selectedRun = nil
                    runPendingDelete = run
                }
            )
        }
        .alert("删除运行记录？", isPresented: deleteConfirmationBinding) {
            Button("删除", role: .destructive) {
                guard let run = runPendingDelete else { return }
                Task { await delete(run) }
            }
            Button("取消", role: .cancel) {
                runPendingDelete = nil
            }
        } message: {
            Text("这将永久删除运行目录及其全部内容。")
        }
        .alert("清空全部运行记录？", isPresented: $showingClearAllConfirmation) {
            Button("清空全部运行记录", role: .destructive) {
                Task { await clearAllRuns() }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text(clearAllConfirmationMessage)
        }
        .alert(deleteErrorTitle, isPresented: $showingDeleteError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(StudioL10n.display(deleteErrorMessage))
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { runPendingDelete != nil },
            set: { if !$0 { runPendingDelete = nil } }
        )
    }

    private func isCurrentRun(_ run: PersistedRun) -> Bool {
        store.allJobRunners.contains { $0.isRunning && run.folderURL.path == $0.lastRunFolder }
    }

    private func delete(_ run: PersistedRun) async {
        do {
            try await store.deletePersistedRun(run)
            if selectedRun?.id == run.id {
                selectedRun = nil
            }
        } catch {
            deleteErrorTitle = "无法删除运行记录"
            deleteErrorMessage = error.localizedDescription
            showingDeleteError = true
        }
        runPendingDelete = nil
    }

    private func clearAllRuns() async {
        do {
            try await store.deletePersistedRuns(deletablePersistedRuns)
            selectedRun = nil
        } catch {
            deleteErrorTitle = "无法清空运行记录"
            deleteErrorMessage = error.localizedDescription
            showingDeleteError = true
            await store.refreshPersistedRuns()
        }
    }

    private var clearAllConfirmationMessage: String {
        let count = deletablePersistedRuns.count
        if protectedActiveRunCount > 0 {
            return "这将永久删除 \(count) 个已保存的运行目录。正在运行的任务目录会保留至任务结束。"
        }
        return "这将永久删除 \(count) 个已保存的运行目录及其全部内容。"
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            HeaderView(
                title: "运行记录",
                subtitle: store.anyJobRunning
                    ? "有任务正在运行"
                    : "历史记录读取自 \(store.outputRoot)",
                symbol: "chart.xyaxis.line"
            )
            Spacer()
            Button(role: .destructive) {
                showingClearAllConfirmation = true
            } label: {
                Label("清空全部运行记录", systemImage: "trash")
            }
            .disabled(deletablePersistedRuns.isEmpty || store.isRefreshingPersistedRuns || store.isDeletingPersistedRuns)
            .buttonStyle(.bordered)
            .help(deletablePersistedRuns.isEmpty ? "没有可删除的已保存运行目录" : "删除全部已保存的运行目录")
            Button {
                Task { await store.refreshPersistedRuns() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .disabled(store.isRefreshingPersistedRuns || store.isDeletingPersistedRuns)
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Active runs

    @ViewBuilder
    private var activeRunsSection: some View {
        if !activeSessionRuns.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("正在运行")
                Text("本次会话中正在运行的任务。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(activeSessionRuns) { run in
                        activeRunRow(run)
                        if run.id != activeSessionRuns.last?.id {
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
                .padding(8)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
            .formBlock()
        }
    }

    private func activeRunRow(_ run: RunRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(run.title).font(.headline)
                Spacer()
                Text(StudioL10n.display(run.status))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(run.status == "Running" ? .green : .secondary)
            }
            Text(run.command)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(run.startedAt, style: .date)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Previous runs

    @ViewBuilder
    private var previousRunsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle("历史运行")
                Spacer()
                if !store.persistedRuns.isEmpty {
                    Text("磁盘上有 \(store.persistedRuns.count) 条")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("从输出目录中发现的记录。点击卡片查看指标和设置。")
                .font(.callout)
                .foregroundStyle(.secondary)

            if store.persistedRuns.isEmpty {
                ContentUnavailableView(
                    "磁盘上尚无运行记录",
                    systemImage: "tray",
                    description: Text("启动训练任务后，收到首条报告时，其运行目录就会显示在这里。")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(store.persistedRuns) { run in
                        RunCard(
                            run: run,
                            canDelete: !isCurrentRun(run),
                            continuationCandidate: store.continuationCandidate(for: run),
                            onOpen: {
                                selectedRun = run
                            },
                            onResume: {
                                Task { await store.resumeTraining(from: run) }
                            },
                            onDelete: {
                                runPendingDelete = run
                            }
                        )
                    }
                }
            }
        }
        .formBlock()
    }
}

// MARK: - Card

/// Compact summary card for a single previous run. Shows the algorithm
/// + model, a sparkline of the loss curve, the final loss value, and
/// the start date. Click anywhere on the card to open the detail sheet.
private struct RunCard: View {
    let run: PersistedRun
    let canDelete: Bool
    let continuationCandidate: TrainingResumeCandidate?
    let onOpen: () -> Void
    let onResume: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            sparkline
            footer
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button {
                onOpen()
            } label: {
                Label("打开详情", systemImage: "arrow.up.right.square")
            }
            Button {
                onResume()
            } label: {
                Label("继续训练", systemImage: "play.circle")
            }
            .disabled(continuationCandidate == nil)
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除运行记录", systemImage: "trash")
            }
            .disabled(!canDelete)
        }
        .help("打开运行详情")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                kindBadge
                Spacer()
                if let continuationCandidate {
                    Button {
                        onResume()
                    } label: {
                        Image(systemName: "play.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help(continueHelp(for: continuationCandidate))
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(!canDelete)
                .help(canDelete ? "删除运行目录" : "无法删除正在运行的任务")
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(run.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            if let spec = run.spec {
                Text(spec.model)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var kindBadge: some View {
        let label: String
        let color: Color
        switch run.kind {
        case .training:
            label = run.spec?.trainMode.title ?? "训练"
            color = .orange
        case .synthetic:
            label = "合成数据"
            color = .purple
        case .hfUpload:
            label = "HF 上传"
            color = .blue
        }
        return Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    @ViewBuilder
    private var sparkline: some View {
        let train = run.metrics.compactMap(\.loss)
        let val = run.metrics.compactMap(\.validationLoss)
        if train.isEmpty {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.04))
                Text("未记录到指标")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(height: 56)
        } else {
            MiniSparkline(trainValues: train, valValues: val)
                .frame(height: 56)
        }
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("最终损失（Final loss）")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(run.finalLoss.map(formatLoss) ?? "—")
                    .font(.system(.callout, design: .monospaced))
            }
            if let val = run.finalValidationLoss {
                VStack(alignment: .leading, spacing: 1) {
                    Text("验证（Val）")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(formatLoss(val))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.blue)
                }
            }
            Spacer()
            Text(run.createdAt, format: .dateTime.month().day().hour().minute())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func formatLoss(_ v: Double) -> String {
        String(format: "%.3f", v)
    }

    private func continueHelp(for candidate: TrainingResumeCandidate) -> String {
        if let step = candidate.step {
            return "从 checkpoint step \(step) 继续训练"
        }
        return "从已保存的 adapter weights 继续训练"
    }
}

// MARK: - Detail sheet

/// Modal that renders everything we know about a previous run: the
/// loss curve (with validation overlay), the same auto-discovered
/// metric cards the Live Metrics page shows, the raw metrics table,
/// the recent trainer reports, and a settings panel summarising the
/// exact `TrainingConfig` that was used. Re-uses `ChartCard`,
/// `MultiLineChart`, `MetricCardGroup`, and `MetricTableRow` from the
/// Live Metrics view so the visual language stays consistent.
private struct RunDetailSheet: View {
    let run: PersistedRun
    let canDelete: Bool
    let continuationCandidate: TrainingResumeCandidate?
    let onResume: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    lossCard
                    autoDiscoveredGrid
                    metricsTableCard
                    settingsCard
                    syntheticSamplesCard
                    recentReportsCard
                }
                .padding(20)
            }
        }
        .frame(minWidth: 820, idealWidth: 980, minHeight: 640, idealHeight: 760)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(run.title)
                    .font(.title2.weight(.semibold))
                Text(run.folderURL.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([run.folderURL])
            } label: {
                Label("在 Finder 中打开", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            if let continuationCandidate {
                Button {
                    onResume()
                    dismiss()
                } label: {
                    Label("继续", systemImage: "play.circle")
                }
                .buttonStyle(.borderedProminent)
                .help(continueHelp(for: continuationCandidate))
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(!canDelete)
            .help(canDelete ? "删除此运行目录" : "无法删除正在运行的任务")
            Button {
                dismiss()
            } label: {
                Text("完成")
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }

    private func continueHelp(for candidate: TrainingResumeCandidate) -> String {
        if let step = candidate.step {
            return "从 checkpoint step \(step) 继续"
        }
        return "从已保存的 adapter weights 继续"
    }

    // MARK: Loss chart

    @ViewBuilder
    private var lossCard: some View {
        let series = buildLossSeries()
        if !series.isEmpty {
            let hasVal = series.contains { $0.id == "val_loss" }
            ChartCard(
                title: "损失（Loss）",
                subtitle: hasVal
                    ? "各 iterations 的训练（实线）和验证（虚线）损失。"
                    : "各 iterations 的训练损失。"
            ) {
                MultiLineChart(series: series, yLabel: "loss")
            }
            .frame(minHeight: 200)
        }
    }

    /// Pulls (loss, step) pairs for train + val from the persisted
    /// metrics. Returns an empty array when the run never produced a
    /// loss sample so the caller can decide not to render a card at
    /// all.
    private func buildLossSeries() -> [MultiLineChart.Series] {
        let trainPairs: [(Double, Int)] = run.metrics.compactMap { m in
            m.loss.map { ($0, m.step) }
        }
        let valPairs: [(Double, Int)] = run.metrics.compactMap { m in
            m.validationLoss.map { ($0, m.step) }
        }
        var series: [MultiLineChart.Series] = []
        if !trainPairs.isEmpty {
            series.append(
                MultiLineChart.Series(
                    id: "loss",
                    label: "训练（Train）",
                    color: .orange,
                    values: trainPairs.map(\.0),
                    xSteps: trainPairs.map(\.1)
                )
            )
        }
        if !valPairs.isEmpty {
            series.append(
                MultiLineChart.Series(
                    id: "val_loss",
                    label: "验证（Validation）",
                    color: .blue,
                    values: valPairs.map(\.0),
                    isDashed: true,
                    xSteps: valPairs.map(\.1)
                )
            )
        }
        return series
    }

    // MARK: Auto-discovered grid

    @ViewBuilder
    private var autoDiscoveredGrid: some View {
        let groups = MetricCardGroup.compute(from: run.metrics)
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("自动发现的指标")
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 320, maximum: 540), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(groups) { group in
                        ChartCard(title: group.title, subtitle: group.subtitle) {
                            MultiLineChart(
                                series: group.series,
                                yLabel: nil,
                                emptyMessage: "正在收集样本…"
                            )
                        }
                        .frame(minHeight: 160)
                    }
                }
            }
            .formBlock()
        }
    }

    // MARK: Metrics table

    @ViewBuilder
    private var metricsTableCard: some View {
        let rows = MetricTableRow.compute(from: run.metrics)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("全部指标")
                VStack(spacing: 0) {
                    tableHeader
                    Divider().background(Color.white.opacity(0.08))
                    ForEach(rows) { row in
                        tableRow(row)
                        if row.id != rows.last?.id {
                            Divider().background(Color.white.opacity(0.04))
                        }
                    }
                }
                .padding(8)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
            .formBlock()
        }
    }

    private var tableHeader: some View {
        HStack {
            Text("指标（Key）").frame(maxWidth: .infinity, alignment: .leading)
            Text("最新值").frame(width: 90, alignment: .trailing)
            Text("最小值").frame(width: 80, alignment: .trailing)
            Text("最大值").frame(width: 80, alignment: .trailing)
            Text("数量").frame(width: 40, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
    }

    private func tableRow(_ row: MetricTableRow) -> some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: row.isValidation ? "checkmark.seal.fill" : "bolt.fill")
                    .font(.caption2)
                    .foregroundStyle(row.isValidation ? .blue.opacity(0.8) : .orange.opacity(0.8))
                Text(row.displayName)
                    .font(.system(.caption, design: .monospaced))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatNumber(row.latest))
                .font(.caption.monospacedDigit())
                .frame(width: 90, alignment: .trailing)
            Text(formatNumber(row.min))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(formatNumber(row.max))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text("\(row.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func formatNumber(_ v: Double) -> String {
        if abs(v) >= 1000 || (abs(v) < 0.01 && v != 0) {
            return String(format: "%.2e", v)
        }
        return String(format: "%.3f", v)
    }

    // MARK: Settings

    @ViewBuilder
    private var settingsCard: some View {
        if let syntheticSpec = run.syntheticSpec {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("数据集运行设置")
                SyntheticSettingsGrid(spec: syntheticSpec)
            }
            .formBlock()
        } else if run.kind == .synthetic {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("数据集运行设置")
                Text("无法解码此目录中的 synthetic_spec.json。原始文件仍保存在磁盘上，可自行查看。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .formBlock()
        } else if let spec = run.spec {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("训练设置")
                SettingsGrid(spec: spec)
            }
            .formBlock()
        } else if run.kind == .training {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("训练设置")
                Text("无法解码此目录中的 run_spec.json。原始文件仍保存在磁盘上，可自行查看。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .formBlock()
        }
    }

    @ViewBuilder
    private var syntheticSamplesCard: some View {
        if run.kind == .synthetic {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("数据集样本")
                if run.syntheticSamples.isEmpty {
                    Text("此运行目录中尚未找到生成的 JSONL 样本。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(run.syntheticSamples) { sample in
                            syntheticSampleBlock(sample)
                        }
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .formBlock()
        }
    }

    private func syntheticSampleBlock(_ sample: SyntheticDatasetSample) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Sample \(sample.index)")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(sample.sourceFile)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            ForEach(sample.fields) { field in
                VStack(alignment: .leading, spacing: 3) {
                    Text(field.key)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(shortened(field.value, limit: 1_800))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(12)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
    }

    private func shortened(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        let index = value.index(value.startIndex, offsetBy: limit)
        return String(value[..<index]) + "\n…"
    }

    // MARK: Recent reports

    @ViewBuilder
    private var recentReportsCard: some View {
        if !run.metrics.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("最近报告")
                let recents = Array(run.metrics.suffix(5).reversed())
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(recents) { metric in
                        rawLineBlock(metric)
                    }
                }
                .padding(10)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
            .formBlock()
        }
    }

    private func rawLineBlock(_ metric: TrainingMetric) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Iter \(metric.step)")
                    .font(.caption.weight(.semibold))
                Spacer()
                if let loss = metric.loss {
                    Text("loss \(String(format: "%.3f", loss))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let mem = metric.memoryGB {
                    Text(String(format: "%.2f GB", mem))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text(metric.rawLine)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(8)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Settings grid

private struct SyntheticSettingsGrid: View {
    let spec: SyntheticConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsGroup("数据集（Dataset）") {
                row("类型（Type）", spec.kind.title)
                row("源数据集（Source dataset）", spec.datasetPath)
                row("输出目录（Output folder）", spec.outputDir)
                if !spec.resumeOutputDir.isEmpty {
                    row("续写目录（Resume output）", spec.resumeOutputDir)
                }
                row("样本总数（Samples）", "\(spec.numSamples)")
                row("验证集划分（Validation split）", spec.validSplit)
                row("测试集划分（Test split）", spec.testSplit)
            }
            settingsGroup("服务提供方（Provider）") {
                row("后端（Backend）", spec.backend.title)
                row("基础地址（Base URL）", spec.baseURL)
                if spec.kind == .sft {
                    row("模型（Model）", spec.model)
                } else {
                    row("基础模型（Base model）", spec.baseModel)
                    row("教师模型（Teacher model）", spec.teacherModel)
                    row("生成目标（Generation target）", spec.dpoGenerationTarget.title)
                }
            }
            settingsGroup("生成设置（Generation）") {
                row("批大小（Batch size）", "\(spec.batchSize)")
                row("最大并发数（Max concurrent）", "\(spec.maxConcurrent)")
                row("随机种子（Seed）", "\(spec.seed)")
                row("系统提示词（System prompt）", spec.systemPrompt)
                row("包含系统提示词（Include system prompt）", spec.includeSystemPrompt ? "on" : "off")
                row("使用标准答案（Use ground truth）", spec.useGroundTruth ? "on" : "off")
            }
            if spec.kind == .sft {
                settingsGroup("对话（Conversation）") {
                    row("多轮对话（Multiturn）", spec.multiturn ? "on" : "off")
                    row("最大轮数（Max turns）", "\(spec.maxTurns)")
                    row("多轮对话比例（Multiturn percentile）", String(format: "%.2f", spec.multiturnPercentile))
                    row("用户角色模型（Human role model）", spec.humanRoleModel)
                }
            }
            if spec.useGenerationSettings {
                settingsGroup("采样（Sampling）") {
                    row("最大 tokens 数（Max tokens）", "\(spec.maxTokens)")
                    row("采样温度（Temperature）", String(format: "%.2f", spec.temperature))
                    row("累计概率阈值（Top-p）", String(format: "%.2f", spec.topP))
                    row("Min-p 阈值（Min-p）", String(format: "%.2f", spec.minP))
                    row("候选数量（Top-k）", "\(spec.topK)")
                    row("最少保留 tokens 数（Min tokens to keep）", "\(spec.minTokensToKeep)")
                    row("XTC 概率（XTC probability）", String(format: "%.2f", spec.xtcProbability))
                    row("XTC 阈值（XTC threshold）", String(format: "%.2f", spec.xtcThreshold))
                }
            }
        }
    }

    @ViewBuilder
    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 180, alignment: .leading)
            Text(value.isEmpty ? "-" : value)
                .font(.caption.monospacedDigit())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Two-column key/value listing of the run's `TrainingConfig`. Groups
/// the fields into headed sections (Model & Data, Optimisation,
/// Algorithm-specific, …) so a 60-line config doesn't become an
/// unreadable wall of rows.
private struct SettingsGrid: View {
    let spec: TrainingConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsGroup("模型与数据（Model & Data）") {
                row("模型（Model）", spec.model)
                row("数据集（Dataset）", spec.data)
                row("适配器路径（Adapter path）", spec.adapterPath)
            }
            settingsGroup("算法（Algorithm）") {
                row("训练模式（Mode）", spec.trainMode.title)
                row("算法类别（Family）", spec.trainMode.family)
                row("微调方式（Train type）", spec.trainType.title)
                row("优化器（Optimizer）", spec.optimizer.title)
                row("量化（Quantization）", spec.quantization.title)
                if spec.trainMode.needsReference, !spec.referenceModelPath.isEmpty {
                    row("参考模型（Reference model）", spec.referenceModelPath)
                }
                if spec.trainMode.needsJudge, !spec.judge.isEmpty {
                    row("评审模型（Judge）", spec.judge)
                }
            }
            settingsGroup("优化设置（Optimisation）") {
                row("学习率（Learning rate）", String(format: "%.3e", spec.learningRate))
                row("学习率计划（LR schedule）", scheduleLabel)
                row("批大小（Batch size）", "\(spec.batchSize)")
                row("梯度累积步数（Grad accumulation）", "\(spec.gradientAccumulationSteps)")
                row(itersOrEpochsKey, itersOrEpochsValue)
                row("验证批数（Val batches）", "\(spec.valBatches)")
                row("最大序列长度（Max seq length）", "\(spec.maxSeqLength)")
            }
            settingsGroup("LoRA 参数（LoRA Parameters）") {
                row("秩（Rank）", "\(spec.rank)")
                row("缩放系数（Scale）", String(format: "%.1f", spec.scale))
                row("丢弃率（Dropout）", String(format: "%.3f", spec.dropout))
            }
            settingsGroup("报告与保存（Reporting & Saving）") {
                row("报告间隔（Steps per report）", "\(spec.stepsPerReport)")
                row("评估间隔（Steps per eval）", "\(spec.stepsPerEval)")
                row("保存间隔（Save every）", "\(spec.saveEvery)")
            }
            settingsGroup("开关（Toggles）") {
                row("梯度检查点（Grad checkpoint）", spec.gradCheckpoint ? "on" : "off")
                row("高效长上下文（Efficient long context）", spec.efficientLongContext ? "on" : "off")
                row("屏蔽提示部分的损失（Mask prompt）", spec.maskPrompt ? "on" : "off")
                row("合并权重（Fuse）", spec.fuse ? "on" : "off")
            }
            algorithmSpecificGroup
            qatGroup
        }
    }

    // MARK: - Group builders

    @ViewBuilder
    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var algorithmSpecificGroup: some View {
        switch spec.trainMode {
        case .dpo, .cpo, .orpo, .onlineDPO, .xpo, .rlhfReinforce, .ppo:
            settingsGroup("偏好／强化学习（Preference / RL）") {
                row("系数（β (beta)）", String(format: "%.3f", spec.beta))
                if spec.trainMode == .dpo || spec.trainMode == .cpo {
                    row("损失类型（Loss type）", spec.dpoCpoLossType)
                }
                if spec.trainMode == .cpo || spec.trainMode == .orpo {
                    row("惩罚系数（δ (delta)）", String(format: "%.1f", spec.delta))
                }
                if spec.trainMode.needsJudge, !spec.alpha.isEmpty {
                    row("系数（α (alpha)）", spec.alpha)
                }
                if spec.trainMode == .rlhfReinforce {
                    row("奖励缩放（Reward scaling）", String(format: "%.2f", spec.rewardScaling))
                }
            }
        case .ftpo:
            settingsGroup("FTPO") {
                row("目标 MSE 系数（Target MSE λ）", String(format: "%.3f", spec.lambdaMSETarget))
                row("目标 MSE 阈值（Target MSE τ）", String(format: "%.3f", spec.tauMSETarget))
                row("非目标 MSE 系数（Non-target MSE λ）", String(format: "%.3f", spec.lambdaMSE))
                row("Logit 裁剪阈值（Logit clip ε）", String(format: "%.3f", spec.clipEpsilonLogits))
            }
        case .grpo:
            settingsGroup("GRPO") {
                row("组大小（Group size）", "\(spec.groupSize)")
                row("裁剪阈值（ε (epsilon)）", String(format: "%.4f", spec.epsilon))
                if !spec.epsilonHigh.isEmpty {
                    row("裁剪上界（ε high）", spec.epsilonHigh)
                }
                row("损失类型（Loss type）", spec.grpoLossType)
                row("最大回答长度（Max completion length）", "\(spec.maxCompletionLength)")
                row("采样温度（Temperature）", String(format: "%.2f", spec.temperature))
                row("累计概率阈值（Top-p）", String(format: "%.2f", spec.topP))
                row("候选数量（Top-k）", "\(spec.topK)")
                row("Min-p 阈值（Min-p）", String(format: "%.2f", spec.minP))
            }
        case .sft:
            settingsGroup("SFT") { row("损失（Loss）", spec.sftLossType.title) }
        }
    }

    @ViewBuilder
    private var qatGroup: some View {
        if spec.qatEnable {
            settingsGroup("Quantization-Aware Training") {
                row("位宽（Bits）", "\(spec.qatBits)")
                row("量化分组大小（Group size）", "\(spec.qatGroupSize)")
                row("起始 step（Start step）", "\(spec.qatStartStep)")
                row("执行间隔（Interval）", "\(spec.qatInterval)")
            }
        }
    }

    // MARK: - Row + helpers

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 180, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.caption.monospacedDigit())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var scheduleLabel: String {
        switch spec.learningRateSchedule {
        case .constant:
            return "constant"
        case .cosineDecay:
            return "cosine decay (warmup \(spec.lrWarmupSteps), init \(String(format: "%.2e", spec.lrWarmupInit)), final \(String(format: "%.2e", spec.lrFinal)))"
        }
    }

    private var itersOrEpochsKey: String {
        spec.epochs > 0 ? "数据轮次（Epochs）" : "迭代次数（Iterations）"
    }

    private var itersOrEpochsValue: String {
        spec.epochs > 0 ? "\(spec.epochs)" : "\(spec.iters)"
    }
}
