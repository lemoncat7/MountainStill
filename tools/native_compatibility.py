#!/usr/bin/env python3
"""Native representative v26-save/full-v27-test.1 and installed-v27-test.1-PCK/old-host checks."""
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import uuid

import native_package_stability as gate
from native_compat_session import session, native_json

OLD_TAG='v1.3.26'
NEW_TAG='v1.3.27-test.1'
OLD_VERSION='1.3.26'
NEW_VERSION='1.3.27-test.1'
DRIVER_SECONDS=12*60
PLATFORM = 'windows' if sys.platform == 'win32' else 'macos'
PINS={
 'old_zip':(OLD_TAG,'MountainStill-v1.3.26-macOS-Universal.zip',141283216,'78a28978026349aee4c806fd553bfa989f2a841b3fa7755b22adebf23811457d'),
 'new_zip':(NEW_TAG,'MountainStill-v1.3.27-test.1-macOS-Universal.zip',141286722,'01bc98334157b0a0758c299deefbab545bc59b0869934a46dc4018f4cdcd1326'),
 'pck':(NEW_TAG,'MountainStill-macos.pck',78493332,'11c558dc20e0cf5172ab3ab982b8c88ed2c52cedc54e67c81b7248276f7b1f92'),
 'manifest':(NEW_TAG,'MountainStill-update.json',579,'c752b79a5c5e8f6b68cf6ebe88820fe4c231a17d0517d151424cbe4a85e1eaa2'),
}

if PLATFORM == 'windows':
    PINS.update({
      'old_zip':(OLD_TAG,'MountainStill-v1.3.26-Windows-x86_64.zip',114552389,'020576fdaeb14b8c901a2c5f28df5a6ba0de35e121ddb1be80e50dfa2b137873'),
      'new_zip':(NEW_TAG,'MountainStill-v1.3.27-test.1-Windows-x86_64.zip',114556300,'3dae6af8dd4c5bacdd91f4e5ff4552065a1518ebf0134e85fd3923b3394f3f58'),
      'pck':(NEW_TAG,'MountainStill-windows.pck',78493332,'11c558dc20e0cf5172ab3ab982b8c88ed2c52cedc54e67c81b7248276f7b1f92'),
    })


def require_environment():
    arch=platform.machine().lower()
    native=(sys.platform=='win32' and arch in ('amd64','x86_64')) or (sys.platform=='darwin' and arch in ('arm64','x86_64'))
    if (not native or os.environ.get('GITHUB_ACTIONS')!='true'
            or os.environ.get('RUNNER_ENVIRONMENT')!='github-hosted'
            or os.environ.get('GITHUB_REPOSITORY')!='lemoncat7/MountainStill'):
        raise RuntimeError('Only official disposable fixed-public-repository Windows x64/macOS ARM64/Intel runners')


def budget(deadline,reserve=0):
    if deadline-time.monotonic()<=reserve:raise RuntimeError('COMPAT_TOTAL_DEADLINE: incomplete is not PASS')


def stopped(registry):
    if not registry or any(p.poll() is None for p in registry):raise RuntimeError('Owned process exit unconfirmed')


def digest(path):
    if path.is_symlink() or not path.is_file():raise RuntimeError('Unsafe/missing evidence file')
    hasher=hashlib.sha256()
    with path.open('rb') as stream:
        while block:=stream.read(1024*1024):hasher.update(block)
    return hasher.hexdigest()


def fetch_pinned(key,root,deadline):
    tag,name,size,sha=PINS[key];path=root/name;budget(deadline,150)
    url='https://github.com/lemoncat7/MountainStill/releases/download/'+tag+'/'+name
    hasher=hashlib.sha256();count=0
    with urllib.request.urlopen(url,timeout=45) as response,path.open('xb') as sink:
        while block:=response.read(1024*1024):
            budget(deadline,150);count+=len(block)
            if count>size:raise RuntimeError('Pinned payload too large')
            hasher.update(block);sink.write(block)
    if count!=size or hasher.hexdigest()!=sha:raise RuntimeError('Pinned payload size/SHA mismatch')
    gate.emit('COMPAT_PIN_VERIFIED',dict(key=key,tag=tag,name=name,size=size,sha256=sha))
    return path


