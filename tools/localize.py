#!/usr/bin/env python3
"""Portable reviewed localization; never installs, launches or updates training packages."""
from __future__ import annotations
import argparse
import collections
import hashlib
import json
import re
import shutil
import tempfile
from pathlib import Path
import swift_lex as audit

PROJECT=Path(__file__).resolve().parents[1]
ROOT=PROJECT/'localization'
UPSTREAM=PROJECT/'.cache/upstream'
WORK=PROJECT/'.build/zh-src'
CATALOG=ROOT/'catalog'
BASE=json.loads((ROOT/'source-baseline.json').read_text())
GRAMMATICAL_PLURAL_DROPS = {
    ('RunsView.swift', 130): ['count == 1 ? "" : "s"'],
    ('RunsView.swift', 132): ['count == 1 ? "" : "s"'],
    ('SyntheticDataView.swift', 445): ['scrapedModels.count == 1 ? "" : "s"'],
    ('TrainingView.swift', 253): ['n == 1 ? "" : "s"', 'd == 1 ? "" : "s"'],
    ('SharedControls.swift', 222): ['text.count == 1 ? "" : "s"'],
}

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def check_upstream():
    reviewed=json.loads((ROOT/'reviewed-upstream.json').read_text())
    if sha(ROOT/'source-baseline.json')!=reviewed['source_manifest_sha256'] or BASE['commit']!=reviewed['commit']:
        raise ValueError('Source manifest differs from the reviewed version lock.')
    if (UPSTREAM/'version').read_text().strip()!=reviewed['version']:
        raise ValueError('Unreviewed app version. Run migrate and review before preparing a build.')
    for rel, record in BASE["files"].items():
        if "sha256" in record and sha(UPSTREAM / rel) != record["sha256"]:
            raise SystemExit(f"Original source changed: {rel}. Migration/review is required.")


def read_translations():
    inventory = json.loads((ROOT / "string-candidates.json").read_text())["records"]
    by_line = collections.defaultdict(list)
    for row in inventory:
        by_line[(Path(row["file"]).name, row["line"])].append(row)
    result = []
    seen = set()
    for table in sorted(CATALOG.glob("*.tsv")):
        for number, line in enumerate(table.read_text().splitlines(), 1):
            if not line or line.startswith("#"):
                continue
            if "\t" not in line:
                raise ValueError(f"Missing tab at {table.name}:{number}")
            selector, target = line.split("\t", 1)
            m = re.fullmatch(r"([^:]+):(\d+)(?:#(\d+))?", selector)
            if not m:
                raise ValueError(f"Invalid selector {selector}")
            file, lineno, nth = m.group(1), int(m.group(2)), int(m.group(3) or 0)
            row = by_line[(file, lineno)][nth]
            identity = (row["file"], row["line"], row["column"])
            if identity in seen:
                raise ValueError(f"Duplicate occurrence: {selector}")
            seen.add(identity)
            original_source=(UPSTREAM / row["file"]).read_text()
            start=offsets(original_source)[row["line"]-1]+row["column"]-1
            prefix=original_source[max(0,start-100):start]
            if re.search(r'\b(?:key|value|symbol|systemImage|systemName|name|id)\s*:\s*$',prefix) and target != row["source_value"]:
                raise ValueError(f"Attempt to translate a protected identifier/default: {selector}")
            glossary=json.loads((ROOT/'terminology.json').read_text())
            protected={k.casefold() for section in ['algorithms','training_terms','technical_units'] for k in glossary[section]}
            if row['source_value'].casefold() in protected and target != row['source_value']:
                # The user's latest explicit preference permits Chinese labels
                # alongside the complete original term, never altering values.
                bilingual=(table.name=='bilingual-labels.tsv' and row['source_value'] in target)
                algorithm=row['source_value'].casefold() in {k.casefold() for k in glossary['algorithms']}
                if not bilingual or algorithm:
                    raise ValueError(f"Attempt to replace a protected technical term: {selector}")
            # All evaluated expressions must survive translation. The only
            # reviewed exceptions remove English grammatical plural suffixes.
            from generate_display import split_template
            original_exprs=collections.Counter(split_template(row['source_value'])[1])
            target_exprs=collections.Counter(split_template(target)[1])
            allowed=collections.Counter(GRAMMATICAL_PLURAL_DROPS.get((file,lineno),[]))
            if original_exprs != target_exprs + allowed:
                raise ValueError(f"Evaluated expression changed in translation: {selector}")
            result.append(dict(row, target_value=target, table=table.name,
                delivery="display_lookup" if table.name == "dynamic-display.tsv" else "compiled_literal"))
    return result


