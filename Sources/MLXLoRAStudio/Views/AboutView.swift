import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeaderView(
                    title: "关于",
                    subtitle: "作者、引用方式，以及这个应用诞生的原因。",
                    symbol: "info.circle"
                )

                VStack(alignment: .leading, spacing: 16) {
                    Text("MLX LoRA Studio 是一款原生桌面应用，可在 Apple silicon 上通过 LoRA、DoRA、supervised fine-tuning、preference optimization 和 reinforcement-style training loops 对语言模型进行 fine-tuning，并实时监控运行。")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("我开发它，是为了让 MLX fine-tuning 工作流从一堆脚本变成专注的工作室：选择 model 和数据，调整关键参数，启动训练并观察运行，同时保留底层命令行的透明性。")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .formBlock()

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("如何引用本项目")
                    
                    Text("如果你在项目中使用本应用或其训练工作流，请引用以下内容：")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 8)
                    
                    BibTeXEntry(
                        key: "mlx2023",
                        type: "software",
                        fields: [
                            ("author", "Awni Hannun and Jagrit Digani and Angelos Katharopoulos and Ronan Collobert"),
                            ("title", "{MLX}: Efficient and flexible machine learning on Apple silicon"),
                            ("url", "https://github.com/ml-explore"),
                            ("version", "0.0"),
                            ("year", "2023")
                        ]
                    )
                    
                    BibTeXEntry(
                        key: "gulmez2025mlxlmlora",
                        type: "software",
                        fields: [
                            ("author", "Gökdeniz Gülmez"),
                            ("title", "{MLX-LM-LoRA}: Train LLMs on Apple silicon with MLX and the Hugging Face Hub"),
                            ("url", "https://github.com/Goekdeniz-Guelmez/mlx-lm-lora"),
                            ("version", "0.1.0"),
                            ("year", "2025")
                        ]
                    )
                    
                    BibTeXEntry(
                        key: "gulmez2026mlxlorastudio",
                        type: "software",
                        fields: [
                            ("author", "Gökdeniz Gülmez"),
                            ("title", "{MLX-LoRA-Studio}: A native Mac App for LLM fine-tuning on Apple Silicon — fully on-device, fully open source."),
                            ("url", "https://github.com/Goekdeniz-Guelmez/MLX-LoRA-Studio.git"),
                            ("version", "2.0.0"),
                            ("year", "2026")
                        ]
                    )
                }
                .formBlock()

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("支持本项目与作者")
                    
                    Link(destination: URL(string: "https://github.com/sponsors/Goekdeniz-Guelmez")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .font(.title3)
                                .foregroundStyle(.pink)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("在 GitHub 上赞助")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("支持 MLX LoRA Studio 的开发")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.forward")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.15), Color.purple.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.pink.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .formBlock()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlass(cornerRadius: 18)
        .padding(16)
        .navigationTitle("关于")
    }
}

private struct BibTeXEntry: View {
    let key: String
    let type: String
    let fields: [(String, String)]
    
    @State private var showCopied = false
    
    private var bibtexString: String {
        var result = "@\(type){\(key),\n"
        for field in fields {
            result += "  \(field.0) = {\(field.1)},\n"
        }
        result += "}"
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.callout)
                    .foregroundStyle(.tint)
                
                Text("@\(type){\(key),")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bibtexString, forType: .string)
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                        Text(showCopied ? "已复制" : "复制")
                            .font(.caption)
                    }
                    .foregroundStyle(showCopied ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                ForEach(fields, id: \.0) { field in
                    HStack(alignment: .top, spacing: 0) {
                        Text("  \(field.0)")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Text(" = ")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        
                        Text("{\(field.1)}")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.primary)
                        
                        Text(",")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Text("}")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .textSelection(.enabled)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
