#!/usr/bin/env python3
import copy
import contextlib
import io
import json
import time
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock,patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import native_reload_matrix as matrix


def state(life=30):
    return dict(version=4,saved_at=1770000000,lifetime_seconds=life,herbs=3,dew=1,qi=30,
        realm=0,journey_completed=0,journey_bond=0,counters={'gathered':0},
        settings={'paused':False,'low_power':False},activity='gather',auto_advance=False,
        journey={'id':'bamboo','repeat':True})


class ReloadContracts(unittest.TestCase):
    def test_full_orchestration_seed_once_then_continuous_50_restores(self):
        for failed in (None,25):
            with tempfile.TemporaryDirectory() as folder:
                root=Path(folder);userdata=root/'userdata';binary=root/'game';binary.write_text('fixture binary')
                calls=[];observed_states=[]
                def fake_session(binary,jobroot,label,rows,registry,deadline):
                    calls.append(label);registry.append(Mock(poll=Mock(return_value=0)))
                    save=userdata/'cultivation_save.json'
                    if label=='seed':
                        after=state();after['activity']='meditate';before=copy.deepcopy(after)
                    else:
                        before=json.loads(save.read_text());observed_states.append(copy.deepcopy(before))
                        after=copy.deepcopy(before);after['lifetime_seconds']+=40
                        after['herbs']+=5;after['counters']['gathered']+=5
                        if failed is not None and label=='reload_%02d'%failed:after['settings']['paused']=True
                    ready_epoch=before['saved_at']+2
                    after['saved_at']=int(time.time())
                    backup=copy.deepcopy(after);backup['lifetime_seconds']-=1
                    save.write_text(json.dumps(after));Path(str(save)+'.bak').write_text(json.dumps(backup))
                    return dict(pid=123,process_identity='pid123:created'+str(len(calls)),ready_epoch=ready_epoch)
                with patch.object(matrix,'require_environment'),patch.object(matrix.gate,'configure_output'),\
                     patch.object(matrix.gate,'userdata_path',return_value=userdata),\
                     patch.object(matrix.gate,'download_pinned',return_value=binary),\
                     patch.object(matrix,'prepare_helper') as prepare,\
                     patch.object(matrix,'session',side_effect=fake_session),\
                     patch.dict(os.environ,{'RUNNER_TEMP':folder}),contextlib.redirect_stdout(io.StringIO()) as output:
                    code=matrix.main()
                self.assertEqual(code,0 if failed is None else 1)
                self.assertEqual(len(calls),51 if failed is None else 26)
                self.assertEqual(calls[0],'seed');prepare.assert_called_once()
                self.assertEqual(output.getvalue().count('EXTERNAL_FIXTURE_ONCE'),1)
                self.assertEqual(observed_states[0]['activity'],'gather')
                self.assertEqual([s['counters']['gathered'] for s in observed_states],list(range(0,5*len(observed_states),5)))
                self.assertFalse(userdata.exists())
                if failed:self.assertIn('"completed": 24',output.getvalue())

    def test_exact_50_not_seed_or_retry(self):
        visited=[];checks=[];progress={'completed':0,'attempted':0}
        matrix.run_reloads(visited.append,checks.append,progress)
        self.assertEqual(visited,list(range(1,51)))
        self.assertEqual(progress,{'completed':50,'attempted':50})
        self.assertEqual(checks,[150,0]*50)
        for failed in (1,25,50):
            visited=[];progress={'completed':0,'attempted':0}
            def cycle(n):
                visited.append(n)
                if n==failed:raise RuntimeError('injected failure')
            with self.assertRaises(RuntimeError):matrix.run_reloads(cycle,lambda _:None,progress)
            self.assertEqual(visited,list(range(1,failed+1)))
            self.assertEqual(progress['completed'],failed-1)

    def test_budget_prelaunch_and_terminal_no_shortened_matrix(self):
        with patch.object(matrix.time,'monotonic',return_value=100):
            matrix.budget(251,150)
            for deadline,reserve in ((250,150),(100,0),(99,0),(float('nan'),0)):
                with self.assertRaises(RuntimeError):matrix.budget(deadline,reserve)
        progress={'completed':0,'attempted':0}
        def budget_fail(reserve):
            if reserve==0:raise RuntimeError('deadline after exit')
        with self.assertRaises(RuntimeError):matrix.run_reloads(lambda _:None,budget_fail,progress)
        self.assertEqual(progress['completed'],0)

    def test_recovery_real_prior_save_small_quit_gap(self):
        before=state();after=state(60);after['herbs']=6;after['counters']['gathered']=3
        backup=copy.deepcopy(after);backup['lifetime_seconds']=59.9
        result=matrix.verify_recovery(before,after,backup,3)
        self.assertAlmostEqual(result['primary_backup_lifetime_delta'],.1)
        for key in ('lifetime_seconds','herbs','dew','qi','journey_completed','journey_bond'):
            bad=copy.deepcopy(after);bad[key]=before[key]-1
            with self.subTest(key=key),self.assertRaises(RuntimeError):matrix.verify_recovery(before,bad,backup,3)
        for offline in (-1,float('nan'),float('inf'),120,25):
            with self.assertRaises(RuntimeError):matrix.verify_recovery(before,after,backup,offline)
        for life in (30,33,61):
            bad=copy.deepcopy(backup);bad['lifetime_seconds']=life
            with self.assertRaises(RuntimeError):matrix.verify_recovery(before,after,bad,3)

    def test_backup_resource_counter_chain_not_only_lifetime(self):
        before=state();after=state(60);after['herbs']=6;after['counters']['gathered']=3
        backup=copy.deepcopy(after);backup['lifetime_seconds']=59
        for key in ('herbs','dew','qi','journey_completed','journey_bond'):
            for value in (before[key]-1,after[key]+1):
                bad=copy.deepcopy(backup);bad[key]=value
                with self.subTest(key=key,value=value),self.assertRaises(RuntimeError):matrix.verify_recovery(before,after,bad,3)
        for value in (-1,4):
            bad=copy.deepcopy(backup);bad['counters']['gathered']=value
            with self.assertRaises(RuntimeError):matrix.verify_recovery(before,after,bad,3)
        bad=copy.deepcopy(backup);bad['herbs']=3
        with self.assertRaises(RuntimeError):matrix.verify_recovery(before,after,bad,3)

    def test_lost_settings_and_counters_rejected(self):
        before=state();before['counters']['gathered']=10
        after=state(60);after['herbs']=6;after['counters']['gathered']=13
        backup=copy.deepcopy(after);backup['lifetime_seconds']=59
        for field in ('paused','low_power','auto_advance','realm','journey','gathered'):
            bad=copy.deepcopy(after)
            if field in ('paused','low_power'):bad['settings'][field]=True
            elif field=='auto_advance':bad[field]=True
            elif field=='realm':bad[field]=1
            elif field=='journey':bad[field]['repeat']=False
            else:bad['counters']['gathered']=9
            with self.subTest(field=field),self.assertRaises(RuntimeError):matrix.verify_recovery(before,bad,backup,3)

    def test_no_live_save_read_gate(self):
        matrix.stopped([Mock(poll=Mock(return_value=0))])
        for rows in ([],[Mock(poll=Mock(return_value=None))]):
            with self.assertRaises(RuntimeError):matrix.stopped(rows)

    def test_save_digest_bounded_and_actual(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'save';path.write_text('first');a=matrix.state_digest(path)
            path.write_text('second');self.assertNotEqual(a,matrix.state_digest(path))
            with path.open('wb') as f:f.truncate(262145)
            with self.assertRaises(RuntimeError):matrix.state_digest(path)

    def test_environment_exact_architectures(self):
        env={'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'github-hosted','GITHUB_REPOSITORY':'lemoncat7/MountainStill'}
        with patch.dict(os.environ,env,clear=True):
            for osname,arch in [('win32','AMD64'),('darwin','arm64'),('darwin','x86_64')]:
                with patch.object(matrix.sys,'platform',osname),patch.object(matrix.platform,'machine',return_value=arch):matrix.require_environment()
            for osname,arch in [('linux','x86_64'),('win32','arm64')]:
                with patch.object(matrix.sys,'platform',osname),patch.object(matrix.platform,'machine',return_value=arch),self.assertRaises(RuntimeError):matrix.require_environment()
            with patch.dict(os.environ,{'GITHUB_REPOSITORY':'other/repo'}),self.assertRaises(RuntimeError):matrix.require_environment()


if __name__=='__main__':unittest.main()
