#!/usr/bin/env python3
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
import native_package_stability as gate


def state(life=30):
    return dict(version=4,saved_at=1770000000,lifetime_seconds=life,herbs=3,dew=1,qi=30,
                journey_completed=0,journey_bond=0,counters={'gathered':0},
                settings={'paused':False,'low_power':False},activity='meditate',auto_advance=False,
                journey={})


class StabilityContracts(unittest.TestCase):
    def test_real_wall_gate_not_frame_count(self):
        gate.require_terminal(0,1200,1200)
        for code,wall in ((0,1199.99),(0,None),(124,1300),(1,1300)):
            with self.subTest(code=code,wall=wall),self.assertRaises(RuntimeError):
                gate.require_terminal(code,wall,1200)
        self.assertEqual(gate.MIN_WALL_SECONDS,1200)
        self.assertEqual(gate.WARMUP_SECONDS,300)
        self.assertGreater(gate.LONG_TIMEOUT_SECONDS,gate.MIN_WALL_SECONDS)

    def test_fixed_app_user_directory(self):
        with patch.object(gate.sys,'platform','win32'),patch.dict(gate.os.environ,{'APPDATA':'/test/appdata'}):
            self.assertEqual(gate.userdata_path(),Path('/test/appdata/Godot/app_userdata')/gate.APP)
        with patch.object(gate.sys,'platform','darwin'),patch.object(gate.Path,'home',return_value=Path('/test/home')):
            self.assertEqual(gate.userdata_path(),Path('/test/home/Library/Application Support/Godot/app_userdata')/gate.APP)

    def test_readiness_requires_fixed_version_and_both_loads(self):
        text='UPDATE BOOT: 1.3.20-test.1\n'+''.join('Loading resource: res://assets/cultivation/beasts/'+x+'\n' for x in gate.ASSETS)
        self.assertTrue(gate.boot_ready(text))
        self.assertFalse(gate.boot_ready(text.replace('1.3.20','1.3.19')))
        for asset in gate.ASSETS:self.assertFalse(gate.boot_ready(text.replace(asset,'absent.png')))

    def test_fixture_uses_actual_save_and_no_mutation(self):
        seed=state();original=copy.deepcopy(seed);fixture=gate.fixture_from(seed)
        self.assertEqual(seed,original)
        self.assertEqual(fixture['journey'],{'id':'bamboo','remaining':300.0,'repeat':True})
        self.assertEqual(fixture['activity'],'gather')
        self.assertFalse(fixture['auto_advance'])
        self.assertFalse(fixture['settings']['paused'])
        self.assertFalse(fixture['settings']['low_power'])

    def test_progress_needs_observed_events_beyond_offline(self):
        seed=gate.fixture_from(state());after=copy.deepcopy(seed);after.update(lifetime_seconds=1330,journey_completed=4,journey_bond=4)
        after['counters']['gathered']=162
        after['herbs']=180
        backup=copy.deepcopy(after);backup['lifetime_seconds']-=10
        result=gate.progress(seed,after,backup,3)
        self.assertEqual(result['completed_fox_returns'],4)
        for fault in ('no_returns','no_gather','no_autosave','paused','wrong_repeat','offline_unbounded','resources_lost'):
            end=copy.deepcopy(after);bak=copy.deepcopy(backup);offline=3
            if fault=='no_returns':end['journey_completed']=0
            if fault=='no_gather':end['counters']['gathered']=0
            if fault=='no_autosave':bak['lifetime_seconds']=end['lifetime_seconds']
            if fault=='paused':end['settings']['paused']=True
            if fault=='wrong_repeat':end['journey']['repeat']=False
            if fault=='offline_unbounded':offline=300
            if fault=='resources_lost':end['herbs']=3
            with self.subTest(fault=fault),self.assertRaises(RuntimeError):gate.progress(seed,end,bak,offline)

    def test_memory_window_and_proposed_budget(self):
        rows=[dict(ready_wall_s=i,rss_bytes=100*1048576) for i in (0,100,300,600,900,1200)]
        result=gate.memory_summary(rows)
        self.assertEqual(result['post_warmup_samples'],4)
        self.assertFalse(result['proposed_rss_budget_review_required'])
        self.assertEqual(result['internal_static_memory'],'NOT_OBSERVED')
        rows[-1]['rss_bytes']=130*1048576
        self.assertTrue(gate.memory_summary(rows)['proposed_rss_budget_review_required'])
        with self.assertRaises(RuntimeError):gate.memory_summary(rows[:2])

    def test_log_budget_before_read(self):
        with tempfile.TemporaryDirectory() as root:
            path=Path(root)/'engine.log'
            with path.open('wb') as stream:stream.truncate(gate.LOG_BUDGET+1)
            with self.assertRaises(RuntimeError):gate.read_log_bounded(path)
            path.write_text('small log')
            self.assertEqual(gate.read_log_bounded(path),'small log')

    def test_save_rejects_invalid_numbers_and_schema(self):
        with tempfile.TemporaryDirectory() as root:
            path=Path(root)/'save.json';path.write_text(json.dumps(state()))
            self.assertEqual(gate.save_snapshot(path)['version'],4)
            for key,value in [('version',3),('herbs',-1),('lifetime_seconds',float('nan')),('journey_completed',True)]:
                bad=state();bad[key]=value;path.write_text(json.dumps(bad))
                with self.subTest(key=key),self.assertRaises((RuntimeError,ValueError)):gate.save_snapshot(path)


if __name__=='__main__':unittest.main()
