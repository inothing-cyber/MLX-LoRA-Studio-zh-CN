import AppKit
import SwiftUI

struct HFUploadView: View {
    @Bindable var store: AppStore
    @State private var manualConsoleCollapsed: Bool? = nil

    var body: some View {
        GeometryReader { proxy in
            let available = proxy.size.width
            let shouldAutoCollapse = available < 900
            let isCollapsed = effectiveCollapsed(shouldAutoCollapse: shouldAutoCollapse)
            let settingsWidth = available * 0.62
            let consoleWidth = available - settingsWidth

            HSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HeaderView(
                            title: "上传到 HF",
                            subtitle: store.huggingFaceTokenIsSet ? "HF token 已就绪" : "请先在设置中添加 HF token",
                            symbol: "arrow.up.circle"
                        )

                        UploadActionStrip(store: store)
                        ModelUploadSection(store: store)
                        SyntheticDatasetUploadSection(store: store)
                        HubSettingsSection(store: store)
                    }
                    .padding(24)
                }
                .layoutPriority(1)
                .frame(
                    minWidth: 360,
                    idealWidth: isCollapsed ? 620 : settingsWidth,
                    maxWidth: isCollapsed ? .infinity : settingsWidth
                )
                .uploadSettingsPane(cornerRadius: 18)
                .padding(16)

                LiveRunPanel(
                    runner: store.hfUploadRunner,
                    collapsed: Binding(
                        get: { isCollapsed },
                        set: { manualConsoleCollapsed = $0 }
                    )
                )
                .frame(
                    minWidth: isCollapsed ? 56 : 260,
                    idealWidth: isCollapsed ? 56 : consoleWidth,
                    maxWidth: isCollapsed ? 56 : consoleWidth
                )
            }
        }
        .navigationTitle("上传到 HF")
        .task {
            await store.refreshLocalRunOutputs()
        }
    }

    private func effectiveCollapsed(shouldAutoCollapse: Bool) -> Bool {
        if let manual = manualConsoleCollapsed { return manual }
        return shouldAutoCollapse
    }
}

private struct UploadActionStrip: View {
    @Bindable var store: AppStore