def offsets(source):
    starts = [0] + [m.end() for m in re.finditer("\n", source)]
    return starts


def literal_patch(source, row):
    start = offsets(source)[row["line"] - 1] + row["column"] - 1
    end, value, _ = audit.read_string(source, start)
    if value != row["source_value"]:
        raise ValueError(f"Source occurrence changed: {row['file']}:{row['line']}")
    hashes, quote, content_start = audit.string_start(source, start)
    target = row["target_value"]
    if hashes:
        raise ValueError("Raw-string edits require explicit implementation review.")
    if quote == '"""':
        closing_indent = value.rsplit("\n", 1)[-1]
        target = "\n" + closing_indent + target + "\n" + closing_indent
    close_length = len(quote) + hashes
    replacement = source[start:content_start] + target + source[end-close_length:end]
    return start, end, replacement


def mask_strings(source):
    pieces, i, last = [], 0, 0
    while i < len(source):
        j = audit.skip_comment(source, i)
        if j != i:
            i = j
        elif audit.string_start(source, i):
            end, _, _ = audit.read_string(source, i)
            pieces.extend([source[last:i], '"<display-literal>"'])
            i = last = end
        else:
            i += 1
    pieces.append(source[last:])
    return "".join(pieces)


def prepare():
    check_upstream()
    if WORK.exists():
        raise ValueError('Output already exists; choose a fresh --output directory.')
    if WORK == UPSTREAM or WORK in UPSTREAM.parents or UPSTREAM in WORK.parents:
        raise ValueError('Output and original source must be separate trees.')
    entries = read_translations()
    if not WORK.exists():
        shutil.copytree(UPSTREAM, WORK, ignore=shutil.ignore_patterns(".git", "__pycache__", "._*"))
    grouped = collections.defaultdict(list)
    for row in entries:
        if row["delivery"] == "compiled_literal":
            grouped[row["file"]].append(row)
    for rel in BASE["files"]:
        if rel.endswith(".swift"):
            original = (UPSTREAM / rel).read_text()
            patches = [literal_patch(original, row) for row in grouped[rel]]
            localized = original
            for start, end, replacement in sorted(patches, reverse=True):
                localized = localized[:start] + replacement + localized[end:]
            if mask_strings(original) != mask_strings(localized):
                raise ValueError(f"Non-string code changed: {rel}")
            (WORK / rel).write_text(localized)
    # Reviewed display-boundary wrappers are separate from literal translation.
    boundaries = []
    for name in ["display-boundaries.json", "ui-improvements.json", "input-feedback.json"]:
        extra = ROOT / name
        boundaries.extend(json.loads(extra.read_text()))
    for edit in boundaries:
        p = WORK / edit["file"]
        source = p.read_text()
        actual = source.count(edit["before"])
        if actual != edit["count"]:
            raise ValueError(f"Display boundary changed ({actual}): {edit['before']}")
        p.write_text(source.replace(edit["before"], edit["after"]))
    # Separately reviewed metric-display repairs; these are not translations.
    metric_fixes = json.loads((ROOT / "metric-display-fixes.json").read_text())
    for edit in metric_fixes:
        p = WORK / edit["file"]
        source = p.read_text()
        actual = source.count(edit["before"])
        if actual != edit["count"]:
            raise ValueError(f"Metric display repair boundary changed ({actual}): {edit['file']}")
        p.write_text(source.replace(edit["before"], edit["after"]))
    from generate_display import generate
    for p in (ROOT / "native").glob("*.swift"):
        shutil.copy2(p, WORK / "Sources/MLXLoRAStudio/Views" / p.name)
    generate(entries, destination=WORK/"Sources/MLXLoRAStudio/Views")
    shutil.copy2(PROJECT / "Tests/MLXLoRAStudioTests/MetricsReadingTests.swift",
                 WORK / "Tests/MLXLoRAStudioTests/MetricsReadingTests.swift")
    report = {
        "app_version": (UPSTREAM/"version").read_text().strip(), "source_commit": BASE["commit"],
        "translated_occurrences": len(entries), "translated_source_files": sum(bool(x) for x in grouped.values()),
        "compiled_literal_occurrences": sum(x["delivery"] == "compiled_literal" for x in entries),
        "display_lookup_templates": sum(x["delivery"] == "display_lookup" for x in entries),
        "display_boundary_edits": len(boundaries),
        "interpolation_expressions_preserved_except_reviewed_grammatical_plural_suffixes": True,
        "reviewed_grammatical_plural_suffixes_removed": sum(map(len,GRAMMATICAL_PLURAL_DROPS.values())),
        "reviewed_presentation_edit_occurrences": sum(x['count'] for x in boundaries),
        "reviewed_metric_display_repairs": len(metric_fixes),
        "reviewed_metric_display_repair_occurrences": sum(x['count'] for x in metric_fixes),
        "metric_display_repairs_sha256": sha(ROOT / "metric-display-fixes.json"),
        "metric_display_helper_sha256": sha(ROOT / "native/StudioMetricReadings.swift"),
        "non_string_code_unchanged_before_reviewed_display_wrappers": True,
        "backend_unchanged": all(sha(UPSTREAM / rel) == sha(WORK / rel)
            for rel in BASE["files"] if rel.startswith("Backend/")),
    }
    (WORK / "localization-build.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))


def migration(source):
    """Emit a report only. Never patch or build an unreviewed app version."""
    source = Path(source).resolve()
    entries = json.loads((CATALOG/'entries.json').read_text())
    reusable, missing = [], []
    for entry in entries:
        p = source / entry["file"]
        values = [x["source_value"] for x in audit.strings_in_file(p)] if p.exists() else []
        # audit.strings_in_file needs SOURCE for relative paths.
        destination = reusable if entry["source_value"] in values else missing
        destination.append({"file": entry["file"], "source_value": entry["source_value"]})
    old_values=collections.defaultdict(set)
    for row in json.loads((ROOT/'string-candidates.json').read_text())['records']:
        old_values[row['file']].add(row['source_value'])
    added=[]
    for path in sorted((source/'Sources/MLXLoRAStudio').rglob('*.swift')):
        for row in audit.strings_in_file(path):
            if row['source_value'] not in old_values[row['file']] and row['classification']=='display_candidate':
                added.append({'file':row['file'],'line':row['line'],'source_value':row['source_value']})
    patch_files=sorted({edit['file'] for name in ('display-boundaries.json','ui-improvements.json','input-feedback.json','metric-display-fixes.json')
                        for edit in json.loads((ROOT/name).read_text())})
    changed_patch_files=[rel for rel in patch_files if not (source/rel).is_file() or sha(source/rel)!=BASE['files'][rel]['sha256']]
    protected_changes=[rel for rel in BASE['files'] if (rel.startswith('Backend/') or '/Models/' in rel)
                       and (not (source/rel).is_file() or sha(source/rel)!=BASE['files'][rel]['sha256'])]
    report = {"status": "review_required_no_changes_applied", "source":str(source),
        "reusable_count":len(reusable),"missing_or_changed_count":len(missing),"new_display_candidates_count":len(added),
        "reusable": reusable, "missing_or_changed": missing,"new_display_candidates":added,
        "changed_patch_files_requiring_review":changed_patch_files,
        "protected_backend_or_model_files_changed":protected_changes,
        "automatic_approval":False}
    print(json.dumps(report, ensure_ascii=False, indent=2))


def verify_committed():
    global WORK
    if json.loads((CATALOG/'entries.json').read_text())!=read_translations():
        raise ValueError('Translation entries and TSV catalogs differ; regenerate catalog explicitly after review.')
    with tempfile.TemporaryDirectory(prefix='mlx-zh-verify-') as temporary:
        WORK=Path(temporary)/'source'
        prepare()
        for folder in ('Sources/MLXLoRAStudio','Backend','Tests'):
            generated={str(p.relative_to(WORK/folder)):sha(p) for p in (WORK/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
            committed={str(p.relative_to(PROJECT/folder)):sha(p) for p in (PROJECT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
            if generated!=committed:
                raise ValueError('Committed files differ from reviewed localization: '+folder)
    print('Committed source exactly reproduces reviewed localization; Backend unchanged.')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=['prepare','verify','migrate','catalog'])
    parser.add_argument('--source',type=Path,default=UPSTREAM)
    parser.add_argument('--output',type=Path,default=WORK)
    args=parser.parse_args()
    UPSTREAM=args.source.resolve()
    WORK=args.output.resolve()
    audit.SOURCE=UPSTREAM
    if args.mode=='prepare':prepare()
    elif args.mode=='verify':verify_committed()
    elif args.mode=='migrate':migration(UPSTREAM)
    else:
        check_upstream()
        (CATALOG/'entries.json').write_text(json.dumps(read_translations(),ensure_ascii=False,indent=2)+'\n')
