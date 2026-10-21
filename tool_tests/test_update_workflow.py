import io
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import ssl
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import upstream
import check_public
import build
import localize

class ReleaseChecks(unittest.TestCase):
    def setUp(self):
        self.lock={'tag':'v2.0.3','commit':'a'*40}

    def report(self,tag,commit='a'*40,**extra):
        return upstream.release_report({'tag_name':tag,**extra},self.lock,lambda _:commit)

    def test_same_version_and_commit_needs_no_review(self):
        self.assertFalse(self.report('v2.0.3')['requires_review'])

    def test_tls_always_verifies_certificate_and_hostname(self):
        context=upstream.tls_context()
        self.assertTrue(context.check_hostname)
        self.assertEqual(context.verify_mode,ssl.CERT_REQUIRED)

    def test_new_version_requires_review_without_changing_pin(self):
        original=dict(self.lock)
        result=self.report('v2.0.4','b'*40)
        self.assertTrue(result['requires_review'])
        self.assertFalse(result['changes_applied'])
        self.assertEqual(self.lock,original)

    def test_moved_tag_requires_review(self):
        self.assertEqual(self.report('v2.0.3','b'*40)['status'],'reviewed_tag_moved_requires_review')

    def test_older_official_release_never_downgrades(self):
        def no_resolve(_):raise AssertionError('Older release should not be resolved or applied')
        result=upstream.release_report({'tag_name':'v2.0.2'},self.lock,no_resolve)
        self.assertFalse(result['requires_review'])
        self.assertIn('older',result['status'])

    def test_prerelease_is_ignored(self):
        self.assertFalse(self.report('v3.0.0-beta',prerelease=True)['requires_review'])

    def test_unrecognized_release_requires_human_review(self):
        self.assertTrue(self.report('future-release')['requires_review'])

    def test_annotated_tag_resolves_to_commit(self):
        with patch.object(upstream,'api_json',side_effect=[
            {'object':{'type':'tag','sha':'b'*40}},
            {'object':{'type':'commit','sha':'c'*40}}]):
            self.assertEqual(upstream.resolve_tag('v2.0.3'),'c'*40)

    def test_tag_loop_is_bounded(self):
        with patch.object(upstream,'api_json',return_value={'object':{'type':'tag','sha':'b'*40}}):
            with self.assertRaises(ValueError):upstream.resolve_tag('v2.0.3')

class SourceArchiveChecks(unittest.TestCase):
    def archive(self,entries):
        stream=io.BytesIO()
        with tarfile.open(fileobj=stream,mode='w:gz') as archive:
            for name,kind in entries:
                member=tarfile.TarInfo(name)
                if kind=='file':
                    member.size=2;archive.addfile(member,io.BytesIO(b'ok'))
                else:
                    member.type=tarfile.SYMTYPE if kind=='symlink' else tarfile.LNKTYPE
                    member.linkname='../outside';archive.addfile(member)
        return stream.getvalue()

    def test_normal_archive_extracts_into_new_directory(self):
        with tempfile.TemporaryDirectory() as temp:
            output=Path(temp)/'source'
            upstream.safe_extract(self.archive([('root/LICENSE','file')]),output)
            self.assertEqual((output/'LICENSE').read_bytes(),b'ok')

    def test_unsafe_archive_never_creates_destination(self):
        cases=[ [('root/../outside','file')], [('/root/file','file')],
                [('root/link','symlink')], [('root/link','hardlink')],
                [('root/file','file'),('root/file','file')],
                [('one/file','file'),('two/file','file')] ]
        for entries in cases:
            with self.subTest(entries=entries),tempfile.TemporaryDirectory() as temp:
                output=Path(temp)/'source'
                with self.assertRaises(ValueError):upstream.safe_extract(self.archive(entries),output)
                self.assertFalse(output.exists())

    def test_existing_destination_is_preserved(self):
        with tempfile.TemporaryDirectory() as temp:
            output=Path(temp)/'source';output.mkdir()
            (output/'mine').write_text('keep')
            with self.assertRaises(ValueError):upstream.safe_extract(self.archive([('root/file','file')]),output)
            self.assertEqual((output/'mine').read_text(),'keep')

