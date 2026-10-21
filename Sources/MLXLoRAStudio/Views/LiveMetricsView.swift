import SwiftUI

/// A page that visualises every metric the active trainer has emitted
/// so far. Discovery is dynamic: cards appear as the relevant keys
/// start landing in `runner.metrics`, and disappear (well, become
/// empty placeholders) if a future step stops producing them. The
/// classic single-series loss chart is kept full-width at the top
/// because it's the most-read signal during training.
struct LiveMetricsView: View {
    @Bindable var runner: PythonJobRunner

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summaryTiles
                lossCard
                autoDiscoveredGrid
                metricsTableCard
                recentRawLinesCard
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlass(cornerRadius: 18)
        .padding(16)
    }

    // MARK: - Header

    private var header: some View {
        HeaderView(
            title: "实时指标",
            subtitle: runner.metrics.isEmpty
                ? "等待训练器输出…"
                : "从当前训练器自动发现",
            symbol: "chart.line.uptrend.xyaxis"
        )
    }

    // MARK: - Summary tiles

    private var summaryTiles: some View {
        HStack(spacing: 10) {
            StatTile(title: "步数（Step）", value: latestStep)
            StatTile(title: "损失（Loss）", value: latestLoss)
            StatTile(title: "速度（Speed）", value: latestItPerSec)
            StatTile(title: "Tokens/s", value: latestTokPerSec)
            StatTile(title: "内存", value: latestMemory)
            StatTile(title: "学习率（LR）", value: latestLearningRate)
        }
    }

    private var latest: TrainingMetric? { runner.metrics.last }
    private var latestStep: String { latest.map { "Iter \($0.step)" } ?? "-" }
    private var latestLoss: String { latest?.loss.map { String(format: "%.3f", $0) } ?? "-" }
    private var latestMemory: String { latest?.memoryGB.map { String(format: "%.2f GB", $0) } ?? "-" }
    private var latestItPerSec: String { latest?.values["it_s"].map { String(format: "%.2f it/s", $0) } ?? "-" }
    private var latestTokPerSec: String { latest?.values["tok_s"].map { String(format: "%.0f", $0) } ?? "-" }
    private var latestLearningRate: String { latest?.learningRate.map { String(format: "%.2e", $0) } ?? "-" }

    // MARK: - Loss chart (full width)

    private var lossCard: some View {
        // Walk the metrics once to keep train + val values paired with their
        // step numbers. Validation reports lag training and skip samples,
        // so each series carries its own xSteps for the hover callout.
        var trainValues: [Double] = []
        var trainSteps: [Int] = []
        var valValues: [Double] = []
        var valSteps: [Int] = []
        var testValues: [Double] = []
        var testSteps: [Int] = []
        for metric in runner.metrics {
            if let loss = metric.loss {
                trainValues.append(loss)
                trainSteps.append(metric.step)
            }
            if let valLoss = metric.validationLoss {
                valValues.append(valLoss)
                valSteps.append(metric.step)
            }
            if let testLoss = metric.testLoss {
                testValues.append(testLoss)
                testSteps.append(metric.step)
            }
        }

        var series: [MultiLineChart.Series] = [
            MultiLineChart.Series(
                id: "loss",
                label: "训练（Train）",
                color: .orange,
                values: trainValues,
                xSteps: trainSteps
            )
        ]
        if !valValues.isEmpty {
            series.append(
                MultiLineChart.Series(
                    id: "val_loss",
                    label: "验证（Validation）",
                    color: .blue,
                    values: valValues,
                    isDashed: true,
                    xSteps: valSteps
                )
            )
        }
        if !testValues.isEmpty {
            series.append(
                MultiLineChart.Series(
                    id: "test_loss",
                    label: "测试（Test）",
                    color: .green,
                    values: testValues,
                    isDashed: true,
                    xSteps: testSteps
                )
            )
        }

        let subtitle = valValues.isEmpty && testValues.isEmpty
            ? "各 iterations 的训练损失，是最常查看的信号。"
            : "各 iterations 的训练（实线）、验证和测试（虚线）损失。"

        return ChartCard(title: "损失（Loss）", subtitle: subtitle) {
            MultiLineChart(series: series, yLabel: "loss")
        }
        .frame(minHeight: 180)
    }

    // MARK: - Auto-discovered grid

    @ViewBuilder
    private var autoDiscoveredGrid: some View {
        let groups = MetricCardGroup.compute(from: runner.metrics)
        if groups.isEmpty {
            EmptyView()
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: 540), spacing: 16)], spacing: 16) {
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
    }

    // MARK: - Metrics table

    private var metricsTableCard: some View {
        let rows = MetricTableRow.compute(from: runner.metrics)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle("全部指标")
            Text("训练器报告过的所有指标。验证和测试指标保留各自的原始 split 前缀。")
                .font(.callout)
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text("尚无指标。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
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
        }
        .formBlock()
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
                if row.isValidation {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue.opacity(0.8))
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange.opacity(0.8))
                }
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

    // MARK: - Recent raw lines

    private var recentRawLinesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("最近报告")
            Text("最近几条训练器报告的原文，便于结合上下文分析图表中的突变。")
                .font(.callout)
                .foregroundStyle(.secondary)
            let recents = Array(runner.metrics.suffix(5).reversed())
            if recents.isEmpty {
                Text("尚无报告。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(recents) { metric in
                        rawLineBlock(metric)
                    }
                }
                .padding(10)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .formBlock()
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

