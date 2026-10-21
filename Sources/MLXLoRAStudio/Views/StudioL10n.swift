import Foundation

// Generated presentation-only translations. Runner data, logs and protocol values stay original.
enum StudioL10n {
    private struct Rule {
        let prefix: String
        let expression: NSRegularExpression
        let parts: [String]
        let captures: [Int]
    }
    private static let exact: [String: String] = [
        "A job is already running.": "已有任务正在运行。",
        "Cancelled": "已取消",
        "Close other apps to free RAM": "关闭其他应用以释放 RAM",
        "Completed": "已完成",
        "Could not determine the base Python version to seed the new env with.": "无法确定用于创建新环境的基础 Python 版本。",
        "Could not find a `conda` binary on PATH or in common install locations.": "在 PATH 或常见安装位置找不到 `conda` 可执行文件。",
        "Could not resume run: no saved adapter checkpoint was found.": "无法恢复运行：未找到已保存的 adapter checkpoint。",
        "Done": "已完成",
        "Enable grad checkpointing": "启用 grad checkpointing",
        "FULL": "全量微调（FULL）",
        "Failed": "失败",
        "Finished": "已完成",
        "Hugging Face upload finished": "Hugging Face 上传已完成",
        "Hugging Face upload stopped": "Hugging Face 上传已停止",
        "Job completion notifications are off.": "任务完成通知已关闭。",
        "Job completion notifications are on.": "任务完成通知已开启。",
        "Job paused.": "任务已暂停。",
        "Job resumed.": "任务已恢复。",
        "Job stopped.": "任务已停止。",
        "Likely fits": "预计可容纳",
        "Lower batch size": "降低 batch size",
        "Notifications are only available when MLX LoRA Studio is running from the built .app bundle.": "仅从构建好的 .app bundle 运行 MLX LoRA Studio 时，才能使用通知。",
        "Package Reinstall": "包重新安装",
        "Package Update": "包更新",
        "Package reinstall": "包重新安装",
        "Package update": "包更新",
        "Paused": "已暂停",
        "Provider URL is empty or not a valid http(s) URL.": "Provider URL 为空，或不是有效的 http(s) URL。",
        "Provider returned a response the scraper could not parse.": "Provider 返回的响应无法解析。",
        "Ready": "就绪",
        "Reduce max sequence length": "减小 max sequence length",
        "Reinstall mlx, mlx-lm, matplotlib, and mlx-lm-lora": "重新安装 mlx、mlx-lm、matplotlib 和 mlx-lm-lora",
        "Requesting macOS notification permission...": "正在请求 macOS 通知权限…",
        "Risky": "可能不足",
        "Running": "运行中",
        "Stopped": "已停止",
        "Switch to LoRA": "切换到 LoRA",
        "Synthetic generation": "合成数据生成",
        "Terminal cleared.": "控制台已清空。",
        "That run folder is outside the configured output folder, so it was not deleted.": "此运行目录不在配置的输出目录内，因此未执行删除。",
        "The mlx-lm-lora package path does not exist.": "mlx-lm-lora 包路径不存在。",
        "The output folder could not be created.": "无法创建输出目录。",
        "The synthetic data job exited before completing successfully.": "合成数据任务在成功完成前退出。",
        "The synthetic data job has completed.": "合成数据任务已完成。",
        "The synthetic resume folder does not exist.": "继续生成合成数据所需的目录不存在。",
        "The training config could not be written.": "无法写入训练 config。",
        "The training run exited before completing successfully.": "训练任务在成功完成前退出。",
        "The training run has completed.": "训练任务已完成。",
        "The upload job exited before completing successfully.": "上传任务在成功完成前退出。",
        "The upload job has completed.": "上传任务已完成。",
        "The working directory does not exist.": "工作目录不存在。",
        "Too large": "超出容量",
        "Training steps": "训练 steps",
        "Try 4-bit quantization": "尝试 4-bit quantization",
        "Update mlx, mlx-lm, matplotlib, and mlx-lm-lora": "更新 mlx、mlx-lm、matplotlib 和 mlx-lm-lora",
        "Upload": "上传",
        "Use a smaller reference model": "使用较小的 reference model",
        "Waiting for administrator approval...": "等待管理员授权…",
        "macOS did not grant notification permission. Enable MLX LoRA Studio in System Settings > Notifications, then try again.": "macOS 未授予通知权限。请在系统设置 > 通知中启用 MLX LoRA Studio，然后重试。",
    ]
    private static let rules: [Rule] = [
        Rule(prefix: "Could not reach ", expression: try! NSRegularExpression(pattern: "\\ACould\\ not\\ reach\\ the\\ provider:\\ ([\\s\\S]*?)\\z"), parts: ["无法连接 provider：", ""], captures: [1]),
        Rule(prefix: "Provider returne", expression: try! NSRegularExpression(pattern: "\\AProvider\\ returned\\ HTTP\\ ([\\s\\S]*?)\\.\\z"), parts: ["Provider 返回 HTTP ", "。"], captures: [1]),
        Rule(prefix: "Provisioning fai", expression: try! NSRegularExpression(pattern: "\\AProvisioning\\ failed\\ \\(exit\\ ([\\s\\S]*?)\\)\\.\\\n([\\s\\S]*?)\\z"), parts: ["环境创建失败（exit ", "）。\n", ""], captures: [1, 2]),
        Rule(prefix: "An environment a", expression: try! NSRegularExpression(pattern: "\\AAn\\ environment\\ already\\ exists\\ at\\ ([\\s\\S]*?)\\.\\z"), parts: ["", " 已存在环境。"], captures: [1]),
        Rule(prefix: "Creating venv at", expression: try! NSRegularExpression(pattern: "\\ACreating\\ venv\\ at\\ ([\\s\\S]*?)\\ using\\ ([\\s\\S]*?)…\\z"), parts: ["正在使用 ", " 于 ", " 创建 venv…"], captures: [2, 1]),
        Rule(prefix: "Venv was created", expression: try! NSRegularExpression(pattern: "\\AVenv\\ was\\ created\\ but\\ no\\ executable\\ was\\ found\\ at\\ ([\\s\\S]*?)\\.\\z"), parts: ["Venv 已创建，但在 ", " 找不到可执行文件。"], captures: [1]),
        Rule(prefix: "Venv ready: ", expression: try! NSRegularExpression(pattern: "\\AVenv\\ ready:\\ ([\\s\\S]*?)\\z"), parts: ["Venv 已就绪：", ""], captures: [1]),
        Rule(prefix: "Creating conda e", expression: try! NSRegularExpression(pattern: "\\ACreating\\ conda\\ env\\ ([\\s\\S]*?)\\ \\(python=([\\s\\S]*?)\\)\\ using\\ ([\\s\\S]*?)…\\z"), parts: ["正在使用 ", " 创建 conda env ", "（python=", "）…"], captures: [3, 1, 2]),
        Rule(prefix: "Conda env was cr", expression: try! NSRegularExpression(pattern: "\\AConda\\ env\\ was\\ created\\ but\\ no\\ executable\\ was\\ found\\ at\\ ([\\s\\S]*?)\\.\\z"), parts: ["Conda env 已创建，但在 ", " 找不到可执行文件。"], captures: [1]),
        Rule(prefix: "Conda env ready:", expression: try! NSRegularExpression(pattern: "\\AConda\\ env\\ ready:\\ ([\\s\\S]*?)\\z"), parts: ["Conda env 已就绪：", ""], captures: [1]),
        Rule(prefix: "Command failed w", expression: try! NSRegularExpression(pattern: "\\ACommand\\ failed\\ with\\ exit\\ ([\\s\\S]*?)\\.\\z"), parts: ["命令执行失败，exit 为 ", "。"], captures: [1]),
        Rule(prefix: "Run folder: ", expression: try! NSRegularExpression(pattern: "\\ARun\\ folder:\\ ([\\s\\S]*?)\\z"), parts: ["运行目录：", ""], captures: [1]),
        Rule(prefix: "Custom ", expression: try! NSRegularExpression(pattern: "\\ACustom\\ ([\\s\\S]*?)\\ pipeline\\z"), parts: ["自定义 ", " pipeline"], captures: [1]),
        Rule(prefix: "Continuing synth", expression: try! NSRegularExpression(pattern: "\\AContinuing\\ synthetic\\ progress\\ from\\ ([\\s\\S]*?)\\ existing\\ records\\.\\z"), parts: ["从已有的 ", " 条记录继续生成合成数据。"], captures: [1]),
        Rule(prefix: "Upload spec: ", expression: try! NSRegularExpression(pattern: "\\AUpload\\ spec:\\ ([\\s\\S]*?)\\z"), parts: ["上传 spec：", ""], captures: [1]),
        Rule(prefix: "Upload ", expression: try! NSRegularExpression(pattern: "\\AUpload\\ ([\\s\\S]*?)\\ to\\ Hugging\\ Face\\z"), parts: ["将 ", " 上传到 Hugging Face"], captures: [1]),
        Rule(prefix: "Job exited with ", expression: try! NSRegularExpression(pattern: "\\AJob\\ exited\\ with\\ status\\ ([\\s\\S]*?)\\.\\z"), parts: ["任务已退出，status 为 ", "。"], captures: [1]),
        Rule(prefix: "Package update e", expression: try! NSRegularExpression(pattern: "\\APackage\\ update\\ exited\\ with\\ status\\ ([\\s\\S]*?)\\.\\z"), parts: ["包更新已退出，status 为 ", "。"], captures: [1]),
        Rule(prefix: "Could not write ", expression: try! NSRegularExpression(pattern: "\\ACould\\ not\\ write\\ metrics\\.json:\\ ([\\s\\S]*?)\\z"), parts: ["无法写入 metrics.json：", ""], captures: [1]),
        Rule(prefix: "Applied iogpu.wi", expression: try! NSRegularExpression(pattern: "\\AApplied\\ iogpu\\.wired_limit_mb=([\\s\\S]*?)\\.\\z"), parts: ["已应用 iogpu.wired_limit_mb=", "。"], captures: [1]),
        Rule(prefix: "Could not apply ", expression: try! NSRegularExpression(pattern: "\\ACould\\ not\\ apply\\ iogpu\\.wired_limit_mb:\\ ([\\s\\S]*?)\\z"), parts: ["无法应用 iogpu.wired_limit_mb：", ""], captures: [1]),
        Rule(prefix: "", expression: try! NSRegularExpression(pattern: "\\A([\\s\\S]*?)\\ training\\ finished\\z"), parts: ["", " 训练已完成"], captures: [1]),
        Rule(prefix: "", expression: try! NSRegularExpression(pattern: "\\A([\\s\\S]*?)\\ training\\ stopped\\z"), parts: ["", " 训练已停止"], captures: [1]),
        Rule(prefix: "Could not start ", expression: try! NSRegularExpression(pattern: "\\ACould\\ not\\ start\\ training:\\ ([\\s\\S]*?)\\z"), parts: ["无法启动训练：", ""], captures: [1]),
        Rule(prefix: "Preparing resume", expression: try! NSRegularExpression(pattern: "\\APreparing\\ resume\\ from\\ ([\\s\\S]*?)\\z"), parts: ["准备从 ", " 恢复"], captures: [1]),
        Rule(prefix: "", expression: try! NSRegularExpression(pattern: "\\A([\\s\\S]*?)\\ data\\ generation\\ finished\\z"), parts: ["", " 数据生成已完成"], captures: [1]),
        Rule(prefix: "", expression: try! NSRegularExpression(pattern: "\\A([\\s\\S]*?)\\ data\\ generation\\ stopped\\z"), parts: ["", " 数据生成已停止"], captures: [1]),
        Rule(prefix: "Could not start ", expression: try! NSRegularExpression(pattern: "\\ACould\\ not\\ start\\ synthetic\\ job:\\ ([\\s\\S]*?)\\z"), parts: ["无法启动合成数据任务：", ""], captures: [1]),
        Rule(prefix: "Could not start ", expression: try! NSRegularExpression(pattern: "\\ACould\\ not\\ start\\ HF\\ upload:\\ ([\\s\\S]*?)\\z"), parts: ["无法启动 HF 上传：", ""], captures: [1]),
        Rule(prefix: "Could not start ", expression: try! NSRegularExpression(pattern: "\\ACould\\ not\\ start\\ package\\ update:\\ ([\\s\\S]*?)\\z"), parts: ["无法启动包更新：", ""], captures: [1]),
        Rule(prefix: "Could not start ", expression: try! NSRegularExpression(pattern: "\\ACould\\ not\\ start\\ package\\ reinstall:\\ ([\\s\\S]*?)\\z"), parts: ["无法启动包重新安装：", ""], captures: [1]),
        Rule(prefix: "", expression: try! NSRegularExpression(pattern: "\\A([\\s\\S]*?)\\ Exit\\ status:\\ ([\\s\\S]*?)\\.\\z"), parts: ["", " Exit status：", "。"], captures: [1, 2]),
        Rule(prefix: "Could not create", expression: try! NSRegularExpression(pattern: "\\ACould\\ not\\ create\\ environment:\\ ([\\s\\S]*?)\\z"), parts: ["无法创建环境：", ""], captures: [1]),
        Rule(prefix: "Could not load p", expression: try! NSRegularExpression(pattern: "\\ACould\\ not\\ load\\ previous\\ synthetic\\ settings:\\ ([\\s\\S]*?)\\z"), parts: ["无法载入先前的合成数据设置：", ""], captures: [1]),
        Rule(prefix: "Loaded synthetic", expression: try! NSRegularExpression(pattern: "\\ALoaded\\ synthetic\\ settings\\ from\\ ([\\s\\S]*?)\\ —\\ backend:\\ ([\\s\\S]*?),\\ ([\\s\\S]*?):\\ ([\\s\\S]*?)\\z"), parts: ["已从 ", " 载入合成数据设置 — backend：", "，", "：", ""], captures: [1, 2, 3, 4]),
    ]

    static func display(_ original: String) -> String { render(original, depth: 0) }

    private static func render(_ original: String, depth: Int) -> String {
        if let translated = exact[original] { return translated }
        guard depth < 3 else { return original }
        let range = NSRange(original.startIndex..<original.endIndex, in: original)
        for rule in rules where original.hasPrefix(rule.prefix) {
            guard let match = rule.expression.firstMatch(in: original, range: range) else { continue }
            var output = rule.parts[0]
            for (index, capture) in rule.captures.enumerated() {
                guard let captured = Range(match.range(at: capture), in: original) else { return original }
                output += render(String(original[captured]), depth: depth + 1)
                output += rule.parts[index + 1]
            }
            return output
        }
        return original
    }

    static func log(_ original: String) -> String {
        let prefix = "[Studio] "
        guard original.hasPrefix(prefix) else { return original }
        return prefix + display(String(original.dropFirst(prefix.count)))
    }

    static func suggestion(_ original: String) -> String {
        original.components(separatedBy: " · ").map(display).joined(separator: " · ")
    }
}
