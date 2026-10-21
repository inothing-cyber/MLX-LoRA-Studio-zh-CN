import Foundation

/// UI editing feedback only. Backend validation and valid numeric values stay unchanged.
enum StudioNumericInput {
    static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let number = Double(trimmed), number.isFinite else { return nil }
        return number
    }

    static func warning(for text: String, actualValue: Double) -> String? {
        guard parse(text) == nil else { return nil }
        let actual = String(format: "%.16g", actualValue)
        return "输入未完成或不是有效数值；本项实际值仍为 \(actual)。按 Return 恢复该值。"
    }
}
