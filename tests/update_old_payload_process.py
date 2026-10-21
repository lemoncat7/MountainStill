#!/usr/bin/env python3
"""Run real old installed payload -> new gameplay PCK in isolated Linux Godot.

Arguments: old public release directory, new release/build directory.
Does not execute Windows/macOS OS binaries natively; Linux editor loads their
actual embedded/resource pack and original bootstrap. No source fallback.
"""
import argparse, hashlib, json, os, subprocess, tempfile, zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('old_release', type=Path)
p.add_argument('new_release', type=Path)
a = p.parse_args()
with tempfile.TemporaryDirectory(prefix='mountain-old-payload-') as tmp:
    base = Path(tmp); (base/'empty').mkdir()
    for platform, suffix, extension in [('windows','Windows-x86_64','.exe'),('macos','macOS-Universal','.pck')]:
        archive = a.old_release/f'MountainStill-v1.3.9-test.1-{suffix}.zip'
        with zipfile.ZipFile(archive) as z:
            member = next(n for n in z.namelist() if n.endswith(extension))
            data = z.read(member)
        payload = base/(platform+extension); payload.write_bytes(data)
        print(json.dumps({'old_archive':archive.name,'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
                          'member':member,'payload_sha256':hashlib.sha256(data).hexdigest()}), flush=True)
        env = dict(os.environ, HOME=str(base/platform), XDG_DATA_HOME=str(base/platform/'data'),
                   XDG_CONFIG_HOME=str(base/platform/'config'), XDG_CACHE_HOME=str(base/platform/'cache'))
        result = subprocess.run([os.environ.get('GODOT_BIN','godot'),'--headless','--path',str(base/'empty'),
            '--main-pack',str(payload),'--script',str(ROOT/'tests/update_old_installed_payload.gd'),
            '--',str(a.new_release.resolve()),platform],env=env,text=True,stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,timeout=120)
        print(result.stdout, flush=True)
        assert result.returncode == 0, result.returncode
        assert 'SCRIPT ERROR:' not in result.stdout and '\nERROR:' not in result.stdout
        assert f'OLD_INSTALLED_UPDATE: {platform} immutable 1.3.9 bootstrap/store' in result.stdout and 'health commit PASS' in result.stdout
print('ACTUAL OLD WINDOWS + MACOS INSTALLED PAYLOADS: both upgrade paths PASS (Linux, non-native OS)')
