#!/usr/bin/env python3
"""Generate unapproved candidate manifests in a new directory; never change the active lock."""
from pathlib import Path
import argparse
import json
import plistlib
import re
import tempfile
import build
import swift_lex

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--commit',required=True)
    parser.add_argument('--original-app',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if not re.fullmatch(r'[0-9a-f]{40}',args.commit):raise SystemExit('Use a complete official commit SHA.')
    source=args.source.resolve();app=args.original_app.resolve();output=args.output.resolve()
    if output.exists() or source==output or app==output or source in output.parents or app in output.parents:
        raise SystemExit('Choose a new output directory separate from the source and application.')
    for required in ('version','Package.swift','Sources/MLXLoRAStudio','Backend'):
        if not (source/required).exists():raise SystemExit('Candidate source missing: '+required)
    version=(source/'version').read_text().strip()
    info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
    if info.get('CFBundleShortVersionString')!=version:raise SystemExit('Candidate source/app versions differ.')
    files={}
    for path in sorted(source.rglob('*')):
        rel=path.relative_to(source)
        if any(p in {'.git','__pycache__','.DS_Store'} or p.startswith('._') for p in rel.parts):continue
        if path.is_symlink():raise SystemExit('Candidate source symlink requires separate review: '+rel.as_posix())
        if path.is_file():files[rel.as_posix()]={'size':path.stat().st_size,'sha256':build.digest(path)}
    swift_lex.SOURCE=source
    records=[row for path in sorted((source/'Sources/MLXLoRAStudio').rglob('*.swift'))
             for row in swift_lex.strings_in_file(path)]
    app_files=build.manifest(app)
    caches={p:v for p,v in app_files.items() if '__pycache__' in Path(p).parts and p.endswith('.pyc')}
    canonical={p:v for p,v in app_files.items() if p not in caches}
    output.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.candidate-review-',dir=output.parent) as temporary:
        stage=Path(temporary)/'review';stage.mkdir()
        data={'source-baseline.json':{'commit':args.commit,'files':files},
              'string-candidates.json':{'method':'Swift lexical inventory; not confirmed UI coverage','records':records},
              'original-app-manifest.json':canonical,'optional-app-cache-manifest.json':caches}
        for name,value in data.items():
            (stage/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
        metadata={'status':'unreviewed_candidate','automatically_approved':False,
                  'version':version,'declared_official_commit':args.commit,
                  'source_manifest_sha256':build.digest(stage/'source-baseline.json'),
                  'original_app_manifest_sha256':build.digest(stage/'original-app-manifest.json'),
                  'optional_app_cache_manifest_sha256':build.digest(stage/'optional-app-cache-manifest.json'),
                  'active_version_lock_modified':False,'application_started':False}
        (stage/'candidate-metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
        stage.rename(output)
    print('Unapproved candidate manifests generated. Review them before changing the active version lock.')

if __name__=='__main__':main()