    private var isRunning: Bool { store.hfUploadRunner.isRunning }
    private var canUploadModel: Bool {
        !store.hfUpload.localModelPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !store.hfUpload.modelRepo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !(store.hfUpload.modelUploadKind == .adaptersOnly && store.hfUploadAdaptersUnavailable)
    }
    private var canUploadDataset: Bool {
        !store.hfUpload.localDatasetPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !store.hfUpload.datasetRepo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isRunning {
                Button {
                    store.hfUploadRunner.stop()
                } label: {
                    Label("取消上传", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            } else {
                HStack(spacing: 12) {
                    Button {
                        Task { await store.startHFUpload(target: .model) }
                    } label: {
                        Label("上传模型", systemImage: "cpu.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canUploadModel)

                    Button {
                        Task { await store.startHFUpload(target: .dataset) }
                    } label: {
                        Label("上传数据集", systemImage: "tray.and.arrow.up.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canUploadDataset)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            HStack(alignment: .top, spacing: 12) {
                InfoPill(text: "模型与数据集分别上传", symbol: "arrow.triangle.branch")
                if !store.hfUploadRunner.lastRunFolder.isEmpty {
                    InfoPill(text: "上次上传：\(store.hfUploadRunner.lastRunFolder)", symbol: "folder")
                }
            }
        }
        .formBlock()
    }
}

private struct ModelUploadSection: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("模型权重（Model Weights）")
            ModelUploadKindSegmentedControl(
                selection: $store.hfUpload.modelUploadKind,
                adaptersUnavailable: store.hfUploadAdaptersUnavailable
            )
            .onChange(of: store.hfUpload.modelUploadKind) {
                store.normalizeHFUploadKindForSelectedModel()
            }

            LocalRunPicker(
                title: "训练记录",
                placeholder: "选择训练记录",
                selection: $store.hfUpload.localModelPath,
                outputs: store.trainingRunOutputs
            )
            .onChange(of: store.hfUpload.localModelPath) {
                store.normalizeHFUploadKindForSelectedModel()
            }
            CustomFolderField(title: "自定义 model 目录", path: $store.hfUpload.localModelPath)
            TextField("目标 model repo，例如 username/model-name", text: $store.hfUpload.modelRepo)

            Text(modelHint)
                .foregroundStyle(.secondary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .formBlock()
    }

    private var modelHint: String {
        if store.hfUploadAdaptersUnavailable {
            return "本次运行没有 adapter checkpoint 文件，请改为上传 merged model weights。"
        }
        return switch store.hfUpload.modelUploadKind {
        case .adaptersOnly:
            "上传 adapter 文件、adapter config、已有的 tokenizer/config 元数据，以及生成的 README.md。"
        case .mergedWeights:
            "上传所选 model 的完整目录，包括 merged model weights、tokenizer/config 文件和 README.md。"
        }
    }
}

private struct ModelUploadKindSegmentedControl: NSViewRepresentable {
    @Binding var selection: HFModelUploadKind
    let adaptersUnavailable: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: HFModelUploadKind.allCases.map(\.title),
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.selectionChanged(_:))
        )
        control.segmentStyle = .rounded
        control.controlSize = .regular
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.selection = $selection
        control.segmentCount = HFModelUploadKind.allCases.count

        for (index, kind) in HFModelUploadKind.allCases.enumerated() {
            control.setLabel(kind.title, forSegment: index)
            control.setWidth(0, forSegment: index)
            control.setEnabled(!(kind == .adaptersOnly && adaptersUnavailable), forSegment: index)
        }

        control.selectedSegment = HFModelUploadKind.allCases.firstIndex(of: selection) ?? 0
    }

    final class Coordinator: NSObject {
        var selection: Binding<HFModelUploadKind>

        init(selection: Binding<HFModelUploadKind>) {
            self.selection = selection
        }

        @MainActor @objc func selectionChanged(_ sender: NSSegmentedControl) {
            let index = sender.selectedSegment
            guard HFModelUploadKind.allCases.indices.contains(index) else { return }
            selection.wrappedValue = HFModelUploadKind.allCases[index]
        }
    }
}

private struct SyntheticDatasetUploadSection: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("合成数据集（Synthetic Dataset）")
            LocalRunPicker(
                title: "合成数据运行记录",
                placeholder: "选择合成数据运行记录",
                selection: $store.hfUpload.localDatasetPath,
                outputs: store.syntheticRunOutputs
            )
            CustomFolderField(title: "自定义 dataset 目录", path: $store.hfUpload.localDatasetPath)
            TextField("目标 dataset repo，例如 username/dataset-name", text: $store.hfUpload.datasetRepo)
            Text("创建或更新 Hugging Face dataset repo，并写入 dataset README.md。")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .formBlock()
    }
}

private struct HubSettingsSection: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Hub 设置")
            ToggleRow("将新建 repo 设为 private", isOn: $store.hfUpload.privateRepo)
            TextField("Commit message", text: $store.hfUpload.commitMessage)
        }
        .formBlock()
    }
}

private struct UploadSettingsPaneModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
            }
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
    func uploadSettingsPane(cornerRadius: CGFloat) -> some View {
        modifier(UploadSettingsPaneModifier(cornerRadius: cornerRadius))
    }
}

private struct LocalRunPicker: View {
    let title: String
    let placeholder: String
    @Binding var selection: String
    let outputs: [LocalRunOutput]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(placeholder, selection: $selection) {
                Text(placeholder).tag("")
                ForEach(outputs) { output in
                    Text(output.name).tag(output.path)
                }
                if !selection.isEmpty && !outputs.contains(where: { $0.path == selection }) {
                    Text("自定义：\(URL(fileURLWithPath: selection).lastPathComponent)").tag(selection)
                }
            }
            .pickerStyle(.menu)
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

private struct CustomFolderField: View {
    let title: String
    @Binding var path: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            TextField(title, text: $path)
            Button {
                pickFolder()
            } label: {
                Label("浏览", systemImage: "folder")
            }
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}
