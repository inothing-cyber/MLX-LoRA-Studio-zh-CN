import Foundation
import Testing
@testable import MLXLoRAStudio

@Suite("Metric display regression")
struct MetricsReadingTests {
    @Test(arguments: [
        "Iter 5 | Train | loss 3.599 | lr 1.00e-05 | 8.71 it/s | 331 tok/s | 2.71 GB",
        "Iter 5: loss 3.599, it/s 8.71, tok/s 331, peak_mem 2.71GB",
        "Iter 5: loss 3.599, it/s: 8.71, tokens/s=331",
        "Iter 5: loss 3.599 | 8.71 iterations/s | 3.31e2 TOKENS/S",
        "Iter 5: loss 3.599, it /s 8.71, tok /s 331",
        "\u{001B}[32mIter 5: loss 3.599 | 8.71 it/s | 331 tok/s\u{001B}[0m"
    ])
    func formats(line: String) throws {
        let metric = try #require(MetricsParser().consume(line).first)
        #expect(metric.step == 5)
        #expect(metric.values["it_s"] == 8.71)
        #expect(metric.values["tok_s"] == 331)
    }

    @Test(arguments: ["Iter 5: loss 1 | it/s unknown | 331 tok/s | 2.71 GB",
                      "Iter 5: loss 1, it/s: NaN, tok/s 331",
                      "Iter 5: loss 1, it/s 1e999, tok/s 331"])
    func missingRateDoesNotStealNextNumber(line: String) throws {
        let metric = try #require(MetricsParser().consume(line).first)
        #expect(metric.values["it_s"] == nil)
        #expect(metric.values["tok_s"] == 331)
    }

    @Test(arguments: [false, true])
    func structuredPrecisionWinsInEitherOrder(reverse: Bool) throws {
        let json = #"@@studio_metric {"iteration":5,"iterations_per_second":8.71192074006166,"tokens_per_second":331.05298812234304}"#
        let text = "Iter 5 | loss 3.599 | 8.71 it/s | 331 tok/s | 2.71 GB"
        let raw = reverse ? text + "\n" + json : json + "\n" + text
        let before = TrainingMetric(step: 5, values: ["it_s":331, "tok_s":2.71, "loss":3.599], rawLine: raw)
        let corrected = StudioMetricReadings.correctedForDisplay(before)
        #expect(corrected.values["it_s"] == 8.71192074006166)
        #expect(corrected.values["tok_s"] == 331.05298812234304)
        #expect(corrected.values["loss"] == before.values["loss"])
        #expect(corrected.rawLine == before.rawLine)
        #expect(corrected.id == before.id)
    }

    @Test func historyReadDoesNotRewriteArchive() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = root.appendingPathComponent("fixture-run")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("{}".utf8).write(to: folder.appendingPathComponent("run_spec.json"))
        let url = folder.appendingPathComponent("metrics.json")
        let old = TrainingMetric(step: 5, values: ["it_s":331, "tok_s":2.71, "loss":3.599],
            rawLine: "Iter 5 | loss 3.599 | 8.71 it/s | 331 tok/s | 2.71 GB")
        try TrainingMetricIO.write([old], to: url)
        let bytes = try Data(contentsOf: url)
        let run = try #require(RunArchive.discoverPersistedRuns(outputRoot: root.path).first)
        let read = try #require(run.metrics.first)
        #expect(read.values["it_s"] == 8.71)
        #expect(read.values["tok_s"] == 331)
        #expect(read.values["loss"] == 3.599)
        #expect(try Data(contentsOf: url) == bytes)
        #expect(TrainingMetricIO.read(from: url).first?.values["tok_s"] == 2.71)
    }

    @Test func unrelatedOrMalformedReportsKeepValues() {
        let old = TrainingMetric(step: 5, values: ["tok_s":123, "val_loss":1.2],
            rawLine: #"@@studio_metric {"iteration":6,"tokens_per_second":999}"# + "\n@@studio_metric {bad}")
        #expect(StudioMetricReadings.correctedForDisplay(old).values == old.values)
    }
}
