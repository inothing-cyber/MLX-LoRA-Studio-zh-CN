import SwiftUI

@MainActor
struct OnboardingTourView: View {
    @Bindable var store: AppStore
    @State private var stepIndex = 0
    @State private var pulse = false

    private let steps = OnboardingStep.all

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            GeometryReader { proxy in
                spotlightLayer(in: proxy.size)

                VStack {
                    Spacer()
                    tourCard
                        .frame(width: min(560, proxy.size.width - 40))
                        .padding(.bottom, 34)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            pulse = true
            store.columnVisibility = .all
            store.selection = currentStep.section
        }
        .onChange(of: stepIndex) { _, _ in
            withAnimation(.easeInOut(duration: 0.28)) {
                store.selection = currentStep.section
            }
        }
    }

    private var currentStep: OnboardingStep {
        steps[stepIndex]
    }

    private var isLastStep: Bool {
        stepIndex == steps.count - 1
    }

    private var tourCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: currentStep.symbol)
                    .font(.title2.weight(.semibold))
                    .frame(width: 46, height: 46)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(currentStep.title)
                        .font(.title2.bold())
                    Text(currentStep.message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                Button {
                    store.completeOnboarding()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("跳过引导")
            }

            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == stepIndex ? Color.accentColor : Color.secondary.opacity(0.28))
                        .frame(width: index == stepIndex ? 28 : 8, height: 8)
                        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: stepIndex)
                }
            }
            .accessibilityHidden(true)

            HStack {
                Button("跳过引导") {
                    store.completeOnboarding()
                }

                Spacer()

                Button("上一步") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        stepIndex = max(stepIndex - 1, 0)
                    }
                }
                .disabled(stepIndex == 0)

                Button(isLastStep ? "完成" : "下一步") {
                    advance()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .liquidGlass(cornerRadius: 18)
        .shadow(color: .black.opacity(0.18), radius: 22, y: 12)
    }

    @ViewBuilder
    private func spotlightLayer(in size: CGSize) -> some View {
        let rect = currentStep.rect(size)

        RoundedRectangle(cornerRadius: currentStep.cornerRadius, style: .continuous)
            .strokeBorder(Color.accentColor.opacity(0.82), lineWidth: 2)
            .background(
                RoundedRectangle(cornerRadius: currentStep.cornerRadius, style: .continuous)
                    .fill(Color.accentColor.opacity(0.10))
            )
            .shadow(color: Color.accentColor.opacity(pulse ? 0.34 : 0.12), radius: pulse ? 28 : 10)
            .scaleEffect(pulse ? 1.012 : 0.992)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .animation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true), value: pulse)
            .animation(.spring(response: 0.42, dampingFraction: 0.84), value: stepIndex)
            .allowsHitTesting(false)
    }

    private func advance() {
        if isLastStep {
            store.completeOnboarding()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                stepIndex += 1
            }
        }
    }
}

private struct OnboardingStep {
    let title: String
    let message: String
    let symbol: String
    let section: SidebarSection
    let cornerRadius: CGFloat
    let rect: (CGSize) -> CGRect

    @MainActor static let all: [OnboardingStep] = [
        OnboardingStep(
            title: "选择工作区",
            message: "通过侧栏可以训练 adapter、查看 metrics、生成 dataset、上传到 Hugging Face、阅读指南，以及重新查看已保存的运行记录。",
            symbol: "sidebar.left",
            section: .train,
            cornerRadius: 18,
            rect: { size in
                CGRect(x: 10, y: 10, width: min(270, size.width * 0.34), height: max(size.height - 20, 0))
            }
        ),
        OnboardingStep(
            title: "配置训练",
            message: "从训练页开始选择 model、dataset、LoRA 设置和算法，点击工具栏中的运行按钮即可启动所选任务。",
            symbol: "cpu",
            section: .train,
            cornerRadius: 18,
            rect: { size in
                let sidebarWidth = min(280, size.width * 0.34)
                return CGRect(x: sidebarWidth + 28, y: 72, width: max(size.width - sidebarWidth - 56, 240), height: max(size.height - 170, 220))
            }
        ),
        OnboardingStep(
            title: "实时观察运行",
            message: "任务运行时，实时指标页会将训练日志转换为 loss、reward、KL 和 learning-rate 图表。",
            symbol: "chart.line.uptrend.xyaxis",
            section: .metrics,
            cornerRadius: 18,
            rect: { size in
                let sidebarWidth = min(280, size.width * 0.34)
                return CGRect(x: sidebarWidth + 34, y: 82, width: max(size.width - sidebarWidth - 68, 240), height: max(size.height - 190, 220))
            }
        ),
        OnboardingStep(
            title: "需要时创建数据",
            message: "运行记录页会整理本地输出，便于查看设置、比较 metrics，或稍后恢复训练。",
            symbol: "chart.xyaxis.line",
            section: .runs,
            cornerRadius: 18,
            rect: { size in
                let sidebarWidth = min(280, size.width * 0.34)
                return CGRect(x: sidebarWidth + 34, y: 82, width: max(size.width - sidebarWidth - 68, 240), height: max(size.height - 190, 220))
            }
        ),
        OnboardingStep(
            title: "设置工作室",
            message: "打开设置，管理 Python 环境、输出目录、Hugging Face token、后端包更新、通知与资源限制。",
            symbol: "gearshape",
            section: .about,
            cornerRadius: 14,
            rect: { size in
                CGRect(x: max(size.width - 260, 20), y: 18, width: min(220, size.width - 40), height: 58)
            }
        )
    ]
}
