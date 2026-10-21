#!/usr/bin/env python3
"""Read official releases and download source; never approve, install or run it."""
from __future__ import annotations
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import ssl
import tarfile
import tempfile
from urllib.parse import quote
from urllib.request import Request, urlopen

PROJECT=Path(__file__).resolve().parents[1]
LOCK=PROJECT/'localization/reviewed-upstream.json'
REPOSITORY='Goekdeniz-Guelmez/MLX-LoRA-Studio'
API='https://api.github.com/repos/'+REPOSITORY
MAX_ARCHIVE=80*1024*1024
MAX_EXTRACTED=256*1024*1024

def tls_context():
    context=ssl.create_default_context()
    # Some framework Python installations have no bundled CA store. Use the
    # operating system's trusted CA bundle without changing global settings.
    system_bundle=Path('/etc/ssl/cert.pem')
    if not context.get_ca_certs() and system_bundle.is_file():
        context.load_verify_locations(cafile=str(system_bundle))
    return context

def read_lock():
    value=json.loads(LOCK.read_text())
    if value['repository']!=REPOSITORY:raise ValueError('Unexpected upstream repository')
    if not re.fullmatch(r'[0-9a-f]{40}',value['commit']):raise ValueError('Invalid reviewed commit')
    return value

def api_json(path):
    headers={'Accept':'application/vnd.github+json','User-Agent':'MLX-LoRA-Studio-zh-CN-update-check'}
    token=os.environ.get('GH_TOKEN')
    if token:headers['Authorization']='Bearer '+token
    with urlopen(Request(API+path,headers=headers),timeout=20,context=tls_context()) as response:
        raw=response.read(5*1024*1024+1)
    if len(raw)>5*1024*1024:raise ValueError('GitHub API response exceeds bound')
    return json.loads(raw)

def resolve_tag(tag):
    obj=api_json('/git/ref/tags/'+quote(tag,safe=''))['object']
    for _ in range(6):
        sha=obj.get('sha','')
        if not re.fullmatch(r'[0-9a-f]{40}',sha):raise ValueError('Invalid upstream object SHA')
        if obj.get('type')=='commit':return sha
        if obj.get('type')!='tag':raise ValueError('Release tag does not resolve to a commit')
        obj=api_json('/git/tags/'+sha)['object']
    raise ValueError('Too many annotated tag indirections')

def version_tuple(tag):
    match=re.fullmatch(r'v?(\d+)\.(\d+)\.(\d+)',tag)
    return tuple(map(int,match.groups())) if match else None

def release_report(release,lock,resolver=resolve_tag):
    tag=release.get('tag_name','')
    if not isinstance(tag,str) or len(tag)>120:raise ValueError('Invalid release tag')
    result={'repository':REPOSITORY,'reviewed_tag':lock['tag'],'reviewed_commit':lock['commit'],
            'latest_official_tag':tag,'changes_applied':False,'automatic_release':False,
            'upstream_url':'https://github.com/'+REPOSITORY+'/releases/tag/'+quote(tag,safe='')}
    if release.get('draft') or release.get('prerelease'):
        result.update(status='non_stable_release_ignored',requires_review=False)
        return result
    latest_version=version_tuple(tag)
    reviewed_version=version_tuple(lock['tag'])
    if latest_version is None:
        result.update(status='unrecognized_version_requires_review',requires_review=True)
        return result
    if reviewed_version is not None and latest_version<reviewed_version:
        result.update(status='official_latest_older_than_reviewed_pin',requires_review=False)
        return result
    commit=resolver(tag)
    result['latest_official_commit']=commit
    if tag==lock['tag'] and commit==lock['commit']:
        result.update(status='reviewed_version_current',requires_review=False)
    elif tag==lock['tag']:
        result.update(status='reviewed_tag_moved_requires_review',requires_review=True)
    else:
        result.update(status='new_version_requires_review',requires_review=True)
    return result

