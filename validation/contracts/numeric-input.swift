import Foundation

@main struct NumericInputProbe {
    static func main() {
        var actual = 0.00001
        let invalid = ["", " ", "1e-", "abc", "0，1", "NaN", "inf", "-Infinity", "1e309"]
        for text in invalid {
            if let parsed = StudioNumericInput.parse(text) { actual = parsed }
            guard actual == 0.00001,
                  let warning = StudioNumericInput.warning(for: text, actualValue: actual),
                  warning.contains(String(format: "%.16g", actual)) else {
                fatalError("Invalid editing state was not explained: \(text)")
            }
        }
        let valid: [(String, Double)] = [("1e-5", 0.00001), (" 0.25 ", 0.25), ("-0.5", -0.5), ("0", 0)]
        for (text, expected) in valid {
            guard let parsed = StudioNumericInput.parse(text), parsed == expected,
                  StudioNumericInput.warning(for: text, actualValue: expected) == nil else {
                fatalError("Valid numeric value changed: \(text)")
            }
        }
        print("13 numeric editing contracts passed")
    }
}
