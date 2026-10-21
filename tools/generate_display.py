"""Generate an explicit presentation-only lookup; never alter runner data."""
from pathlib import Path
import json
import re
import swift_lex as audit

ROOT = Path(__file__).resolve().parents[1] / 'localization'


def swift_string(s):
    return json.dumps(s, ensure_ascii=False).replace("\\/", "/")


def decode_literal(s):
    # Text fragments only, after interpolation expressions were removed.
    return re.sub(r'\\(u\{[0-9a-fA-F]+\}|[nrt0"\\])', lambda m: (
        chr(int(m.group(1)[2:-1],16)) if m.group(1).startswith('u{') else
        {'n':'\n','r':'\r','t':'\t','0':'\0','"':'"','\\':'\\'}[m.group(1)]), s)


def split_template(s):
    parts, expressions, i, last = [], [], 0, 0
    while i < len(s):
        if s.startswith('\\(', i):
            end = audit.skip_interpolation(s, i + 2)
            parts.append(decode_literal(s[last:i]))
            expressions.append(s[i + 2:end - 1])
            i = last = end
        elif s.startswith('\\', i):
            i += 2
        else:
            i += 1
    parts.append(decode_literal(s[last:]))
    return parts, expressions


def generate(entries, destination=None):
    exact = {
        'Running':'运行中', 'Paused':'已暂停', 'Stopped':'已停止',
        'Completed':'已完成', 'Finished':'已完成', 'Failed':'失败',
        'Cancelled':'已取消', 'Done':'已完成', 'Ready':'就绪',
        'Training steps':'训练 steps', 'Synthetic generation':'合成数据生成',
        'Upload':'上传', 'Package update':'包更新', 'Package reinstall':'包重新安装',
        'Package Update':'包更新', 'Package Reinstall':'包重新安装',
        'Job stopped.':'任务已停止。', 'Job paused.':'任务已暂停。',
        'Job resumed.':'任务已恢复。', 'Terminal cleared.':'控制台已清空。',
        'Likely fits':'预计可容纳', 'Risky':'可能不足', 'Too large':'超出容量',
        'FULL':'全量微调（FULL）',
    }
    rules, unique = [], set()
    for row in entries:
        if row['delivery'] != 'display_lookup':
            continue
        original, exprs = split_template(row['source_value'])
        translated, target_exprs = split_template(row['target_value'])
        if not exprs:
            exact[''.join(original)] = ''.join(translated)
            continue
        pattern = r'\A' + r'([\s\S]*?)'.join(re.escape(x) for x in original) + r'\z'
        if pattern in unique:
            continue
        unique.add(pattern)
        groups = []
        for expr in target_exprs:
            if expr not in exprs:
                raise ValueError('Unmatched display placeholder: '+expr)
            groups.append(exprs.index(expr) + 1)
        rules.append((original[0][:16], pattern, translated, groups))
    native = Path(destination) if destination is not None else ROOT/'native'
    native.mkdir(exist_ok=True)
    lines = ['import Foundation', '',
        '// Generated presentation-only translations. Runner data, logs and protocol values stay original.',
        'enum StudioL10n {', '    private struct Rule {',
        '        let prefix: String', '        let expression: NSRegularExpression',
        '        let parts: [String]', '        let captures: [Int]', '    }',
        '    private static let exact: [String: String] = [']
    lines += ['        '+swift_string(k)+': '+swift_string(v)+',' for k,v in sorted(exact.items())]
    lines += ['    ]','    private static let rules: [Rule] = [']
    for prefix,pattern,parts,groups in rules:
        # regexes and source fragments are generated from reviewed literal templates.
        lines.append('        Rule(prefix: '+swift_string(prefix)+', expression: try! NSRegularExpression(pattern: '+swift_string(pattern)+'), parts: ['+', '.join(map(swift_string,parts))+'], captures: ['+', '.join(map(str,groups))+']),')
    lines += ['    ]', '''
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
''']
    (native/'StudioL10n.swift').write_text('\n'.join(lines))


if __name__ == '__main__':
    generate(json.loads((ROOT/'catalog/entries.json').read_text()))
