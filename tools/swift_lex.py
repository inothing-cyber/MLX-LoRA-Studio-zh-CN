"""Swift literal inventory, derived from the MIT-licensed localization tooling."""
from pathlib import Path
import bisect
import re

SOURCE=Path('.')

def skip_comment(s: str, i: int) -> int:
    if s.startswith("//", i):
        n = s.find("\n", i)
        return len(s) if n < 0 else n
    if s.startswith("/*", i):
        depth, i = 1, i + 2
        while i < len(s) and depth:
            if s.startswith("/*", i):
                depth, i = depth + 1, i + 2
            elif s.startswith("*/", i):
                depth, i = depth - 1, i + 2
            else:
                i += 1
        return i
    return i


def string_start(s: str, i: int):
    j = i
    while j < len(s) and s[j] == "#":
        j += 1
    if j < len(s) and s[j] == '"':
        q = '"""' if s.startswith('"""', j) else '"'
        return j - i, q, j + len(q)
    return None


def skip_interpolation(s: str, i: int) -> int:
    depth = 1
    while i < len(s) and depth:
        j = skip_comment(s, i)
        if j != i:
            i = j
        elif string_start(s, i):
            i, _, _ = read_string(s, i)
        elif s[i] == "(":
            depth, i = depth + 1, i + 1
        elif s[i] == ")":
            depth, i = depth - 1, i + 1
        else:
            i += 1
    return i


def read_string(s: str, start: int):
    hashes, quote, i = string_start(s, start)
    content_start = i
    close = quote + "#" * hashes
    escape = "\\" + "#" * hashes
    interpolated = False
    while i < len(s):
        if s.startswith(escape + "(", i):
            interpolated = True
            i = skip_interpolation(s, i + len(escape) + 1)
        elif s.startswith(escape, i):
            i += len(escape) + 1
        elif s.startswith(close, i):
            return i + len(close), s[content_start:i], interpolated
        else:
            i += 1
    raise ValueError(f"Unterminated Swift string near offset {start}")


def strings_in_file(path: Path) -> list[dict]:
    s = path.read_text()
    starts = [0] + [m.end() for m in re.finditer("\n", s)]
    lines = s.splitlines()
    records, i = [], 0
    while i < len(s):
        j = skip_comment(s, i)
        if j != i:
            i = j
            continue
        if not string_start(s, i):
            i += 1
            continue
        end, value, interpolated = read_string(s, i)
        line_index = bisect.bisect_right(starts, i) - 1
        context = "\n".join(lines[max(0, line_index - 1):line_index + 2])
        prefix = s[max(starts[line_index], i - 100):i]
        technical = (
            re.search(r"\b(?:systemImage|systemName|symbol)\s*:\s*$", prefix)
            or re.search(r"\bcase\s+\w+\s*=\s*$", prefix)
            or re.match(r"\s*:", s[end:end + 5])
            or re.match(r"(?:https?://|/|~/)", value)
        )
        category = "keep_identifier_candidate" if technical else (
            "display_candidate" if path.parent.name in {"Views", "App"} else "review"
        )
        records.append({
            "file": str(path.relative_to(SOURCE)),
            "line": line_index + 1,
            "column": i - starts[line_index] + 1,
            "source_value": value,
            "interpolated": interpolated,
            "classification": category,
            "review_status": "unreviewed",
            "context": context,
        })
        i = end
    return records

