import SwiftUI

struct SettingsView: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Python") {
                    PythonPickerSection(store: store)
                    TextField("mlx-lm-lora 包路径", text: $store.packagePath)
                    TextField("工作目录", text: $store.workingDirectory)
                }

                Section("输出") {
                    TextField("运行输出目录", text: $store.outputRoot)
                    Text("每个任务都会在此创建独立目录。默认位置为 ~/.mlxlorastudio/runs，也可以指定其他目录。在训练或合成数据页将单次运行的目录名留空，即可自动生成。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Hugging Face") {
                    HuggingFaceTokenField(store: store)
                    Text("token 保存在 macOS Keychain 中。运行器会将其作为 `HF_TOKEN` 和 `HUGGING_FACE_HUB_TOKEN` 注入每个 Python 任务，使 gated 或 private repo 的加载方式与执行 `huggingface-cli login` 后一致。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("通知") {
                    Toggle("任务结束时通知", isOn: completionNotificationsBinding)
                        .disabled(store.isUpdatingCompletionNotifications)
                    Text("训练、合成数据生成或 Hugging Face 上传结束时显示 macOS 通知。首次开启时，macOS 可能要求授予通知权限。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if !store.completionNotificationsStatus.isEmpty {
                        Text(StudioL10n.display(store.completionNotificationsStatus))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section("资源保护（Resource Guard）") {
                    HStack {
                        Text("内存上限")
                        Spacer()
                        HStack(alignment: .center, spacing: 6) {
                            TextField("", value: $store.resourceGuardMemoryPercent, format: .number)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 64)
                                .labelsHidden()
                            Text("%")
                                .foregroundStyle(.secondary)
                                .frame(width: 16, alignment: .leading)
                            Stepper("内存上限", value: $store.resourceGuardMemoryPercent, in: 10...98, step: 1)
                                .labelsHidden()
                        }
                    }
                    Text("训练运行会在峰值内存达到系统 RAM 的此占比前停止。降低此值可留出更多内存余量；默认值为 78%。")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Divider()

                    HStack {
                        Text("iGPU 锁定内存上限（wired limit）")
                        Spacer()
                        HStack(alignment: .center, spacing: 6) {
                            TextField("", value: $store.iogpuWiredLimitMB, format: .number)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 96)
                                .labelsHidden()
                            Text("MB")
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .leading)
                            Stepper("iGPU 锁定内存上限（wired limit）", value: $store.iogpuWiredLimitMB, in: 1_024...1_048_576, step: 1_024)
                                .labelsHidden()
                        }
                    }
                    HStack {
                        Text("通过 macOS 管理员授权提示执行 `sudo sysctl iogpu.wired_limit_mb=\(store.iogpuWiredLimitMB)`。此处默认值为 21504 MB。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            Task { await store.applyIOGPUWiredLimit() }
                        } label: {
                            Label(store.isApplyingIOGPUWiredLimit ? "正在应用" : "应用限制", systemImage: "lock.shield")
                        }
                        .disabled(store.isApplyingIOGPUWiredLimit)
                    }
                    if !store.iogpuWiredLimitStatus.isEmpty {
                        Text(StudioL10n.display(store.iogpuWiredLimitStatus))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Section("使用引导") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("产品导览")
                                .font(.headline)
                            Text("重新显示首次使用时的界面引导。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            store.replayOnboarding()
                        } label: {
                            Label("重新查看引导", systemImage: "sparkles")
                        }
                    }
                }

                Section("包更新") {
                    LabeledContent("内置后端") {
                        Text("mlx-lm-lora 3.1.2")
                            .foregroundStyle(.secondary)
                    }
                    Text("这是每次构建应用时复制进来的后端。3.1.2 版本为 recurrent 和 hybrid SSM model 添加了自动 memory-safe training 支持，无需额外配置。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Python 后端")
                                .font(.headline)
                            Text("更新或重新安装 MLX runtime 包，然后安装此版本应用固定使用的本地 mlx-lm-lora 及其依赖，其中包括 OpenAI-compatible API 支持。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Button {
                                Task { await store.updatePackages() }
                            } label: {
                                Label("更新", systemImage: "arrow.down.circle")
                            }
                            Button {
                                Task { await store.reinstallPackages() }
                            } label: {
                                Label(store.packageRunner.isRunning ? "运行中" : "重新安装", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .help("在所选 Python 环境中强制重新安装 MLX runtime 包和本地 mlx-lm-lora 所需依赖。")
                        }
                        .disabled(store.packageRunner.isRunning)
                    }

                    if !store.packageRunner.logLines.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(Array(store.packageRunner.logLines.suffix(80).enumerated()), id: \.offset) { _, line in
                                    Text(StudioL10n.log(ANSIText.clean(line)))
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                        }
                        .frame(height: 160)
                    }
                }

                Section("当前命令") {
                    Text(StudioL10n.display(store.packageRunner.currentCommand.isEmpty ? "尚未执行包管理命令。" : store.packageRunner.currentCommand))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlass(cornerRadius: 18)
        .padding(16)
    }

    private var completionNotificationsBinding: Binding<Bool> {
        Binding(
            get: { store.completionNotificationsEnabled },
            set: { enabled in
                Task { await store.setCompletionNotificationsEnabled(enabled) }
            }
        )
    }
}

/// Password-style field for the Hugging Face personal access token.
///
/// The field does NOT keep the secret in its own state. Instead, it
/// shows a placeholder ("••• set" when a token is already in the
/// Keychain, "Paste token…" when not) and only switches into a real
/// text editor once the user clicks "Edit" — at which point the new
/// value is committed to the Keychain on commit and cleared from
/// memory. This is the same UX pattern Apple uses for saved Wi-Fi
/// passwords in the network settings.
private struct HuggingFaceTokenField: View {
    @Bindable var store: AppStore

    /// `true` while the user is in the middle of typing a new token.
    /// When `false`, the field renders the placeholder, never the
    /// real stored value.
    @State private var isEditing = false
    @State private var draft = ""

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill")
                .foregroundStyle(.secondary)
            Group {
                if isEditing {
                    SecureField("hf_…", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(commit)
                } else {
                    // The placeholder is the only thing visible when
                    // not editing. We intentionally never read the
                    // token back from the Keychain into the field —
                    // that would defeat the point of a secret field.
                    Text(placeholder)
                        .foregroundStyle(store.huggingFaceTokenIsSet ? .primary : .secondary)
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
                Button(store.huggingFaceTokenIsSet ? "替换…" : "设置…") {
                    draft = ""
                    isEditing = true
                }
                if store.huggingFaceTokenIsSet {
                    Button {
                        store.clearHuggingFaceToken()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("移除已保存的 token")
                }
            }
        }
    }

    private var placeholder: String {
        store.huggingFaceTokenIsSet
            ? "••• token 已保存在 Keychain 中"
            : "未设置 token — gated / private HF 资源将无法加载"
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        store.setHuggingFaceToken(trimmed)
        draft = ""
        isEditing = false
    }
}
