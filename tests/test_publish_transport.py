import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.request import Request
from urllib.error import HTTPError
import publish_v1344_once as p

class Transport(unittest.TestCase):
    def test_cross_host_redirect_strips_auth(self):
        request=Request('https://api.github.com/repos/a/b/releases/assets/1',headers={'Authorization':'Bearer dummy-test'})
        redirect=p.SafeRedirects().redirect_request(request,None,302,'',{},'https://release-assets.githubusercontent.com/path')
        self.assertNotIn('Authorization',dict(redirect.header_items()))
    def test_insecure_or_foreign_redirect_refused(self):
        for url in ['http://release-assets.githubusercontent.com/x','https://attacker.invalid/x']:
            with self.assertRaises(ValueError):
                p.SafeRedirects().redirect_request(Request('https://api.github.com/x'),None,302,'',{},url)
    def test_missing_remote_digest_refused(self):
        with self.assertRaises(ValueError):p.metadata({'name':'x','size':2,'state':'uploaded'},'x',{'size':2,'sha256':'a'*64})
    def test_visible_asset_stops(self):
        import io
        with patch.object(p.OPENER,'open',return_value=io.BytesIO(b'PKasset')),self.assertRaisesRegex(ValueError,'successful response'):
            p.private_asset_unavailable(p.ASSETS[0],'dummy',[p.ASSETS[0]])
    def test_private_asset_denial_is_anonymous(self):
        import io
        for code in [401,403,404]:
            requests=[]
            def denied(req,**kwargs):
                requests.append(req)
                raise HTTPError(req.full_url,code,'',{},io.BytesIO(b'rate limit exceeded' if code==403 else b'not found'))
            with patch.object(p.OPENER,'open',side_effect=denied),patch.object(p,'state') as state:
                p.private_asset_unavailable(p.ASSETS[0],'dummy',[p.ASSETS[0]])
                state.assert_called_once_with('dummy',draft=True,prerelease=True,names=[p.ASSETS[0]])
            self.assertNotIn('Authorization',dict(requests[0].header_items()))
    def test_unexpected_asset_error_stops(self):
        def error(req,**kwargs):raise HTTPError(req.full_url,500,'',{},None)
        with patch.object(p.OPENER,'open',side_effect=error),self.assertRaisesRegex(ValueError,'Unexpected'):
            p.private_asset_unavailable(p.ASSETS[0],'dummy',[p.ASSETS[0]])
    def test_local_failure_before_any_network(self):
        with patch.object(p,'verify',side_effect=ValueError('invalid')),patch.object(p,'api') as api:
            with self.assertRaises(ValueError):p.publish(Path('/none'),Path('/none/report'),'dummy')
            api.assert_not_called()
    def test_wrong_main_refused(self):
        with patch.object(p,'api',return_value={'object':{'sha':'0'*40}}),self.assertRaisesRegex(ValueError,'Main'):p.reference("dummy")
    def test_extra_asset_refused(self):
        with self.assertRaises(ValueError):p.uploaded_assets({'assets':[{'name':'foreign.zip'}]})
    def test_upload_error_stops_without_retry_or_promotion(self):
        expected={n:{'size':1,'sha256':'a'*64} for n in p.ASSETS}
        with patch.object(p,'verify',return_value=expected),patch.object(p,'reference'),patch.object(p,'previous_latest'),patch.object(p,'state',return_value={}),patch.object(p,'create_private_draft'),patch.object(p,'api',return_value={'draft':True,'prerelease':True}) as api,patch.object(p,'upload',side_effect=ValueError('write uncertain')) as upload:
            with self.assertRaisesRegex(ValueError,'uncertain'):p.publish(Path('/none'),Path('/none/report'),'dummy')
            self.assertEqual(upload.call_count,1)
            api.assert_not_called()
    def test_upload_order_manifest_last(self):
        self.assertEqual(len(p.ASSETS),7);self.assertEqual(p.ASSETS[-1],p.MANIFEST)

