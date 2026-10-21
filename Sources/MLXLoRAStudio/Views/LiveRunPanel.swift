import SwiftUI

struct LiveRunPanel: View {
    @Bindable var runner: PythonJobRunner
    /// When `true` we render a thin "rail" version of the panel: just the
    /// collapse/expand button and a live-status dot. The full terminal
    /// + status pill only appear when the panel is expanded. The binding
    /// is a `Bool` (not a `Set<Bool>`) so callers can drive it directly
    /// from a manual toggle, an auto-collapse rule, or both.
    var collapsed: Binding<Bool> = .constant(false)

    var body: some View {
        if collapsed.wrappedValue {
            collapsedRail
        } else {
            expandedContent
        }
    }

    /// Thin vertical rail. Shows the current run state (idle / running /
    /// paused) and a single button to expand the console back out. The
    /// button is the only interactive surface here, which keeps the rail
    /// from competing with the form on the left for clicks.
    private var collapsedRail: some View {
        VStack(spacing: 10) {
            Button {
                collapsed.wrappedValue = false
            } label: {
                Image(systemName: "rectangle.righthalf.inset.filled.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help("显示运行控制台")
            .accessibilityLabel("显示运行控制台（Show Run Console）")

            // Status dot at the top of the rail: green while a job is
            // running, secondary when idle. We use a small caption
            // "Run" / "Idle" below it so the user can tell at a glance
            // whether anything is happening, even when the terminal
            // is hidden.
            Circle()
                .fill(runner.isRunning ? .green : .secondary)
                .frame(width: 10, height: 10)
                .scaleEffect(runner.isRunning ? 1.08 : 0.9)
                .animation(.easeInOut(duration: 0.24), value: runner.isRunning)

            Text(runner.isRunning ? (runner.isPaused ? "已暂停" : "运行中") : "空闲")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 14)
        .frame(maxHeight: .infinity)
        .frame(width: 56)
        .liquidGlass(cornerRadius: 18)
        .padding(16)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(runner.isRunning ? "实时运行" : "运行控制台")
                        .font(.title3.bold())
                    Text(StudioL10n.display(runner.currentCommand.isEmpty ? "就绪" : runner.currentCommand))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    collapsed.wrappedValue = true
                } label: {
                    Image(systemName: "rectangle.lefthalf.inset.filled.arrow.left")
                }
                .buttonStyle(.plain)
                .help("隐藏运行控制台")
                .accessibilityLabel("隐藏运行控制台（Hide Run Console）")

                Button {
                    runner.clearTerminal()
                } label: {
                    Label("清空", systemImage: "eraser")
                }
                .disabled(runner.logLines.isEmpty)

                Circle()
                    .fill(runner.isRunning ? .green : .secondary)
                    .frame(width: 10, height: 10)
                    .scaleEffect(runner.isRunning ? 1.08 : 0.9)
                    .animation(.easeInOut(duration: 0.24), value: runner.isRunning)
            }

            // Compact status pill — just the latest step / loss / memory,
            // the deep metric view now lives in the Live Metrics page.
            StatusPill(metric: runner.metrics.last)
                .padding(.horizontal, 4)

            // Terminal window: log lines auto-scroll to the bottom. We use
            // `defaultScrollAnchor(.bottom)` so SwiftUI naturally anchors new
            // content to the bottom as it arrives, and an explicit scrollTo
            // on each batch to jump past the lazy-stack's "unlaid out" gap.
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(runner.logLines.enumerated()), id: \.offset) { index, line in
                            Text(ANSIRenderer.attributed(StudioL10n.log(line)))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .foregroundStyle(line.contains("[Studio]") ? .secondary : .primary)
                                .id(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .liquidGlass(cornerRadius: 10)
                .padding(8)
                .defaultScrollAnchor(.bottom)
                .animation(.easeInOut(duration: 0.18), value: runner.logLines.count)
                .onChange(of: runner.logLines.count) { _, count in
                    guard count > 1 else { return }
                    // Defer to the next runloop so newly-appended rows have
                    // time to be measured — otherwise the LazyVStack's unlaid
                    // cells swallow the scroll.
                    DispatchQueue.main.async {
                        proxy.scrollTo(count - 1, anchor: .bottom)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if runner.logLines.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "terminal")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(runner.isRunning ? "等待任务输出" : "尚无运行日志")
                            .font(.headline)
                        Text(runner.isRunning
                             ? "任务已启动，正在等待第一条日志。"
                             : "点击右上角“运行”后，这里会显示本次任务的输出。")
                        Text("终端或其他应用启动的 Python 任务不会出现在这里。")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(24)
                    .frame(maxWidth: 400)
                    .allowsHitTesting(false)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .liquidGlass(cornerRadius: 18)
        .padding(16)
        .animation(.easeInOut(duration: 0.22), value: runner.isPaused)
        .animation(.easeInOut(duration: 0.22), value: runner.isRunning)
    }
}

/// Compact summary of the latest metric, shown above the terminal.
/// Shows the same five signals as the Live Metrics summary row —
/// Step, Loss, Speed, Tokens/s, Memory, LR — so the small window is
/// self-sufficient for a quick glance. For richer visualisations,
/// the user switches to the Live Metrics page in the sidebar.
private struct StatusPill: View {
    let metric: TrainingMetric?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                metricTiles
            }
            .fixedSize(horizontal: true, vertical: false)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3),
                      alignment: .leading, spacing: 8) {
                metricTiles
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private var metricTiles: some View {
        tile(title: "Step", value: stepValue)
        tile(title: "Loss", value: lossValue)
        tile(title: "Speed", value: speedValue)
        tile(title: "Tokens/s", value: tokensPerSecValue)
        tile(title: "内存", value: memoryValue)
        tile(title: "LR", value: lrValue)
    }

    private var stepValue: String { metric.map { "Iter \($0.step)" } ?? "—" }
    private var lossValue: String { metric?.loss.map { String(format: "%.3f", $0) } ?? "—" }
    private var memoryValue: String { metric?.memoryGB.map { String(format: "%.2f GB", $0) } ?? "—" }
    private var lrValue: String { metric?.learningRate.map { String(format: "%.2e", $0) } ?? "—" }
    private var speedValue: String {
        metric?.values["it_s"].map { String(format: "%.2f it/s", $0) } ?? "—"
    }
    private var tokensPerSecValue: String {
        metric?.values["tok_s"].map { String(format: "%.0f", $0) } ?? "—"
    }

    private func tile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum ANSIRenderer {
    struct Style {
        var color: Color?
        var isBold = false
    }

    static func attributed(_ raw: String) -> AttributedString {
        var result = AttributedString()
        var style = Style()
        var buffer = ""
        var index = raw.startIndex

        func flush() {
            guard !buffer.isEmpty else { return }
            var chunk = AttributedString(buffer)
            if let color = style.color {
                chunk.foregroundColor = color
            }
            if style.isBold {
                chunk.inlinePresentationIntent = .stronglyEmphasized
            }
            result += chunk
            buffer.removeAll(keepingCapacity: true)
        }

        while index < raw.endIndex {
            if raw[index] == "\u{001B}",
               let open = raw.index(index, offsetBy: 1, limitedBy: raw.endIndex),
               open < raw.endIndex,
               raw[open] == "[",
               let close = raw[open...].firstIndex(of: "m") {
                flush()
                let codesText = raw[raw.index(after: open)..<close]
                apply(codesText: String(codesText), style: &style)
                index = raw.index(after: close)
            } else {
                buffer.append(raw[index])
                index = raw.index(after: index)
            }
        }
        flush()
        return result
    }

    private static func apply(codesText: String, style: inout Style) {
        let codes = codesText
            .split(separator: ";", omittingEmptySubsequences: false)
            .compactMap { Int($0.isEmpty ? "0" : $0) }

        for code in codes {
            switch code {
            case 0:
                style = Style()
            case 1:
                style.isBold = true
            case 22:
                style.isBold = false
            case 30, 90:
                style.color = .secondary
            case 31, 91:
                style.color = .red
            case 32, 92:
                style.color = .green
            case 33, 93:
                style.color = .yellow
            case 34, 94:
                style.color = .blue
            case 35, 95:
                style.color = .purple
            case 36, 96:
                style.color = .cyan
            case 37, 97:
                style.color = .primary
            case 39:
                style.color = nil
            default:
                break
            }
        }
    }
}