def bounded_json(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_size>65536:raise RuntimeError('Unsafe journal')
    data=json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(data,dict):raise RuntimeError('Journal object required')
    return data


def installed_record(manifest):
    if any(type(manifest.get(key)) is not int for key in ('schema','bootstrap','save_schema')):
        raise RuntimeError('Manifest schema fields must be integers, not booleans')
    if {key:manifest.get(key) for key in ('schema','version','engine','bootstrap','save_schema')} != dict(schema=1,version=NEW_VERSION,engine='4.6.3',bootstrap=1,save_schema=4):
        raise RuntimeError('Unexpected pinned manifest compatibility fields')
    package=manifest.get('packages',{}).get(PLATFORM,{})
    _,name,size,sha=PINS['pck']
    if package.get('restart_required') is not True or package != dict(kind='pck',asset=name,size=size,sha256=sha,restart_required=True):
        raise RuntimeError('Unexpected pinned manifest package')
    return dict(schema=1,version=NEW_VERSION,engine='4.6.3',bootstrap=1,save_schema=4,
        platform=PLATFORM,**package,path='user://updates/'+sha+'.pck')


def assert_owner(userdata,token):
    marker=userdata/'.native-package-ci-owner'
    if userdata.is_symlink() or marker.is_symlink() or not marker.is_file() or marker.read_text(encoding='ascii')!=token:
        raise RuntimeError('Userdata ownership unverified')


def stage_installed_fixture(userdata,token,pck,manifest,registry):
    stopped(registry);assert_owner(userdata,token)
    record=installed_record(manifest);updates=userdata/'updates'
    if pck.stat().st_size!=record['size'] or digest(pck)!=record['sha256']:
        raise RuntimeError('External PCK byte verification failed')
    if updates.is_symlink() or not updates.is_dir():raise RuntimeError('Unsafe updates directory')
    for name in ('active.json','previous.json','booting.json','pending.json'):
        if (updates/name).exists() or (updates/name).is_symlink():raise RuntimeError('Refuse existing journal overwrite')
    save=userdata/'cultivation_save.json';backup=Path(str(save)+'.bak')
    gate.save_snapshot(save);gate.save_snapshot(backup)
    prefix='snapshot-compat-'+uuid.uuid4().hex
    snapshot_digests={}
    for suffix in ('','.bak'):
        source=Path(str(save)+suffix);destination=updates/(prefix+suffix)
        if destination.exists():raise RuntimeError('Snapshot collision')
        shutil.copyfile(source,destination)
        snapshot_digests[suffix]=digest(source)
        if digest(destination)!=snapshot_digests[suffix]:raise RuntimeError('Snapshot copy mismatch')
    packpath=updates/(record['sha256']+'.pck')
    if packpath.exists() or packpath.is_symlink():raise RuntimeError('Pack destination already exists')
    shutil.copyfile(pck,packpath)
    if digest(packpath)!=record['sha256']:raise RuntimeError('Installed PCK copy mismatch')
    previous=dict(record={},snapshot=dict(files={'':True,'.bak':True},prefix=prefix))
    for name,value in [('previous.json',previous),('booting.json',dict(phase='armed',sha256=record['sha256'])),('active.json',record)]:
        with (updates/name).open('x',encoding='utf-8') as stream:json.dump(value,stream,ensure_ascii=False,allow_nan=False)
    gate.emit('EXTERNAL_INSTALLED_UPDATE_FIXTURE',dict(version=NEW_VERSION,host=OLD_VERSION,
        phase='armed',network_download_and_activate_pending='NOT_TESTED',rollback='NOT_EXECUTED',
        protected_old_service='NOT_UPGRADED',primary_sha256=snapshot_digests[''],backup_sha256=snapshot_digests['.bak']))
    return dict(record=record,previous=previous,snapshots=snapshot_digests,pack_sha=record['sha256'])


def verify_installed_health(userdata,fixture):
    updates=userdata/'updates'
    if (updates/'booting.json').exists() or (updates/'booting.json').is_symlink():
        raise RuntimeError('HEALTH_FAILURE: application did not clear armed/launching journal')
    if bounded_json(updates/'active.json')!=fixture['record']:raise RuntimeError('Active record changed or rolled back')
    if bounded_json(updates/'previous.json')!=fixture['previous']:raise RuntimeError('Previous snapshot journal changed')
    if digest(updates/(fixture['pack_sha']+'.pck'))!=fixture['pack_sha']:raise RuntimeError('Installed PCK changed')
    prefix=fixture['previous']['snapshot']['prefix']
    for suffix,sha in fixture['snapshots'].items():
        if digest(updates/(prefix+suffix))!=sha:raise RuntimeError('Old-save snapshot changed')


def recovery(before,after,backup,offline_upper):
    if not gate.number(offline_upper) or offline_upper>=120:raise RuntimeError('Offline bound invalid')
    for key in ('lifetime_seconds','qi','herbs','dew','journey_completed','journey_bond'):
        if not before[key]<=backup[key]<=after[key]:raise RuntimeError('Save primary/backup rollback: '+key)
    for data in (backup,after):
        for key in ('realm','activity','auto_advance','outfit','weapon','technique'):
            if data.get(key)!=before.get(key):raise RuntimeError('Old choice lost: '+key)
        for key in ('paused','low_power'):
            if data.get('settings',{}).get(key)!=before.get('settings',{}).get(key):raise RuntimeError('Old setting lost: '+key)
        if data.get('journey',{})!=before.get('journey',{}):raise RuntimeError('Default old journey changed')
        for key,value in before.get('counters',{}).items():
            if data.get('counters',{}).get(key,-1)<value:raise RuntimeError('Old counter lost: '+key)
    for key,value in before.get('counters',{}).items():
        if not value<=backup.get('counters',{}).get(key,-1)<=after.get('counters',{}).get(key,-1):
            raise RuntimeError('Primary/backup counter chain rollback: '+key)
    life=after['lifetime_seconds']-before['lifetime_seconds'];prior=backup['lifetime_seconds']-before['lifetime_seconds']
    if life<=offline_upper+10 or prior<=offline_upper+5:raise RuntimeError('No live recovery beyond offline credit')
    return dict(lifetime_gain=life,prior_save_lifetime_gain=prior,offline_upper_seconds=offline_upper,
        primary_backup_lifetime_delta=after['lifetime_seconds']-backup['lifetime_seconds'],
        schema=after['version'],old_schema_migration='NOT_TESTED; v26 and v27-test.1 schema4')


def scenario(kind,old_binary,new_binary,pck,manifest,root,deadline,all_registry):
    token=uuid.uuid4().hex;userdata=gate.userdata_path();owned=False;completed=0
    registry=[];rows=[]
    try:
        gate.claim_userdata(userdata,token);owned=True
        (userdata/'updates').mkdir();(userdata/'updates'/'preferences.cfg').write_text('[updates]\nauto_check=false\n',encoding='utf-8')
        gate.emit('COMPAT_SCENARIO_START',dict(scenario=kind,userdata=str(userdata),fresh_independent_case=True))
        budget(deadline,150)
        session(old_binary,root,kind+'_old_seed',OLD_VERSION,rows,registry,deadline)
        all_registry.extend(registry);stopped(registry)
        save=userdata/'cultivation_save.json';backup_path=Path(str(save)+'.bak')
        baseline=gate.save_snapshot(save);gate.save_snapshot(backup_path)
        if baseline.get('activity')!='meditate' or baseline.get('auto_advance') is not False or baseline.get('journey',{})!={}:
            raise RuntimeError('Unexpected default old save; no fixture editing permitted')
        previous=baseline;expected_sha=digest(save);expected_backup_sha=digest(backup_path)
        installed=None
        if kind=='installed_pck':installed=stage_installed_fixture(userdata,token,pck,manifest,registry)
        for number in (1,2):
            budget(deadline,150);stopped(registry)
            if digest(save)!=expected_sha or digest(backup_path)!=expected_backup_sha:
                raise RuntimeError('Primary/backup chain altered before target boot')
            if kind=='full_upgrade' and (userdata/'updates'/'active.json').exists():raise RuntimeError('Full upgrade case must not have active pack')
            gate.emit('COMPAT_RESTORE_START',dict(scenario=kind,restore=number,primary_sha256=expected_sha,backup_sha256=expected_backup_sha,
                old_save_content_edited=False,host_version=OLD_VERSION if installed else NEW_VERSION))
            count=len(registry)
            result=session(old_binary if installed else new_binary,root,kind+'_restore_'+str(number),NEW_VERSION,rows,registry,deadline)
            all_registry.extend(registry[count:]);stopped(registry)
            after=gate.save_snapshot(save);backup=gate.save_snapshot(backup_path)
            evidence=recovery(previous,after,backup,result['ready_epoch']-previous['saved_at']+1)
            if list(userdata.glob('*invalid*')):raise RuntimeError('Invalid-save recovery occurred')
            if installed:verify_installed_health(userdata,installed)
            actual_sha=digest(save)
            if actual_sha==expected_sha:raise RuntimeError('Save unchanged after target boot')
            completed+=1
            gate.emit('COMPAT_RESTORE_VERIFIED',dict(scenario=kind,restore=number,primary_sha256=actual_sha,
                backup_sha256=digest(backup_path),healthy_journal_cleared_by_app=bool(installed),**evidence))
            previous=after;expected_sha=actual_sha;expected_backup_sha=digest(backup_path)
        budget(deadline)
        return dict(scenario=kind,status='PASS_REPRESENTATIVE_ONLY',seed_boots=1,restores=completed)
    except Exception as error:
        gate.emit('COMPAT_SCENARIO_FAILURE',dict(scenario=kind,completed_restores=completed,type=type(error).__name__,message=str(error)))
        raise
    finally:
        # Session registers before launch can fail; retain all references for cleanup decisions.
        for child in registry:
            if child not in all_registry:all_registry.append(child)
        if owned and all(p.poll() is not None for p in registry):gate.cleanup_userdata(userdata,token)
        elif owned:raise RuntimeError('Owned process still live; compatibility userdata preserved')


def main():
    gate.configure_output();deadline=time.monotonic()+DRIVER_SECONDS;registry=[];results=[];success=False
    try:
        require_environment()
        with tempfile.TemporaryDirectory(prefix='mountainstill-gui-compat-',dir=os.environ['RUNNER_TEMP']) as folder:
            root=Path(folder)
            files={key:fetch_pinned(key,root,deadline) for key in PINS}
            manifest=bounded_json(files['manifest']);installed_record(manifest)
            oldroot=root/'old';newroot=root/'new';gate.extract(files['old_zip'],oldroot);gate.extract(files['new_zip'],newroot)
            relative='MountainStill/MountainStill.exe' if PLATFORM=='windows' else gate.APP+'.app/Contents/MacOS/'+gate.APP
            old_binary=oldroot/relative;new_binary=newroot/relative
            original_hashes={str(path):digest(path) for path in (old_binary,new_binary)}
            budget(deadline,150)
            if PLATFORM=='windows':
                prepared=native_json(['powershell','-NoProfile','-NonInteractive','-File',
                    str(Path(__file__).with_name('native_gui_capture.ps1')),'-PrepareAssembly',
                    '-NativeAssembly',str(root/'capture.dll')],timeout=120)
                if prepared.get('status')!='HELPER_PREPARED':raise RuntimeError('Native Windows helper preparation failed')
            else:
                with (root/'helper.compile.txt').open('wb') as sink:
                    built=subprocess.run(['swiftc','-target',platform.machine()+'-apple-macosx15.0','-parse-as-library',
                        str(Path(__file__).with_name('native_gui_capture.swift')),'-o',str(root/'capture')],stdout=sink,stderr=subprocess.STDOUT,timeout=120)
                if built.returncode:raise RuntimeError('Native helper compile failed')
            for kind in ('full_upgrade','installed_pck'):
                results.append(scenario(kind,old_binary,new_binary,files['pck'],manifest,root,deadline,registry))
            for name,sha in original_hashes.items():
                if digest(Path(name))!=sha:raise RuntimeError('Original package executable changed')
            budget(deadline);success=len(results)==2
    except Exception as error:gate.emit('COMPAT_FAILURE',dict(type=type(error).__name__,message=str(error)))
    finally:
        if any(p.poll() is None for p in registry):success=False
        if time.monotonic()>=deadline:success=False
        summary='## Native representative old-save / installed-PCK compatibility\n\n'+('PASS representative two scenarios, six actual boots' if success else 'FAIL/incomplete representative compatibility')+'\n\n'+json.dumps(results)+'\n\nNot a50-cycle matrix, old-schema migration, network update/download/UI activation, rollback, Service upgrade, visual/audio or formal-release acceptance. Old headless failures retained.\n'
        print(summary,flush=True)
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            with open(os.environ['GITHUB_STEP_SUMMARY'],'a',encoding='utf-8') as sink:sink.write(summary)
    return 0 if success else 1


if __name__=='__main__':sys.exit(main())
