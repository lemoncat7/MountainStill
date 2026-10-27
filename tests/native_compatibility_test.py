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
    def test_exact_old_and_new_pins_both_platforms(self):
        expected = {
            'win32': ('windows', 114533871, '5de31cfed0bc1ed9038d605e8a03ff0cd8a0c8e2265aeb7f7857c9be99dd0cda',
                      114548564, '30940b6ee4f4541bdc7610d84bbfd051e212477f0099fc3c4ac12a1107012d7f'),
            'darwin': ('macos', 141264802, 'ac0f3603f0ad8d80fc262c66442b475aeb266dee3c59f8ed414b968022e99a28',
                       141279331, '06a6fd42ff7e3fa809c657ac4bb90457226d5162f15d69ae217417635f8a2f78'),
        }
        try:
            for platform_name, (package_platform, old_size, old_sha, new_size, new_sha) in expected.items():
                with patch.object(sys, 'platform', platform_name):
                    importlib.reload(compat)
                    self.assertEqual(compat.OLD_TAG, 'v1.3.25-test.1')
                    self.assertEqual(compat.NEW_TAG, 'v1.3.26-test.1')
                    self.assertEqual(compat.PINS['old_zip'][2:], (old_size, old_sha))
                    self.assertEqual(compat.PINS['new_zip'][2:], (new_size, new_sha))
                    self.assertIn('v1.3.25-test.1', compat.PINS['old_zip'][1])
                    self.assertIn('v1.3.26-test.1', compat.PINS['new_zip'][1])
                    self.assertEqual(compat.PINS['pck'], ('v1.3.26-test.1', 'MountainStill-'+package_platform+'.pck',
                        78491732, '777774ad17ba866a670aa4e7946fcdc285969fd9c7d2eb246c4662f0cc9712fd'))
                    self.assertEqual(compat.PINS['manifest'][2:], (579,
                        '860ef463e762a12acfa81ab5c21cf91409d17c35eb49596f8a3a7a40002ba0ba'))
        finally:
            importlib.reload(compat)

    def test_hard_pins_and_manifest_fields(self):
        self.assertEqual(compat.PINS['old_zip'][2],114533871 if compat.PLATFORM=='windows' else 141264802)
        self.assertEqual(compat.PINS['pck'][3],'777774ad17ba866a670aa4e7946fcdc285969fd9c7d2eb246c4662f0cc9712fd')
        value=manifest();record=compat.installed_record(value)
        self.assertEqual(record['path'],'user://updates/'+record['sha256']+'.pck')
        for key,bad in [('version','1.3.25-test.1'),('engine','4.5'),('save_schema',3),('bootstrap',2),('schema',True)]:
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
