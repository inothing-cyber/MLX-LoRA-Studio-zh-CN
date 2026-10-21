import Foundation

@main struct ContractProbe {
    static func main() throws {
        var records: [[String: Any]] = []
        func add(_ name: String, _ data: Data) throws {
            records.append(["name":name,"spec":try JSONSerialization.jsonObject(with:data)])
        }
        for mode in TrainMode.allCases {
            for type in TrainType.allCases {
                for quant in Quantization.allCases {
                    var config=TrainingConfig()
                    config.trainMode=mode
                    config.trainType=type
                    config.quantization=quant
                    config.model="owner/model"
                    config.data="/tmp/数据/data"
                    config.datasetSystemPrompt="Preserve SFT, token and 中文 exactly."
                    config.seed=123
                    try add("\(mode.rawValue)/\(type.rawValue)/\(quant.rawValue)", config.runSpecData(adapterPath:"/tmp/适配器"))
                }
            }
        }
        for optimizer in OptimizerKind.allCases {
            var config=TrainingConfig();config.optimizer=optimizer
            try add("optimizer/\(optimizer.rawValue)",config.runSpecData())
        }
        for loss in SFTLossType.allCases {
            var config=TrainingConfig();config.sftLossType=loss
            try add("loss/\(loss.rawValue)",config.runSpecData())
        }
        for family in ModelFamily.allCases {
            var config=TrainingConfig();config.modelFamily=family;config.vlmModel="owner/vlm"
            try add("family/\(family.rawValue)",config.runSpecData())
        }
        for target in HFUploadTarget.allCases {
            try add("upload/\(target.rawValue)",HFUploadConfig().runSpecData(target:target))
        }
        for kind in SyntheticKind.allCases {
            var config=SyntheticConfig();config.kind=kind
            try add("synthetic/\(kind.rawValue)",config.runSpecData(outputDir:"/tmp/生成数据"))
        }
        let result=try JSONSerialization.data(withJSONObject:records,options:[.sortedKeys])
        FileHandle.standardOutput.write(result)
    }
}
