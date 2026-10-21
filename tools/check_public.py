#!/usr/bin/env python3
"""Check publishable files for private paths, credentials and local artifacts."""
import argparse
import json
from pathlib import Path
import re
import subprocess

PROJECT=Path(__file__).resolve().parents[1]
IGNORED={'.git','.build','.cache','dist','__pycache__','.swiftpm'}
FORBIDDEN={'audit','baselines','preview','vendor'}
PATTERNS={
    'personal home path':re.compile(rb'/(?:Users|home)/[^/\s"<>]+/'),
    'external volume path':re.compile(rb'/(?:Volumes)/[^/\n"<>]+/'),
    'GitHub credential':re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,})'),
    'Hugging Face credential':re.compile(rb'hf_[A-Za-z0-9]{25,}'),
    'API credential':re.compile(rb'\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{20,}'),
    'private key':re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
}

def findings(root):
    root=Path(root);issues=[]
    tracked=set()
    if (root/'.git').exists():
        result=subprocess.run(['git','ls-files','-z'],cwd=root,capture_output=True,check=True)
        tracked={Path(p.decode()) for p in result.stdout.split(b'\0') if p}
    for path in sorted(root.rglob('*')):
        rel=path.relative_to(root)
        if '.git' in rel.parts:continue
        ignored=any(part in IGNORED for part in rel.parts)
        if ignored and rel not in tracked:continue
        if path.is_symlink():
            issues.append({'file':rel.as_posix(),'reason':'symlink requires explicit review'})
            continue
        if not path.is_file():continue
        reasons=[]
        if path.name=='.env' or path.name.startswith('.env.'):reasons.append('environment credential file')
        if ignored or any(part in FORBIDDEN or part.endswith('.app') for part in rel.parts):reasons.append('local artifact directory')
        if path.suffix.lower() in {'.pyc','.log','.safetensors','.gguf','.dmg','.zip','.gz','.p12','.pem','.key'}:reasons.append('private/build/model artifact type')
        if path.stat().st_size>25*1024*1024:reasons.append('unexpected large repository file')
        data=path.read_bytes()
        for name,pattern in PATTERNS.items():
            if pattern.search(data):reasons.append(name)
        if reasons:issues.append({'file':rel.as_posix(),'reasons':reasons})
    return issues

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=PROJECT)
    args=parser.parse_args()
    issues=findings(args.root)
    print(json.dumps({'findings':issues,'passed':not issues},ensure_ascii=False,indent=2))
    if issues:raise SystemExit(1)

if __name__=='__main__':main()
