import Foundation
import CoreFoundation

/// Repairs display readings only; preserves the training process and raw reports.
enum StudioMetricReadings {
    enum Rate: CaseIterable { case iterations, tokens }

    private static let number = #"([-+]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:e[-+]?[0-9]+)?)"#
    private static let rules: [Rate: [NSRegularExpression]] = {
        let aliases: [Rate: [String]] = [
            .iterations: ["it/s", "iterations/s", "it /s"],
            .tokens: ["tok/s", "tokens/s", "tok /s"]
        ]
        return aliases.mapValues { names in
            let unit = "(?:" + names.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + ")"
            // Bound each value to its own field. Never scan past a separator
            // to the next metric when a value is absent or comes first.
            let end = #"(?=\s*(?:[,;|\]]|$))"#
            return [
                #"(?<![\p{L}\p{N}_/])"# + unit + #"[ \t]*[:=]?[ \t]*"# + number + end,
                #"(?<![\p{L}\p{N}_.+\-])"# + number + #"[ \t]*"# + unit + end
            ].map { try! NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
        }
    }()

    static func throughput(_ rate: Rate, in line: String) -> Double? {
        let line = clean(line)
        for regex in rules[rate] ?? [] {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = regex.firstMatch(in: line, range: range),
                  let numberRange = Range(match.range(at: 1), in: line),
                  let value = Double(line[numberRange]), value.isFinite else { continue }
            return value
        }
        return nil
    }

    /// Rebuild just throughput from the embedded raw reports. Also used on
    /// history reads, without rewriting the existing metrics.json file.
    static func correctedForDisplay(_ metric: TrainingMetric) -> TrainingMetric {
        var textValues: [String: Double] = [:]
        var structured: [String: Double] = [:]
        for raw in metric.rawLine.split(separator: "\n") {
            let line = clean(String(raw)).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("@@studio_metric ") {
                let data = Data(line.dropFirst("@@studio_metric ".count).utf8)
                guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let iteration = numeric(object["iteration"]), iteration == Double(metric.step) else { continue }
                for (key, aliases) in [("it_s", ["iterations_per_second", "it_s"]),
                                       ("tok_s", ["tokens_per_second", "tok_s"])] {
                    for alias in aliases {
                        if let value = numeric(object[alias]) { structured[key] = value; break }
                    }
                }
            } else {
                if let value = throughput(.iterations, in: line) { textValues["it_s"] = value }
                if let value = throughput(.tokens, in: line) { textValues["tok_s"] = value }
            }
        }
        var values = metric.values
        for (key, value) in textValues { values[key] = value }
        for (key, value) in structured { values[key] = value }
        var corrected = TrainingMetric(step: metric.step, values: values, rawLine: metric.rawLine)
        corrected.id = metric.id
        return corrected
    }

    private static func numeric(_ value: Any?) -> Double? {
        let result: Double?
        switch value {
        case let number as NSNumber:
            guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            result = number.doubleValue
        case let text as String: result = Double(text)
        default: result = nil
        }
        guard let result, result.isFinite else { return nil }
        return result
    }

    private static func clean(_ line: String) -> String {
        line.replacingOccurrences(of: "\u{001B}\\[[0-?]*[ -/]*[@-~]", with: "", options: .regularExpression)
    }
}