def safe_extract(data,destination):
    destination=Path(destination)
    if destination.exists():raise ValueError('Destination already exists; choose a new directory')
    destination.parent.mkdir(parents=True,exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(data),mode='r:gz') as archive:
        members=archive.getmembers()
        if not members or len(members)>20000:raise ValueError('Invalid source archive member count')
        total=sum(m.size for m in members)
        if total>MAX_EXTRACTED:raise ValueError('Source archive exceeds extracted size bound')
        top=None;seen=set();validated=[]
        for member in members:
            path=PurePosixPath(member.name)
            if path.is_absolute() or '..' in path.parts or '\\' in member.name:
                raise ValueError('Unsafe archive path')
            if not path.parts:raise ValueError('Empty archive path')
            if top is None:top=path.parts[0]
            if path.parts[0]!=top:raise ValueError('Archive must have one root directory')
            if not (member.isdir() or member.isfile()):raise ValueError('Source links/special entries are not accepted')
            rel=Path(*path.parts[1:])
            if rel in seen:raise ValueError('Duplicate archive member')
            seen.add(rel);validated.append((member,rel))
        with tempfile.TemporaryDirectory(prefix='.upstream-source-',dir=destination.parent) as temporary:
            stage=Path(temporary)/'source';stage.mkdir()
            for member,rel in validated:
                target=stage/rel
                if member.isdir():target.mkdir(parents=True,exist_ok=True)
                else:
                    target.parent.mkdir(parents=True,exist_ok=True)
                    with archive.extractfile(member) as source, target.open('xb') as output:
                        while chunk:=source.read(1024*1024):output.write(chunk)
                    target.chmod(0o755 if member.mode&0o111 else 0o644)
            stage.rename(destination)

def verify_reviewed_source(source):
    baseline=json.loads((PROJECT/'localization/source-baseline.json').read_text())
    for rel,record in baseline['files'].items():
        path=Path(source)/rel
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=record['sha256']:
            raise ValueError('Reviewed source mismatch: '+rel)

def fetch(commit,destination):
    if not re.fullmatch(r'[0-9a-f]{40}',commit):raise ValueError('Use a complete 40-character commit SHA')
    if Path(destination).exists():raise ValueError('Destination already exists')
    url='https://codeload.github.com/'+REPOSITORY+'/tar.gz/'+commit
    # Public source download never receives the API authorization header.
    with urlopen(Request(url,headers={'User-Agent':'MLX-LoRA-Studio-zh-CN'}),timeout=30,context=tls_context()) as response:
        data=response.read(MAX_ARCHIVE+1)
    if len(data)>MAX_ARCHIVE:raise ValueError('Source download exceeds size bound')
    safe_extract(data,destination)
    if commit==read_lock()['commit']:verify_reviewed_source(destination)
    return {'repository':REPOSITORY,'commit':commit,'source_archive_sha256':hashlib.sha256(data).hexdigest(),
            'source_downloaded':True,'code_executed':False,'reviewed_pin_changed':False}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='mode',required=True)
    check=sub.add_parser('check')
    check.add_argument('--output',type=Path,default=PROJECT/'.build/upstream-review.json')
    check.add_argument('--fail-on-update',action='store_true')
    download=sub.add_parser('fetch')
    download.add_argument('--commit',default=None)
    download.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    lock=read_lock()
    if args.mode=='fetch':
        print(json.dumps(fetch(args.commit or lock['commit'],args.output),ensure_ascii=False,indent=2))
        return
    report=release_report(api_json('/releases/latest'),lock)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    summary=os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary,'a') as output:
            output.write('## 官方版本检查\n\n已适配：`'+lock['tag']+'`\n\n官方最新稳定版：`'+report['latest_official_tag']+'`\n\n状态：`'+report['status']+'`\n\n不会自动套用补丁、合并或发布。\n')
    print(json.dumps(report,ensure_ascii=False,indent=2))
    if args.fail_on_update and report['requires_review']:raise SystemExit(2)

if __name__=='__main__':main()
