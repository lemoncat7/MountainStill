#!/usr/bin/env python3
import copy
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import native_gui_stability as gui


def fixture():
    return dict(lifetime_seconds=30,herbs=3,dew=1,journey_completed=0,journey_bond=0,
        counters={'gathered':0},settings={'paused':False,'low_power':False},activity='gather',
        auto_advance=False,journey={'id':'bamboo','repeat':True})


class GuiContracts(unittest.TestCase):
    def test_environment_closed_to_other_platforms_and_repositories(self):
        env={'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'github-hosted','GITHUB_REPOSITORY':'lemoncat7/MountainStill'}
        with patch.dict(os.environ,env,clear=True),patch.object(gui.sys,'platform','darwin'),patch.object(gui.platform,'machine',return_value='arm64'):
            gui.require_environment()
            for key,value in [('GITHUB_REPOSITORY','other/repo'),('RUNNER_ENVIRONMENT','self-hosted'),('GITHUB_ACTIONS','false')]:
                with patch.dict(os.environ,{key:value}),self.assertRaises(RuntimeError):gui.require_environment()
            with patch.object(gui.platform,'machine',return_value='x86_64'),self.assertRaises(RuntimeError):gui.require_environment()

    def test_actual_prior_save_not_synthetic_gap(self):
        seed=fixture();after=copy.deepcopy(seed)
        after.update(lifetime_seconds=1230,herbs=170,journey_completed=4,journey_bond=4)
        after['counters']['gathered']=150
        backup=copy.deepcopy(after);backup['lifetime_seconds']-=.35
        before=copy.deepcopy(backup)
        v=gui.gui_progress(seed,after,backup,3)
        self.assertAlmostEqual(v['primary_backup_lifetime_delta'],.35)
        self.assertEqual(backup,before)
        for fault in ('old_backup','future_backup','no_gather','low_power','no_fox','offline'):
            a=copy.deepcopy(after);b=copy.deepcopy(backup);offline=3
            if fault=='old_backup':b['lifetime_seconds']=seed['lifetime_seconds']
            if fault=='future_backup':b['lifetime_seconds']=a['lifetime_seconds']+1
            if fault=='no_gather':a['counters']['gathered']=0
            if fault=='low_power':a['settings']['low_power']=True
            if fault=='no_fox':a['journey_completed']=0
            if fault=='offline':offline=300
            with self.subTest(fault=fault),self.assertRaises(RuntimeError):gui.gui_progress(seed,a,b,offline)

    def test_restart_requires_retention_and_real_advance(self):
        after=fixture();restored=copy.deepcopy(after);restored['lifetime_seconds']+=30
        backup=copy.deepcopy(restored);backup['lifetime_seconds']-=.1
        gui.verify_restart(after,restored,backup,3)
        for key in ('lifetime_seconds','herbs','journey_bond'):
            bad=copy.deepcopy(restored);bad[key]=after[key]-1
            with self.assertRaises(RuntimeError):gui.verify_restart(after,bad,backup,3)
        with self.assertRaises(RuntimeError):gui.verify_restart(after,restored,backup,300)
        with self.assertRaises(RuntimeError):gui.verify_restart(after,restored,backup,25)
        for fault in ('paused','auto_advance','journey'):
            bad=copy.deepcopy(restored)
            if fault=='paused':bad['settings']['paused']=True
            if fault=='auto_advance':bad['auto_advance']=True
            if fault=='journey':bad['journey']['id']='other'
            with self.assertRaises(RuntimeError):gui.verify_restart(after,bad,backup,3)
        restored['settings']['low_power']=True
        with self.assertRaises(RuntimeError):gui.verify_restart(after,restored,backup,3)


if __name__=='__main__':unittest.main()
