import Foundation

@main struct DisplayProbe {
    static func main() throws {
        let samples:[(String,String)] = [
            ("Running","运行中"),
            ("Provider returned HTTP 401.","Provider 返回 HTTP 401。"),
            ("Could not start training: The working directory does not exist.","无法启动训练：工作目录不存在。"),
            ("Creating venv at /tmp/环境 using /opt/python…","正在使用 /opt/python 于 /tmp/环境 创建 venv…"),
            ("SFT training finished","SFT 训练已完成"),
            ("The upload job exited before completing successfully. Exit status: 7.","上传任务在成功完成前退出。 Exit status：7。"),
            ("SFT","SFT"),("tokens/s","tokens/s"),
            ("FULL","全量微调（FULL）"),
            ("owner/private-model","owner/private-model"),
            ("unrecognized original error: /tmp/中文","unrecognized original error: /tmp/中文")
        ]
        for (original,expected) in samples {
            let actual=StudioL10n.display(original)
            guard actual==expected else { fatalError("Presentation mismatch: \(original) -> \(actual)") }
        }
        let raw="[Studio] Run folder: /tmp/中文"
        guard StudioL10n.log(raw)=="[Studio] 运行目录：/tmp/中文",raw=="[Studio] Run folder: /tmp/中文" else { fatalError("Log mutation") }
        guard StudioL10n.log("loss 1.23 tokens/s 100")=="loss 1.23 tokens/s 100" else { fatalError("Raw metrics changed") }
        print("13 presentation contracts passed")
    }
}