// MARK: - Chart card wrapper


// MARK: - Auto-discovery

/// One chart card, derived from a logical group of metric keys. The
/// grouping rules are static (preference rewards, KL, clipping, etc.)
/// because the trainers always emit those names — but which groups
/// actually render depends on which keys have non-empty data in
/// `runner.metrics`.
struct MetricCardGroup: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let series: [MultiLineChart.Series]

    static func compute(from metrics: [TrainingMetric]) -> [MetricCardGroup] {
        guard !metrics.isEmpty else { return [] }
        var groups: [MetricCardGroup] = []

        // Preference rewards (DPO/CPO/ORPO/PPO/Online-DPO/XPO)
        let pref = preferenceRewards(from: metrics)
        if !pref.isEmpty {
            groups.append(MetricCardGroup(
                id: "preference",
                title: "偏好奖励（Preference Rewards）",
                subtitle: "训练（实线）和验证（虚线）批次中，优选回答（chosen）与被拒绝回答（rejected）的奖励。",
                series: pref
            ))
        }

        // RLHF Reinforce: rewards + kl_penalty + advantages
        let rlhf = rlhfMetrics(from: metrics)
        if !rlhf.isEmpty {
            groups.append(MetricCardGroup(
                id: "rlhf",
                title: "RLHF",
                subtitle: "策略梯度训练循环中每个 step 的奖励、KL 惩罚和优势值。",
                series: rlhf
            ))
        }

        // GRPO reward distribution: total_rewards + grouped_rewards
        let dist = rewardDistribution(from: metrics)
        if !dist.isEmpty {
            groups.append(MetricCardGroup(
                id: "reward-dist",
                title: "奖励分布（Reward Distribution）",
                subtitle: "GRPO 每轮生成（rollout）中总奖励与各组奖励的均值和标准差。",
                series: dist
            ))
        }

        // KL divergence (GRPO standalone)
        if let klSeries = singleSeries(key: "kl", label: "KL", color: .teal, from: metrics) {
            groups.append(MetricCardGroup(
                id: "kl",
                title: "KL 散度（KL Divergence）",
                subtitle: "每个 step 中，当前策略与参考策略之间的 KL 散度。",
                series: [klSeries]
            ))
        }

        // PPO clipping
        let clipping = clippingRatios(from: metrics)
        if !clipping.isEmpty {
            groups.append(MetricCardGroup(
                id: "clipping",
                title: "PPO 裁剪（PPO Clipping）",
                subtitle: "触发下限裁剪、上限裁剪及任一裁剪的 tokens 占比。",
                series: clipping
            ))
        }

        // Generation tokens (GRPO)
        let gen = generation(from: metrics)
        if !gen.isEmpty {
            groups.append(MetricCardGroup(
                id: "generation",
                title: "生成（Generation）",
                subtitle: "每次生成（rollout）的 Token 数量，以及达到长度上限的比例。",
                series: gen
            ))
        }

        // Per-reward functions (GRPO)
        let perReward = perRewardFunctions(from: metrics)
        for group in perReward {
            groups.append(group)
        }

        // Throughput (it/s, tok/s) — always useful, render even with 1 point
        let throughput = throughput(from: metrics)
        if !throughput.isEmpty {
            groups.append(MetricCardGroup(
                id: "throughput",
                title: "吞吐量（Throughput）",
                subtitle: "训练器报告的每秒 iterations 与 tokens 数量。",
                series: throughput
            ))
        }

        return groups
    }

    // MARK: - Series builders

    private static func preferenceRewards(from metrics: [TrainingMetric]) -> [MultiLineChart.Series] {
        var series: [MultiLineChart.Series] = []
        if let s = singleSeries(key: "chosen_r", label: "训练：优选回答（Chosen (train)）", color: .green, from: metrics, isValidation: false) {
            series.append(s)
        }
        if let s = singleSeries(key: "rejected_r", label: "训练：被拒绝的回答（Rejected (train)）", color: .red, from: metrics, isValidation: false) {
            series.append(s)
        }
        if let s = singleSeries(key: "val_chosen_r", label: "验证：优选回答（Chosen (val)）", color: .green, from: metrics, isValidation: true) {
            series.append(s)
        }
        if let s = singleSeries(key: "val_rejected_r", label: "验证：被拒绝的回答（Rejected (val)）", color: .red, from: metrics, isValidation: true) {
            series.append(s)
        }
        return series
    }

    private static func rlhfMetrics(from metrics: [TrainingMetric]) -> [MultiLineChart.Series] {
        var series: [MultiLineChart.Series] = []
        if let s = singleSeries(key: "rewards", label: "奖励（Rewards）", color: .green, from: metrics) { series.append(s) }
        if let s = singleSeries(key: "kl_penalty", label: "KL 惩罚（KL Penalty）", color: .teal, from: metrics) { series.append(s) }
        if let s = singleSeries(key: "advantages", label: "优势值（Advantages）", color: .purple, from: metrics) { series.append(s) }
        return series
    }

    private static func rewardDistribution(from metrics: [TrainingMetric]) -> [MultiLineChart.Series] {
        var series: [MultiLineChart.Series] = []
        if let s = singleSeries(key: "total_rewards_mean", label: "总奖励均值（Total μ）", color: .green, from: metrics) { series.append(s) }
        if let s = singleSeries(key: "total_rewards_std", label: "总奖励标准差（Total σ）", color: .green.opacity(0.55), from: metrics) { series.append(s) }
        if let s = singleSeries(key: "grouped_rewards_mean", label: "组奖励均值（Group μ）", color: .orange, from: metrics) { series.append(s) }
        if let s = singleSeries(key: "grouped_rewards_std", label: "组奖励标准差（Group σ）", color: .orange.opacity(0.55), from: metrics) { series.append(s) }
        return series
    }

    private static func clippingRatios(from metrics: [TrainingMetric]) -> [MultiLineChart.Series] {
        var series: [MultiLineChart.Series] = []
        if let s = singleSeries(key: "clip_ratio_low", label: "下限裁剪（Low）", color: .blue, from: metrics) { series.append(s) }
        if let s = singleSeries(key: "clip_ratio_high", label: "上限裁剪（High）", color: .indigo, from: metrics) { series.append(s) }
        if let s = singleSeries(key: "clip_ratio_total", label: "总裁剪（Total）", color: .purple, from: metrics) { series.append(s) }
        return series
    }

    private static func generation(from metrics: [TrainingMetric]) -> [MultiLineChart.Series] {
        var series: [MultiLineChart.Series] = []
        if let s = singleSeries(key: "avg_generated_tokens", label: "平均 tokens（Avg tokens）", color: .purple, from: metrics) { series.append(s) }
        if let s = singleSeries(key: "min_generated_tokens", label: "最少 tokens（Min tokens）", color: .indigo, from: metrics) { series.append(s) }
        if let s = singleSeries(key: "max_generated_tokens", label: "最多 tokens（Max tokens）", color: .pink, from: metrics) { series.append(s) }
        if let s = singleSeries(key: "hit_max_tokens_ratio", label: "命中上限（Hit limit）", color: .orange, from: metrics) { series.append(s) }
        return series
    }

    private static func throughput(from metrics: [TrainingMetric]) -> [MultiLineChart.Series] {
        var series: [MultiLineChart.Series] = []
        if let s = singleSeries(key: "it_s", label: "it/s", color: .cyan, from: metrics) { series.append(s) }
        if let s = singleSeries(key: "tok_s", label: "tok/s", color: .mint, from: metrics) { series.append(s) }
        return series
    }

    /// Build a card per reward function defined in the GRPO config.
    /// Each function emits `reward_<name>_mean`, `..._std`, `..._coverage`.
    private static func perRewardFunctions(from metrics: [TrainingMetric]) -> [MetricCardGroup] {
        // Find every distinct reward-function name by scanning for
        // `reward_<name>_mean` keys. We never want to assume a fixed
        // list of reward functions — the user configures them.
        var names: [String] = []
        var seen: Set<String> = []
        for metric in metrics {
            for key in metric.values.keys {
                guard key.hasPrefix("reward_"), key.hasSuffix("_mean") else { continue }
                let middle = key
                    .dropFirst("reward_".count)
                    .dropLast("_mean".count)
                let name = String(middle)
                if !seen.contains(name) {
                    seen.insert(name)
                    names.append(name)
                }
            }
        }
        return names.map { name in
            var series: [MultiLineChart.Series] = []
            if let s = singleSeries(key: "reward_\(name)_mean", label: "均值（μ）", color: .green, from: metrics) { series.append(s) }
            if let s = singleSeries(key: "reward_\(name)_std", label: "标准差（σ）", color: .yellow, from: metrics) { series.append(s) }
            if let s = singleSeries(key: "reward_\(name)_coverage", label: "覆盖率（Coverage）", color: .blue, from: metrics) { series.append(s) }
            return MetricCardGroup(
                id: "reward-\(name)",
                title: "奖励（Reward）· \(humanise(name))",
                subtitle: "每项奖励在生成结果（rollout）中的均值、标准差和覆盖率。",
                series: series
            )
        }
    }

    // MARK: - Helpers

    /// Pull a single key out of the metrics array, dropping `nil`s. Returns
    /// `nil` if there are no values for the key, so callers can decide
    /// whether to include the resulting series in a card.
    private static func singleSeries(
        key: String,
        label: String,
        color: Color,
        from metrics: [TrainingMetric],
        isValidation: Bool = false
    ) -> MultiLineChart.Series? {
        // Walk once and pick up (value, step) pairs in order. Validation
        // series tend to lag training and skip samples, so a compactMap on
        // values alone loses the step mapping. The chart's hover overlay
        // shows "step N" from the i-th entry of `xSteps`.
        var values: [Double] = []
        var xSteps: [Int] = []
        values.reserveCapacity(metrics.count)
        xSteps.reserveCapacity(metrics.count)
        for metric in metrics {
            if let v = metric.values[key] {
                values.append(v)
                xSteps.append(metric.step)
            }
        }
        guard !values.isEmpty else { return nil }
        return MultiLineChart.Series(
            id: key,
            label: label,
            color: color,
            values: values,
            isDashed: isValidation,
            xSteps: xSteps
        )
    }

    private static func humanise(_ key: String) -> String {
        // `helpfulness_v2` → `Helpfulness V2`
        key.replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

// MARK: - Metrics table

struct MetricTableRow: Identifiable {
    let id: String
    let rawKey: String
    let displayName: String
    let isValidation: Bool
    let latest: Double
    let min: Double
    let max: Double
    let count: Int

    static func compute(from metrics: [TrainingMetric]) -> [MetricTableRow] {
        // Group values by key, keeping the order in which each key first
        // appeared. This gives a stable table layout.
        var order: [String] = []
        var buckets: [String: [Double]] = [:]
        for metric in metrics {
            for (key, value) in metric.values {
                if buckets[key] == nil {
                    order.append(key)
                    buckets[key] = []
                }
                buckets[key]?.append(value)
            }
        }
        return order.compactMap { key in
            guard let values = buckets[key], !values.isEmpty else { return nil }
            return MetricTableRow(
                id: key,
                rawKey: key,
                displayName: humanise(key),
                isValidation: key.hasPrefix("val_"),
                latest: values.last ?? 0,
                min: values.min() ?? 0,
                max: values.max() ?? 0,
                count: values.count
            )
        }
    }

    private static func humanise(_ key: String) -> String {
        // `chosen_r` → `Chosen R`, `kl_penalty` → `KL Penalty`,
        // `reward_helpfulness_mean` → `Helpfulness (mean)`.
        var working = key
        var suffix: String? = nil
        for s in ["_mean", "_std", "_coverage"] {
            if working.hasSuffix(s) {
                suffix = String(s.dropFirst())
                working = String(working.dropLast(s.count))
                break
            }
        }
        let core = working
            .replacingOccurrences(of: "_r", with: " R")
            .replacingOccurrences(of: "_s", with: "/s")
            .replacingOccurrences(of: "tok_s", with: "tok/s")
            .replacingOccurrences(of: "it_s", with: "it/s")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        if let suffix {
            return "\(core) (\(suffix))"
        }
        return core
    }
}
