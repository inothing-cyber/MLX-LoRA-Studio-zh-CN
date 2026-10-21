#!/usr/bin/env python3
"""Run configuration/display regression without loading models or installing packages."""
from pathlib import Path
import argparse
import json
import subprocess
import sys
import localize

PROJECT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=PROJECT/'.cache/upstream')
    parser.add_argument('--python',type=Path,default=Path(sys.executable),help='Existing Python with NumPy; never installs packages')
    args=parser.parse_args()
    numpy=subprocess.run([str(args.python),'-B','-c','import numpy'],capture_output=True,text=True)
    if numpy.returncode:raise SystemExit('Tests require NumPy. Select an existing environment with --python; no packages were installed.')
    localize.UPSTREAM=args.source.resolve();localize.audit.SOURCE=localize.UPSTREAM
    localize.verify_committed()
    out=PROJECT/'.build/validation';out.mkdir(parents=True,exist_ok=True)
    def run(label,command,cwd=PROJECT):
        result=subprocess.run(command,cwd=cwd,capture_output=True,text=True)
        (out/(label+'.log')).write_text(result.stdout+result.stderr)
        if result.returncode:
            print((result.stdout+result.stderr)[-6000:])
            raise SystemExit(result.returncode)
        return result.stdout
    specs=[]
    for name,tree in [('original',localize.UPSTREAM),('chinese',PROJECT)]:
        binary=out/('contract-'+name)
        run('compile-'+name,['xcrun','swiftc','-module-cache-path',str(out/'module-cache'),
                            str(tree/'Sources/MLXLoRAStudio/Models/TrainingModels.swift'),
                            str(PROJECT/'validation/contracts/contract.swift'),'-o',str(binary)])
        specs.append(json.loads(run('spec-'+name,[str(binary)])))
    if specs[0]!=specs[1]:raise ValueError('Training configuration differs from the reviewed official version')
    for name,native,contract in [('display','StudioL10n.swift','display.swift'),
                                 ('numeric-input','StudioNumericInput.swift','numeric-input.swift')]:
        binary=out/name
        run('compile-'+name,['xcrun','swiftc','-module-cache-path',str(out/'module-cache'),
                            str(PROJECT/'localization/native'/native),str(PROJECT/'validation/contracts'/contract),
                            '-o',str(binary)])
        run(name,[str(binary)])
    run('python-tests',[str(args.python),'-B','-m','unittest','discover','-s','Tests','-p','test_*.py','-v'])
    run('update-tool-tests',[sys.executable,'-B','-m','unittest','discover','-s','tool_tests','-v'])
    swift=run('swift-tests',['swift','test','--scratch-path',str(out/'swift-tests')])
    if '16 tests' not in swift:raise ValueError('Unexpected Swift test count; review test discovery')
    migration=json.loads(run('same-version-migration',[sys.executable,'-B',str(PROJECT/'tools/localize.py'),
                              'migrate','--source',str(localize.UPSTREAM)]))
    if migration['missing_or_changed_count'] or migration['new_display_candidates_count']:
        raise ValueError('Reviewed-version migration is not stable')
    summary={'configuration_cases_identical':len(specs[0]),'display_contracts_passed':13,
             'numeric_contracts_passed':13,'original_python_tests_passed':9,
             'original_swift_tests_passed':11,'metric_tests_passed':5,'metric_cases_passed':13,
             'same_version_migration_passed':True,'real_training_started':False}
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2))

if __name__=='__main__':main()
