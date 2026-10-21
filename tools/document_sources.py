#!/usr/bin/env python3
"""Document existing translations without changing application sources or catalogs."""
from __future__ import annotations

import argparse
import collections
import html
import json
import re
from pathlib import Path

import localize

PROJECT = Path(__file__).resolve().parents[1]
GUIDE = "Sources/MLXLoRAStudio/Views/AlgorithmGuideView.swift"
REVIEWED_COMMIT = "69e34a31aca717b6d5a0a4f5306e25cf7c0b18f1"
ALGORITHMS = {
    "sft": ["P04"], "dpo": ["P05"], "ftpo": ["P13"],
    "cpo": ["P06"], "orpo": ["P07"], "grpo": ["P08", "P09"],
    "onlineDPO": ["P05", "P12"], "xpo": ["P05", "P10"],
    "rlhfReinforce": ["P04", "P11"], "ppo": ["P04", "P09"],
}
# These are reviewed ranges in the pinned original, never in translated sources.
BLOCKS = [
    (262, 318, "算法概述"), (321, 386, "算法直觉"),
    (402, 494, "算法数学说明"), (598, 755, "算法参数"),
    (761, 805, "数据格式"), (810, 857, "适用场景"),
    (875, 943, "操作建议"),
]
TABLE_NAMES = {
    "bilingual-labels": "双语参数与标签", "core": "通用界面与设置",
    "dynamic-display": "动态状态与错误说明", "final-labels": "补充标签",
    "guide-foundations": "指南：基础知识", "guide-intro": "指南：算法介绍",
    "guide-parameters": "指南：参数说明", "guide-usage": "指南：数据与用法",
    "interface": "界面说明与交互", "model-display": "模型类型与显示",
    "synthetic": "遗留合成数据页面",
}
CLARIFICATIONS = {
    49: "保留原指南 3.0.0 背景，并提示以内置后端实际版本为准。",
    547: "本项目补充区分论文 α/r 约定与本次观察的 mlx-lm scale 参数；不改变参数。",
    1287: "本项目补充区分论文公式与具体 MLX scale 实现。",
    1316: "本项目补充说明不能把论文 α/r 直接用于现有 scale 值换算。",
    1470: "本项目将原指南整数公式标为示意，提醒以具体 MLX quantization mode 为准。",
    1489: "本项目补充 MXFP4/E8M0 与整数示意公式的区别。",
    1524: "本项目补充 MXFP4 分组和编码区别。",
}


def cell(value: str, limit: int = 62) -> str:
    value = " ".join(value.replace("\\n", " ").split())
    if len(value) > limit:
        value = value[:limit] + "…"
    return (html.escape(value).replace("|", "&#124;").replace("`", "&#96;")
            .replace("[", "&#91;").replace("]", "&#93;").replace("*", "&#42;"))


def guide_ranges(source: str):
    result = []
    lines = source.splitlines()
    for start, end, section in BLOCKS:
        cases = []
        for number in range(start, end + 1):
            text = lines[number - 1].strip()
            if text.startswith("case "):
                modes = re.findall(r"\.(\w+)", text.split(":", 1)[0])
                if not modes or any(mode not in ALGORITHMS for mode in modes):
                    raise ValueError(f"Unreviewed guide case at {number}")
                cases.append((number, modes))
        if not cases:
            raise ValueError(f"Guide section disappeared: {section}")
        for index, (number, modes) in enumerate(cases):
            last = cases[index + 1][0] - 1 if index + 1 < len(cases) else end
            refs = sorted({ref for mode in modes for ref in ALGORITHMS[mode]})
            result.append((number, last, section, refs))
    return result


