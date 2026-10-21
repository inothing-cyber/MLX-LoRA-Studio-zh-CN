import SwiftUI
import AppKit

/// A combo-box-style input for an HF model or dataset. The user can:
///   - Type a value directly into the text field (an arbitrary HF id
///     or a local path is accepted).
///   - Click the dropdown chevron to pick from a menu of:
///       • all assets already in the local HF cache, sorted most
///         recently used first,
///       • the user-typed custom list (persisted to UserDefaults),
///       • the bundled defaults for the current training mode,
///       • two "Add…" actions: one for a new HF repo (with a small
///         text-input sheet) and one for a local filesystem path
///         (which opens an `NSOpenPanel`).
///
/// The picker binds directly to the string the trainer reads, so
/// picking a cached model and then clicking *Start* on the live run
/// panel works without any intermediate copy step.
struct HFAssetPicker: View {
    @Binding var text: String
    let kind: HFCachedAsset.Kind
    let placeholder: String
    /// A short caption shown under the text field (e.g. "Local cache:
    /// 12 models · 31 datasets"). Set by the parent so the picker does
    /// not have to know about the store.
    var footer: String? = nil

    @Environment(AppStore.self) private var store

    @State private var showingAddHFSheet = false
    @State private var newHFInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: kind == .model ? "cpu" : "tray")
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                Menu {
                    menuContent
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
                    Task {
                        await store.refreshHFCache()
                        if kind == .dataset {
                            await store.refreshLocalRunOutputs()
                        }
                    }
                } label: {
                    if store.isScanningHFCache {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .help("重新扫描本地 Hugging Face cache")
            }
            if let footer {
                HStack(spacing: 6) {
                    Text(footer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    // Tiny "HF key set" indicator next to the cache
                    // footer. If a token is stored, gated / private
                    // repos will load; if not, the indicator dims
                    // and a help-tip explains how to add one. This
                    // keeps the user oriented at the moment they
                    // paste a gated model id and get a 401.
                    if store.huggingFaceTokenIsSet {
                        Label("已设置 HF key", systemImage: "key.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .help("Hugging Face token 已保存在 Keychain 中，访问 gated 或 private repo 时会自动进行身份验证。")
                    } else {
                        Label("未设置 HF key", systemImage: "key")
                            .labelStyle(.titleAndIcon)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .help("在设置 → Hugging Face 中添加 token，以加载 gated 或 private repo。")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddHFSheet) {
            AddHFAssetSheet(
                kind: kind,
                initial: newHFInput,
                onCommit: { id in
                    let clean = id.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !clean.isEmpty else { return }
                    store.addCustomHFAsset(clean, kind: kind)
                    text = clean.contains("/")
                        ? clean
                        : clean.replacingOccurrences(of: "--", with: "/")
                    newHFInput = ""
                    showingAddHFSheet = false
                },
                onCancel: {
                    newHFInput = ""
                    showingAddHFSheet = false
                },
            )
        }
    }

    // MARK: Menu

    @ViewBuilder
    private var menuContent: some View {
        let cached = kind == .model ? store.cachedModels : store.cachedDatasets
        let custom = kind == .model ? store.customModelPaths : store.customDatasetPaths
        let syntheticOutputs = store.syntheticRunOutputs

        Section("本地 HF cache（\(cached.count)）") {
            if cached.isEmpty {
                Text("尚未下载任何内容").foregroundStyle(.secondary)
            } else {
                ForEach(cached) { asset in
                    Button {
                        text = asset.hfID
                    } label: {
                        Label(asset.hfID, systemImage: kind == .model ? "cpu" : "tray")
                    }
                }
            }
        }

        if kind == .dataset {
            Section("合成数据运行记录（\(syntheticOutputs.count)）") {
                if syntheticOutputs.isEmpty {
                    Text("尚无 generated-data 目录").foregroundStyle(.secondary)
                } else {
                    ForEach(syntheticOutputs) { output in
                        Button {
                            text = output.path
                        } label: {
                            Label(output.name, systemImage: "sparkles")
                        }
                    }
                }
            }
        }

        if !custom.isEmpty {
            Section("自定义路径（\(custom.count)）") {
                ForEach(custom, id: \.self) { path in
                    Button {
                        text = path
                    } label: {
                        HStack {
                            Label(path, systemImage: "bookmark")
                            Spacer()
                            Button {
                                store.removeCustomPath(path, kind: kind)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }

        Section {
            Button {
                newHFInput = ""
                showingAddHFSheet = true
            } label: {
                Label("添加 HF repo…", systemImage: "plus.circle")
            }
            Button { pickLocalPathWithPanel() } label: {
                Label("浏览本地路径…", systemImage: "folder.badge.plus")
            }
        }
    }

    // MARK: Local path picker

    private func pickLocalPathWithPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = (kind == .dataset)
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = kind == .model
            ? "选择本地 model 目录（包含 config.json 的目录）。"
            : "选择本地 dataset 目录或文件。"
        panel.prompt = "使用此路径"
        if panel.runModal() == .OK, let url = panel.url {
            store.addCustomLocalPath(url.path, kind: kind)
            text = url.path
        }
    }
}

// MARK: - "Add HF repo…" sheet

private struct AddHFAssetSheet: View {
    let kind: HFCachedAsset.Kind
    @State var initial: String
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(kind == .model ? "添加 Hugging Face model" : "添加 Hugging Face dataset")
                .font(.headline)
            Text("粘贴 huggingface.co 上的 repo id，支持 `owner/name` 和 `owner--name` 两种写法。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField(kind == .model ? "owner/model-name" : "owner/dataset-name", text: $initial)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 360)
            HStack {
                Spacer()
                Button("取消", role: .cancel) { onCancel() }
                Button("添加") {
                    onCommit(initial)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(initial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 400)
    }
}
