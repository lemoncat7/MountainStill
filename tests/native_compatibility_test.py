#!/usr/bin/env python3
import copy
import hashlib
import importlib
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock,patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import native_compatibility as compat
import verify_native_compatibility_assets as asset_contract


def save(life=30):
    return dict(version=4,saved_at=1770000000,lifetime_seconds=life,herbs=3,dew=1,qi=30,
        realm=0,journey_completed=0,journey_bond=0,counters={'gathered':0},
        activity='meditate',auto_advance=False,outfit='moon',weapon='sword',technique='mist',
        settings={'paused':False,'low_power':False},journey={})


def manifest():
    _,name,size,sha=compat.PINS['pck']
    return dict(schema=1,version=compat.NEW_VERSION,engine='4.6.3',bootstrap=1,save_schema=4,
        packages={compat.PLATFORM:dict(kind='pck',asset=name,size=size,sha256=sha,restart_required=True)})


class CompatibilityContracts(unittest.TestCase):
    def test_actual_asset_contract_rejects_independent_byte_drift(self):
        original_pins = copy.deepcopy(compat.PINS)
        original_platform = compat.PLATFORM
        try:
            with tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                payload = b'GDPC-small-independent-contract-fixture'
                sha = hashlib.sha256(payload).hexdigest()
                value = dict(schema=1, version=compat.NEW_VERSION, engine='4.6.3', bootstrap=1, save_schema=4,
                    packages={name: dict(kind='pck', asset='MountainStill-'+name+'.pck', size=len(payload),
                        sha256=sha, restart_required=True) for name in ('windows', 'macos')})
                raw = json.dumps(value).encode()
                (root/'MountainStill-update.json').write_bytes(raw)
                for name in ('windows', 'macos'):
                    (root/('MountainStill-'+name+'.pck')).write_bytes(payload)
                def fixed_fixture(module):
                    module.PLATFORM = 'windows' if sys.platform == 'win32' else 'macos'
                    module.PINS = dict(manifest=(module.NEW_TAG, 'MountainStill-update.json', len(raw), hashlib.sha256(raw).hexdigest()),
                        pck=(module.NEW_TAG, 'MountainStill-'+module.PLATFORM+'.pck', len(payload), sha))
                    return module
                with patch.object(asset_contract.importlib, 'reload', side_effect=fixed_fixture):
                    self.assertEqual(asset_contract.verify(root), ['windows', 'macos'])
                    file = root/'MountainStill-macos.pck'
                    for bad in (payload+b'x', b'X'+payload[1:]):
                        file.write_bytes(bad)
                        with self.assertRaisesRegex(ValueError, 'does not match'):
                            asset_contract.verify(root)
                    file.write_bytes(payload)
                    (root/'MountainStill-update.json').write_bytes(raw+b' ')
                    with self.assertRaisesRegex(ValueError, 'does not match'):
                        asset_contract.verify(root)
                    (root/'MountainStill-update.json').write_bytes(raw)
                    file.unlink()
                    with self.assertRaisesRegex(ValueError, 'Missing/unsafe'):
                        asset_contract.verify(root)
        finally:
            compat.PINS = original_pins
            compat.PLATFORM = original_platform

    def test_exact_old_and_new_pins_both_platforms(self):
        expected = {
            'win32': ('windows', 114552389, '020576fdaeb14b8c901a2c5f28df5a6ba0de35e121ddb1be80e50dfa2b137873',
                      114641665, 'e91e6f941ff06b54053053765af675619e9afb53961f1bc33a5006d9bcd44dc1'),
            'darwin': ('macos', 141283216, '78a28978026349aee4c806fd553bfa989f2a841b3fa7755b22adebf23811457d',
                       141373386, '8bb6cf17dcb013c445e9dab36eacd34b356e0848a6422bd103100e6d07b8ea53'),
        }
        try:
            for platform_name, (package_platform, old_size, old_sha, new_size, new_sha) in expected.items():
                with patch.object(sys, 'platform', platform_name):
                    importlib.reload(compat)
                    self.assertEqual(compat.OLD_TAG, 'v1.3.26')
                    self.assertEqual(compat.NEW_TAG, 'v1.3.40')
                    self.assertEqual(compat.PINS['old_zip'][2:], (old_size, old_sha))
                    self.assertEqual(compat.PINS['new_zip'][2:], (new_size, new_sha))
                    suffix = 'Windows-x86_64.zip' if package_platform == 'windows' else 'macOS-Universal.zip'
                    self.assertEqual(compat.PINS['old_zip'][1], 'MountainStill-v1.3.26-'+suffix)
                    self.assertEqual(compat.PINS['new_zip'][1], 'MountainStill-v1.3.40-'+suffix)
                    self.assertEqual(compat.PINS['pck'], ('v1.3.40', 'MountainStill-'+package_platform+'.pck',
                        78537364, '6d423fcbfc44883546db6c99c605c63bc69061cb8bdbaf13091139a5f6f8658a'))
                    self.assertEqual(compat.PINS['manifest'][2:], (572,
                        'df508322bc7b46b62dd8d1609b54ab6ae8121688ff2a6d67b437b660c4c78c66'))
        finally:
            importlib.reload(compat)

    def test_hard_pins_and_manifest_fields(self):
        self.assertEqual(compat.PINS['old_zip'][2],114552389 if compat.PLATFORM=='windows' else 141283216)
        self.assertEqual(compat.PINS['pck'][3],'6d423fcbfc44883546db6c99c605c63bc69061cb8bdbaf13091139a5f6f8658a')
        value=manifest();record=compat.installed_record(value)
        self.assertEqual(record['path'],'user://updates/'+record['sha256']+'.pck')
        for key,bad in [('version','1.3.26'),('engine','4.5'),('save_schema',3),('bootstrap',2),('schema',True)]:
            invalid=copy.deepcopy(value);invalid[key]=bad
            with self.assertRaises(RuntimeError):compat.installed_record(invalid)
        for key,bad in [('sha256','0'*64),('size',1),('asset','other.pck'),('restart_required',False),('restart_required',1)]:
            invalid=copy.deepcopy(value);invalid['packages'][compat.PLATFORM][key]=bad
            with self.assertRaises(RuntimeError):compat.installed_record(invalid)

    def test_installed_fixture_preserves_actual_save_copies_and_requires_app_health(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);userdata=root/'owned';compat.gate.claim_userdata(userdata,'owned-token');(userdata/'updates').mkdir()
            primary=userdata/'cultivation_save.json';backup=Path(str(primary)+'.bak')
            primary.write_text(json.dumps(save()));backup.write_text(json.dumps(save(29)))
            before=(primary.read_bytes(),backup.read_bytes())
            pck=root/'pck';pck.write_bytes(b'GDPC-unit-fixture-not-runtime-pack')
            fakepin=(compat.NEW_TAG,'MountainStill-'+compat.PLATFORM+'.pck',pck.stat().st_size,hashlib.sha256(pck.read_bytes()).hexdigest())
            dead=[Mock(poll=Mock(return_value=0))]
            with patch.dict(compat.PINS,{'pck':fakepin}),patch.object(compat.gate,'emit'):
                with self.assertRaises(RuntimeError):compat.stage_installed_fixture(userdata,'wrong',pck,manifest(),dead)
                with self.assertRaises(RuntimeError):compat.stage_installed_fixture(userdata,'owned-token',pck,manifest(),[Mock(poll=Mock(return_value=None))])
                fixture=compat.stage_installed_fixture(userdata,'owned-token',pck,manifest(),dead)
                self.assertEqual((primary.read_bytes(),backup.read_bytes()),before)
                self.assertEqual(compat.bounded_json(userdata/'updates'/'booting.json')['phase'],'armed')
                with self.assertRaises(RuntimeError):compat.verify_installed_health(userdata,fixture)
                # Unit simulation only: actual CI requires application to remove this file.
                (userdata/'updates'/'booting.json').unlink()
                compat.verify_installed_health(userdata,fixture)
                with self.assertRaises(RuntimeError):compat.stage_installed_fixture(userdata,'owned-token',pck,manifest(),dead)
                snapshot=userdata/'updates'/fixture['previous']['snapshot']['prefix']
                snapshot.write_text('corrupted')
                with self.assertRaises(RuntimeError):compat.verify_installed_health(userdata,fixture)

    def test_pck_bytes_or_version_tamper_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);userdata=root/'owned';compat.gate.claim_userdata(userdata,'t');(userdata/'updates').mkdir()
            pck=root/'bad';pck.write_bytes(b'GDPC')
            with self.assertRaises(RuntimeError):compat.stage_installed_fixture(userdata,'t',pck,manifest(),[Mock(poll=Mock(return_value=0))])

    def test_old_save_real_progress_and_choices(self):
        before=save();after=save(60);backup=save(59.9)
        evidence=compat.recovery(before,after,backup,3)
        self.assertAlmostEqual(evidence['primary_backup_lifetime_delta'],.1)
        for offline in (-1,float('nan'),120,25):
            with self.assertRaises(RuntimeError):compat.recovery(before,after,backup,offline)
        for key in ('outfit','weapon','technique','activity','realm','auto_advance'):
            bad=copy.deepcopy(after);bad[key]='changed'
            with self.assertRaises(RuntimeError):compat.recovery(before,bad,backup,3)
        bad=copy.deepcopy(backup);bad['counters']['gathered']=1
        with self.assertRaises(RuntimeError):compat.recovery(before,after,bad,3)
        bad=copy.deepcopy(backup);bad['qi']=0
        with self.assertRaises(RuntimeError):compat.recovery(before,after,bad,3)
        bad=copy.deepcopy(after);bad['settings']['low_power']=True
        with self.assertRaises(RuntimeError):compat.recovery(before,bad,backup,3)
        with self.assertRaises(RuntimeError):compat.recovery(before,after,save(31),3)

    def test_two_scenarios_use_correct_binaries_without_save_edits(self):
        for kind,healthy in (('full_upgrade',True),('installed_pck',True),('installed_pck',False)):
            with tempfile.TemporaryDirectory() as folder:
                root=Path(folder);userdata=root/'userdata';old=root/'old';new=root/'new'
                old.write_text('old actual binary fixture');new.write_text('new actual binary fixture')
                pck=root/'pack';pck.write_bytes(b'GDPC-unit-only')
                pin=(compat.NEW_TAG,'MountainStill-'+compat.PLATFORM+'.pck',pck.stat().st_size,hashlib.sha256(pck.read_bytes()).hexdigest())
                calls=[];previous_bytes=None
                def fake_session(binary,jobroot,label,version,rows,registry,deadline):
                    nonlocal previous_bytes
                    # Keep the real downstream profile/readiness guard in this
                    # scenario test; mocking it hid stale session allowlists.
                    import native_compat_session as actual_session
                    resources=''.join('Loading resource: res://assets/cultivation/beasts/'+asset+'\n'
                        for asset in actual_session.ASSETS)
                    self.assertTrue(actual_session.boot_ready('UPDATE BOOT: '+version+'\n'+resources, version))
                    calls.append((binary,version));registry.append(Mock(poll=Mock(return_value=0)))
                    path=userdata/'cultivation_save.json'
                    if len(calls)==1:
                        value=save();value['saved_at']=int(time.time());ready=value['saved_at']+2
                    else:
                        self.assertEqual(path.read_bytes(),previous_bytes)
                        value=json.loads(path.read_text());ready=value['saved_at']+2
                        value['lifetime_seconds']+=40;value['qi']+=1
                        if kind=='installed_pck' and healthy:
                            (userdata/'updates'/'booting.json').unlink(missing_ok=True)
                    value['saved_at']=int(time.time())
                    path.write_text(json.dumps(value));previous_bytes=path.read_bytes()
                    backup=copy.deepcopy(value);backup['lifetime_seconds']-=1
                    Path(str(path)+'.bak').write_text(json.dumps(backup))
                    return {'ready_epoch':ready}
                with patch.dict(compat.PINS,{'pck':pin}),patch.object(compat.gate,'userdata_path',return_value=userdata),\
                     patch.object(compat,'session',side_effect=fake_session),patch.object(compat.gate,'emit'):
                    if healthy:
                        result=compat.scenario(kind,old,new,pck,manifest(),root,time.monotonic()+720,[])
                        self.assertEqual(result['restores'],2)
                    else:
                        with self.assertRaises(RuntimeError):compat.scenario(kind,old,new,pck,manifest(),root,time.monotonic()+720,[])
                expected=[(old,compat.OLD_VERSION)]+[(old if kind=='installed_pck' else new,compat.NEW_VERSION)]*(2 if healthy else 1)
                self.assertEqual(calls,expected)
                self.assertFalse(userdata.exists())

    def test_native_platforms_and_deadline(self):
        env={'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'github-hosted','GITHUB_REPOSITORY':'lemoncat7/MountainStill'}
        with patch.dict(os.environ,env,clear=True),patch.object(compat.sys,'platform','darwin'),patch.object(compat.platform,'machine',return_value='arm64'):
            compat.require_environment()
            with patch.object(compat.platform,'machine',return_value='x86_64'):compat.require_environment()
            with patch.object(compat.sys,'platform','win32'),patch.object(compat.platform,'machine',return_value='AMD64'):compat.require_environment()
            with patch.object(compat.sys,'platform','win32'),self.assertRaises(RuntimeError):compat.require_environment()
            with patch.dict(os.environ,{'GITHUB_REPOSITORY':'other/repo'}),self.assertRaises(RuntimeError):compat.require_environment()
        with patch.object(compat.time,'monotonic',return_value=100):
            compat.budget(251,150)
            with self.assertRaises(RuntimeError):compat.budget(250,150)


if __name__=='__main__':unittest.main()