def background(row, ranges):
    if row["file"] != GUIDE:
        return [], "界面原文"
    line = row["line"]
    refs, section = [], "指南原文"
    for start, end, label, ids in ranges:
        if start <= line <= end:
            refs, section = list(ids), label
            break
    if 1254 <= line <= 1350:
        refs, section = ["P01", "P03"], "Adaptation methods"
    elif 1353 <= line <= 1452:
        refs, section = ["P16", "P17", "D01", "D02"], "Optimizers"
    elif line >= 1455:
        refs, section = ["P02", "P18"], "Quantization / QAT"
    text = row["source_value"] + " " + row["target_value"]
    for pattern, extra in [(r"\b(?:DFT|Dynamic Fine-Tuning)\b", ["P14"]),
                           (r"\bGSPO\b", ["P15"]),
                           (r"\bMXFP4\b", ["D09"])]:
        if re.search(pattern, text):
            refs.extend(extra)
    if line == 547:
        refs.append("P01")
    return sorted(set(refs)), section


def generate():
    localize.check_upstream()
    lock = json.loads((PROJECT / "localization/reviewed-upstream.json").read_text())
    if lock["commit"] != REVIEWED_COMMIT:
        raise ValueError("Review citation ranges for the new upstream commit first.")
    entries = json.loads((PROJECT / "localization/catalog/entries.json").read_text())
    if entries != localize.read_translations():
        raise ValueError("The catalog and TSV translations differ.")
    bibliography = json.loads((PROJECT / "localization/reference-sources.json").read_text())
    refs = bibliography["papers"] + bibliography["documents"]
    ids = {ref["id"] for ref in refs}
    if len(ids) != len(refs) or any(not ref["url"].startswith("https://") for ref in refs):
        raise ValueError("Duplicate references or non-HTTPS reference URL.")
    ranges = guide_ranges((localize.UPSTREAM / GUIDE).read_text())
    source_base = f"https://github.com/{lock['repository']}/blob/{lock['commit']}/"
    grouped = collections.defaultdict(list)
    for row in entries:
        grouped[row["table"]].append(row)
    outputs = {}
    inventory = collections.defaultdict(list)
    for record in json.loads((PROJECT / "localization/string-candidates.json").read_text())["records"]:
        inventory[(Path(record["file"]).name, record["line"])].append(record)
    index = ["# 逐条译文来源索引", "", "本页由 `tools/document_sources.py` 生成。",
             "", f"对应官方 {lock['tag']} / `{lock['commit']}`。共 {len(entries)} 处资源出现位置，含重复和保留原文的技术标签；不表示覆盖率百分比。",
             "", "每条记录链接到锁定的英文原文和完整中文 TSV。多段文字在目录中保存为同一字符串时，共用该原文位置；点击链接可展开完整段落。论文栏仅列相关理论背景，直接翻译来源始终是应用原文。",
             "", "参见[来源说明](../TRANSLATION_SOURCES.md)和[参考文献](../REFERENCES.md)。",
             "", "| 分类 | 条目数 |", "| --- | ---: |"]
    guide_count = 0
    for table, rows in sorted(grouped.items()):
        stem = Path(table).stem
        if stem not in TABLE_NAMES:
            raise ValueError(f"Unreviewed catalog table: {table}")
        selectors = {}
        for number, text in enumerate((PROJECT / "localization/catalog" / table).read_text().splitlines(), 1):
            if not text or text.startswith("#"):
                continue
            selector, target = text.split("\t", 1)
            file, rest = selector.split(":", 1)
            line, _, nth = rest.partition("#")
            key = (file, int(line), int(nth or 0))
            if key in selectors:
                raise ValueError(f"Duplicate TSV selector: {selector}")
            selectors[key] = (number, target)
        title = TABLE_NAMES[stem]
        index.append(f"| [{title}]({stem}.md) | {len(rows)} |")
        page = [f"# {title}：译文来源", "", "[全部分类](README.md) · [来源说明](../TRANSLATION_SOURCES.md) · [论文与官方资料](../REFERENCES.md)",
                "", "“英文原文”固定到已审定官方 commit；“完整译文”固定到本仓库对应 TSV 行。预览仅用于查找，完整原文和译文请点链接。",
                "", "“相关背景”列用于核对概念；该列不表示参数、公式、性能数字或应用实现均由论文证明。普通操作标签不强行归入论文。",
                "", "| 位置与分类 | 中文预览 | 英文原文 | 完整译文 | 相关背景 |", "| --- | --- | --- | --- | --- |"]
        for row in sorted(rows, key=lambda item: (item["file"], item["line"], item["column"])):
            file, line = Path(row["file"]).name, row["line"]
            candidates = inventory[(file, line)]
            nth = next(i for i, item in enumerate(candidates) if item["column"] == row["column"])
            number, target = selectors[(file, line, nth)]
            if target != row["target_value"]:
                raise ValueError("TSV target mismatch")
            background_ids, section = background(row, ranges)
            if not set(background_ids) <= ids:
                raise ValueError("Unknown reference ID")
            if row["file"] == GUIDE:
                guide_count += 1
            if row["file"] == GUIDE and line in CLARIFICATIONS and len(row["source_value"]) > 60:
                section += "；含本项目补充，见来源说明"
            background_links = "、".join(f"[{ref}](../REFERENCES.md#{ref.lower()})" for ref in background_ids) or "应用原文"
            original = source_base + row["file"] + f"#L{line}"
            translated = f"../../localization/catalog/{table}?plain=1#L{number}"
            page.append(f"| {file}:{line}:{row['column']}<br>{section} | {cell(target)} | [原文]({original}) | [译文]({translated}) | {background_links} |")
        outputs[PROJECT / f"docs/translation_sources/{stem}.md"] = "\n".join(page) + "\n"
    index += ["", f"算法指南对应 {guide_count} 处资源出现位置。新增控制台说明和数值输入提示另见[本项目补充说明](../TRANSLATION_SOURCES.md#project-additions)。",
              "", "维护时修改译文目录后运行 `python3 tools/document_sources.py --write`，再运行 `--check`。更新官方版本需先审查本工具的版本锁、区段与引用关系。"]
    outputs[PROJECT / "docs/translation_sources/README.md"] = "\n".join(index) + "\n"
    book = ["# 论文与一手参考资料", "", "[译文来源说明](TRANSLATION_SOURCES.md) · [逐条来源索引](translation_sources/README.md)",
            "", f"核对日期：{bibliography['checked_on']}。{bibliography['checked_scope']}",
            "", "本页记录本次中文解释的术语核对依据。中文表述由本项目 AI 辅助翻译、整理，维护账号 inothing-cyber；引用不表示原作者提供中文译文或为本项目背书。不收录论文全文。",
            "", "P 为论文／预印本，年份按首发年；D 为官方文档、作者说明、实现或规范。网页及代码入口可能更新，应用原文则固定到已审定 commit。",
            "", "## 论文与预印本", ""]
    for category in ["papers", "documents"]:
        if category == "documents":
            book += ["## 官方文档、作者说明与格式规范", ""]
        for ref in bibliography[category]:
            year = str(ref["first_year"]) if ref["first_year"] else "持续维护资料，版本以页面为准"
            book += [f"<a id=\"{ref['id'].lower()}\"></a>", "", f"### {ref['id']} · {ref['topic']}", "",
                     f"{ref['authors']}，{year}。[{ref['title']}]({ref['url']})。", "", ref["role"], ""]
    book += ["## 引用范围", "", "算法论文用于核对概念。应用的字段、默认值、数据集要求、分发逻辑、QAT hook 与执行参数，以对应版本代码和所选环境为准；操作建议、资源占用估算和速度比较不能仅凭本页引用变成已验证结论。具体差异见[来源说明](TRANSLATION_SOURCES.md#implementation-limits)。"]
    outputs[PROJECT / "docs/REFERENCES.md"] = "\n".join(book) + "\n"
    return outputs, {"catalog_occurrences": len(entries), "guide_occurrences": guide_count,
                     "papers": len(bibliography["papers"]), "other_primary_sources": len(bibliography["documents"])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write", action="store_true", help="Write generated documentation only")
    mode.add_argument("--check", action="store_true", help="Check committed documentation (default)")
    args = parser.parse_args()
    outputs, report = generate()
    if args.write:
        for path, content in outputs.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
    else:
        changed = [str(path.relative_to(PROJECT)) for path, content in outputs.items()
                   if not path.is_file() or path.read_text() != content]
        if changed:
            raise SystemExit("Documentation needs regeneration: " + ", ".join(changed))
    print(json.dumps(dict(report, mode="write" if args.write else "check", passed=True), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
