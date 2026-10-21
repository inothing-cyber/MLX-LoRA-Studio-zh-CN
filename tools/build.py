#!/usr/bin/env python3
"""Build into a fresh directory from a reviewed official app. Never install or launch."""
from pathlib import Path
import argparse
import hashlib
import json
import plistlib
import shutil
import subprocess
import sys
import tempfile
import localize
from upstream import read_lock

PROJECT=Path(__file__).resolve().parents[1]

def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def manifest(root):
    result={}
    for path in sorted(Path(root).rglob('*')):
        rel=path.relative_to(root)
        if any(p.startswith('._') or p=='.DS_Store' for p in rel.parts):continue
        if path.is_symlink():result[rel.as_posix()]={'symlink':str(path.readlink())}
        elif path.is_file():result[rel.as_posix()]={'size':path.stat().st_size,'sha256':digest(path)}
    return result

def verify_original(app,lock):
    table=PROJECT/'localization/original-app-manifest.json'
    if digest(table)!=lock['original_app_manifest_sha256']:raise ValueError('Unreviewed original app manifest')
    expected=json.loads(table.read_text())
    actual=manifest(app)
    optional={}
    if 'optional_app_cache_manifest_sha256' in lock:
        cache_table=PROJECT/'localization/optional-app-cache-manifest.json'
        if digest(cache_table)!=lock['optional_app_cache_manifest_sha256']:raise ValueError('Unreviewed cache manifest')
        optional=json.loads(cache_table.read_text())
    changed=[p for p in expected if actual.get(p)!=expected[p]]
    extra=[p for p in actual if p not in expected and actual[p]!=optional.get(p)]
    if changed or extra:raise ValueError('Official app content differs from the reviewed baseline; do not build this version.')
    info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
    if info['CFBundleShortVersionString']!=lock['version']:raise ValueError('Unreviewed official app version')
    return actual

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--original-app',type=Path,required=True)
    parser.add_argument('--source',type=Path,default=PROJECT/'.cache/upstream')
    parser.add_argument('--output',type=Path,default=PROJECT/'dist')
    args=parser.parse_args()
    if sys.platform!='darwin':raise SystemExit('Building the macOS app requires macOS and Xcode.')
    original=args.original_app.resolve();destination=args.output.resolve()
    if destination.exists():raise SystemExit('Output exists. Choose a fresh --output directory.')
    if original in destination.parents:raise SystemExit('Output must not be inside the official app.')
    lock=read_lock()
    expected=verify_original(original,lock)
    localize.UPSTREAM=args.source.resolve();localize.audit.SOURCE=localize.UPSTREAM
    localize.verify_committed()
    destination.parent.mkdir(parents=True,exist_ok=True)
    # Stage on macOS's temporary filesystem so archive modes remain correct
    # even when the repository is on a volume that synthesizes Unix modes.
    with tempfile.TemporaryDirectory(prefix='mlx-zh-build-') as temporary:
        stage=Path(temporary)/'release';stage.mkdir()
        app=stage/'MLX LoRA Studio 中文版.app'
        shutil.copytree(original,app,symlinks=True)
        binary=app/'Contents/MacOS/MLXLoRAStudio'
        cache=Path(temporary)/'module-cache'
        sources=sorted(p.relative_to(PROJECT).as_posix() for p in (PROJECT/'Sources/MLXLoRAStudio').rglob('*.swift'))
        command=['xcrun','swiftc','-target','arm64-apple-macosx14.0',
                 '-module-cache-path',str(cache),'-file-prefix-map',str(PROJECT)+'=.',
                 '-debug-prefix-map',str(PROJECT)+'=.',
                 '-file-prefix-map',str(Path.home())+'=/build-user',
                 *sources,'-o',str(binary),'-framework','SwiftUI','-framework','AppKit','-framework','UserNotifications']
        subprocess.run(command,cwd=PROJECT,check=True)
        if str(Path.home()).encode() in binary.read_bytes() or str(PROJECT).encode() in binary.read_bytes():
            raise ValueError('Compiler embedded a personal build path; packaging stopped.')
        info_path=app/'Contents/Info.plist'
        info=plistlib.loads(info_path.read_bytes())
        info['CFBundleDevelopmentRegion']='zh-Hans';info['CFBundleLocalizations']=['zh-Hans']
        info_path.write_bytes(plistlib.dumps(info,sort_keys=False))
        resources=app/'Contents/Resources'
        language=resources/'zh-Hans.lproj';language.mkdir(exist_ok=True)
        (language/'InfoPlist.strings').write_text('"CFBundleDisplayName" = "MLX LoRA Studio";\n')
        notices=resources/'OpenSourceLicenses';notices.mkdir()
        shutil.copy2(PROJECT/'LICENSE',notices/'MLX-LoRA-Studio-MIT.txt')
        shutil.copy2(PROJECT/'licenses/mlx-lm-lora-Apache-2.0.txt',notices/'mlx-lm-lora-Apache-2.0.txt')
        shutil.copy2(PROJECT/'NOTICE',notices/'NOTICE')
        marker={'app_version':lock['version'],'locale':'zh-Hans','source_commit':lock['commit'],
                'localization_revision':lock['translation_revision'],'unofficial':True,
                'catalog_sha256':digest(PROJECT/'localization/catalog/entries.json'),
                'updater_policy':'New upstream versions require review, tests and a separate release.'}
        (resources/'ChineseLocalization.json').write_text(json.dumps(marker,ensure_ascii=False,indent=2)+'\n')
        for path in [app,*app.rglob('*')]:
            if path.is_symlink():continue
            reference=original/path.relative_to(app)
            mode=(reference.stat().st_mode&0o777) if reference.exists() else (0o755 if path.is_dir() else 0o644)
            path.chmod(mode)
        binary.chmod(0o755)
        subprocess.run(['codesign','--force','--deep','--sign','-',str(app)],check=True)
        subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
        support=Path('Contents/Resources/StudioSupport')
        if manifest(app/support)!=manifest(original/support):raise ValueError('Backend payload changed')
        if manifest(original)!=expected:raise ValueError('Official app changed during build')
        archive=stage/('MLX-LoRA-Studio-zh-CN-'+lock['version']+'-'+lock['translation_revision']+'.app.zip')
        subprocess.run(['ditto','-c','-k','--keepParent',str(app),str(archive)],check=True)
        (stage/'SHA256SUMS').write_text(digest(archive)+'  '+archive.name+'\n')
        report={'app_version':lock['version'],'translation_revision':lock['translation_revision'],
                'source_commit':lock['commit'],'backend_file_count':len(manifest(app/support)),
                'backend_bytes_unchanged':True,'official_app_unchanged':True,
                'native_sha256':digest(binary),'archive_sha256':digest(archive),
                'signature':'local ad-hoc; not notarized','installed_or_launched':False,
                'personal_build_paths_in_native_binary':False,
                'archive_binary_mode':oct(binary.stat().st_mode&0o777),
                'archive_info_plist_mode':oct(info_path.stat().st_mode&0o777)}
        (stage/'build-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
        with tempfile.TemporaryDirectory(prefix='.mlx-zh-export-',dir=destination.parent) as export:
            transfer=Path(export)/'release'
            shutil.copytree(stage,transfer,symlinks=True)
            if manifest(transfer)!=manifest(stage):raise ValueError('Output copy verification failed')
            transfer.rename(destination)
    print('Built verified app and ZIP in the selected output directory. Nothing installed or launched.')

if __name__=='__main__':main()