class PrivacyChecks(unittest.TestCase):
    def test_environment_files_are_rejected_even_without_known_token_format(self):
        with tempfile.TemporaryDirectory() as temp:
            (Path(temp)/'.env').write_text('EXAMPLE_PASSWORD=example')
            self.assertTrue(check_public.findings(temp))

    def test_private_paths_and_fake_tokens_are_detected(self):
        examples=['/'+ 'Users'+'/example/private',('gh'+'p_')+'x'*36,('hf'+'_')+'y'*30]
        for example in examples:
            with self.subTest(example_type=example[:3]),tempfile.TemporaryDirectory() as temp:
                (Path(temp)/'example.txt').write_text(example)
                self.assertTrue(check_public.findings(temp))

    def test_local_build_outputs_are_excluded_from_source_scan(self):
        with tempfile.TemporaryDirectory() as temp:
            folder=Path(temp)/'dist';folder.mkdir()
            (folder/'app.zip').write_bytes(b'not a published source file')
            self.assertFalse(check_public.findings(temp))

    def test_force_tracked_ignored_artifacts_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            subprocess.run(['git','init','-q',temp],check=True)
            folder=Path(temp)/'dist';folder.mkdir()
            (folder/'app.zip').write_bytes(b'example')
            subprocess.run(['git','add','-f','dist/app.zip'],cwd=temp,check=True)
            self.assertTrue(check_public.findings(temp))

class OfficialBundleChecks(unittest.TestCase):
    def test_only_exact_reviewed_optional_cache_is_accepted(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);loc=root/'localization';loc.mkdir()
            app=root/'Original.app';(app/'Contents').mkdir(parents=True)
            (app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString':'2.0.3'}))
            table=loc/'original-app-manifest.json';table.write_text(json.dumps(build.manifest(app)))
            cache=app/'Contents/__pycache__/sample.pyc';cache.parent.mkdir()
            cache.write_bytes(b'reviewed cache example')
            optional={k:v for k,v in build.manifest(app).items() if '__pycache__' in k}
            cache_table=loc/'optional-app-cache-manifest.json';cache_table.write_text(json.dumps(optional))
            lock={'original_app_manifest_sha256':build.digest(table),'version':'2.0.3',
                  'optional_app_cache_manifest_sha256':build.digest(cache_table)}
            with patch.object(build,'PROJECT',root):
                build.verify_original(app,lock)
                cache.write_bytes(b'modified cache')
                with self.assertRaises(ValueError):build.verify_original(app,lock)

    def test_unreviewed_source_version_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            source=Path(temp)
            (source/'version').write_text('9.9.9')
            with patch.object(localize,'UPSTREAM',source):
                with self.assertRaises(ValueError):localize.check_upstream()

    def test_app_manifest_change_is_not_silently_accepted(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);loc=root/'localization';loc.mkdir()
            table=loc/'original-app-manifest.json';table.write_text('{}')
            with patch.object(build,'PROJECT',root):
                with self.assertRaises(ValueError):build.verify_original(root/'not-an-app',{'original_app_manifest_sha256':'0'*64})

    def test_modified_official_payload_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);loc=root/'localization';loc.mkdir()
            app=root/'Original.app';(app/'Contents').mkdir(parents=True)
            (app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString':'2.0.3'}))
            table=loc/'original-app-manifest.json'
            table.write_text(json.dumps(build.manifest(app)))
            lock={'original_app_manifest_sha256':build.digest(table),'version':'2.0.3'}
            with patch.object(build,'PROJECT',root):
                build.verify_original(app,lock)
                (app/'Contents/extra.txt').write_text('changed')
                with self.assertRaises(ValueError):build.verify_original(app,lock)

if __name__=='__main__':unittest.main()