class PublishFlow(unittest.TestCase):
    def exercise(self, readback_fails=False, private_visible=False):
        import copy
        expected={n:{'size':1,'sha256':'a'*64} for n in p.ASSETS}
        release={'id':900042,'tag_name':p.TAG,'draft':True,'prerelease':True,'assets':[]}
        created=False
        events=[]
        def api(path,token='',payload=None,method='PATCH'):
            nonlocal created
            self.assertEqual(token,'dummy', 'REST metadata must be authenticated')
            if path.startswith('/releases?'):
                return [copy.deepcopy(release)] if created else []
            if path=='/releases' and method=='POST':
                self.assertEqual(payload['target_commitish'],p.SOURCE);self.assertTrue(payload['draft'])
                created=True;events.append(('create',dict(payload)));return copy.deepcopy(release)
            if path=='/git/ref/heads/main':return {'object':{'sha':p.EXPECTED_MAIN}}
            if path==f'/git/ref/tags/{p.TAG}':return {'object':{'type':'commit','sha':p.SOURCE}}
            if path=='/releases/latest':return {'id':p.RELEASE_ID if not release['prerelease'] else 444007588,'tag_name':p.TAG if not release['prerelease'] else p.PREVIOUS_LATEST,'draft':False,'prerelease':False}
            if payload is not None:
                self.assertEqual(path,p.ONE);self.assertEqual(token,'dummy')
                events.append(('patch',dict(payload)));release.update(payload)
            if release['draft'] and not token:raise HTTPError('url',404,'',{},None)
            return copy.deepcopy(release)
        def upload(file,token,wanted):
            self.assertTrue(release['draft']);self.assertEqual(token,'dummy')
            asset={'name':file.name,**wanted,'state':'uploaded','digest':'sha256:'+wanted['sha256'],'id':len(release['assets'])+1}
            release['assets'].append(asset);events.append(('upload',file.name));return asset
        def readback(asset,name,wanted,token=''):
            events.append(('read',name,bool(token)))
            if readback_fails:raise ValueError('readback mismatch')
        with patch.object(p,'verify',return_value=expected),patch.object(p,'api',side_effect=api),patch.object(p,'upload',side_effect=upload),patch.object(p,'readback',side_effect=readback),patch.object(p,'anonymous_pages') as pages,patch.object(p,'private_asset_unavailable',side_effect=ValueError('public asset') if private_visible else None) as unavailable,patch.dict(p.os.environ,{'GITHUB_RUN_ID':'123'}):
            if private_visible:
                with self.assertRaisesRegex(ValueError,'public asset'):p.publish(Path('/none'),Path('/none/report'),'dummy')
            elif readback_fails:
                with self.assertRaisesRegex(ValueError,'readback mismatch'):p.publish(Path('/none'),Path('/none/report'),'dummy')
            else:p.publish(Path('/none'),Path('/none/report'),'dummy')
        if not readback_fails and not private_visible:
            self.assertEqual(pages.call_args_list[-1].args,(200,))
            unavailable.assert_called_once()
            self.assertEqual(unavailable.call_args.args[0],p.ASSETS[0])
        return events,release
    def test_full_order_and_public_verification(self):
        events,release=self.exercise()
        self.assertEqual([e[1] for e in events if e[0]=='upload'],list(p.ASSETS))
        reads=[e for e in events if e[0]=='read'];self.assertEqual(len(reads),14)
        self.assertTrue(all(e[2] for e in reads[:7]));self.assertTrue(all(not e[2] for e in reads[7:]))
        patches=[e[1] for e in events if e[0]=='patch'];self.assertEqual(len(patches),1)
        self.assertFalse(patches[-1]['draft']);self.assertEqual(patches[-1]['make_latest'],'true')
        self.assertFalse(release['prerelease'])
    def test_readback_failure_keeps_private_and_no_retry(self):
        events,release=self.exercise(True)
        self.assertTrue(release['draft'])
        self.assertEqual(sum(e[0]=='upload' for e in events),1)
        self.assertEqual(sum(e[0]=='patch' for e in events),0)
    def test_exposed_first_asset_stops_before_manifest(self):
        events,release=self.exercise(private_visible=True)
        self.assertTrue(release['draft'])
        self.assertEqual([e[1] for e in events if e[0]=='upload'],[p.ASSETS[0]])
        self.assertEqual(sum(e[0]=='patch' for e in events),0)
    def test_actual_readback_rejects_bad_hash(self):
        import io
        asset={'name':'x','size':1,'state':'uploaded','digest':'sha256:'+'a'*64,'id':1}
        with patch.object(p.OPENER,'open',return_value=io.BytesIO(b'b')),self.assertRaisesRegex(ValueError,'digest mismatch'):
            p.readback(asset,'x',{'size':1,'sha256':'a'*64},'dummy')

class Preflight(unittest.TestCase):
    def test_preflight_refuses_existing_target_including_draft(self):
        with patch.object(p,'reference'),patch.object(p,'previous_latest'),patch.object(p,'api',return_value=[{'tag_name':p.TAG,'draft':True}]) as api:
            with self.assertRaisesRegex(ValueError,'already exists'):p.preflight('dummy')
            self.assertTrue(all(len(call.args)==2 for call in api.call_args_list))
    def test_create_only_private_and_exact_source(self):
        result={'id':900042,'tag_name':p.TAG,'draft':True,'prerelease':True,'assets':[]}
        with patch.object(p,'preflight'),patch.object(p,'api',return_value=result) as api,patch.object(p,'state'):
            p.create_private_draft('dummy')
            args=api.call_args
            self.assertEqual(args.kwargs['method'],'POST')
            self.assertTrue(args.args[2]['draft']);self.assertEqual(args.args[2]['target_commitish'],p.SOURCE)
    def test_uncertain_create_stops_without_retry(self):
        with patch.object(p,'preflight'),patch.object(p,'api',side_effect=TimeoutError) as api:
            with self.assertRaises(TimeoutError):p.create_private_draft('dummy')
            self.assertEqual(api.call_count,1)
