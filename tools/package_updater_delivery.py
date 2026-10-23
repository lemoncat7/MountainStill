#!/usr/bin/env python3
"""Package seven release assets locally, using the audited source allowlist."""
import argparse, hashlib, json, shutil, subprocess, sys, zipfile
from pathlib import Path
from release_file_policy import exclusion_reason
ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('output', type=Path)
p.add_argument('--version', default='1.3.12-test.1')
a = p.parse_args()
out = a.output.resolve(); out.mkdir(parents=True, exist_ok=True)
build = ROOT / 'builds/updater-release'
subprocess.run([sys.executable, str(ROOT/'tools/verify_updater_artifacts.py'), str(build)], check=True)
subprocess.run([sys.executable, str(ROOT/'tools/package_source.py')], check=True)
docs = [ROOT/n for n in ['README.md','FIRST_TEST_README.md','BUILD_VERIFICATION.md','PUBLICATION_NOTES.md']]
docs += sorted(p for p in (ROOT/'docs').rglob('*') if p.is_file() and exclusion_reason(p.relative_to(ROOT)) is None)
prefix = f'MountainStill-v{a.version}'
win = out / (prefix+'-Windows-x86_64.zip')
with zipfile.ZipFile(win,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    z.write(build/'MountainStill.exe','MountainStill/MountainStill.exe')
    for f in docs: z.write(f,'MountainStill/'+str(f.relative_to(ROOT)))
mac = out / (prefix+'-macOS-Universal.zip')
shutil.copyfile(build/'MountainStill-macOS.zip',mac)
with zipfile.ZipFile(mac,'a',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for f in docs: z.write(f,str(f.relative_to(ROOT)))
source = out/(prefix+'-Public-Source.zip')
shutil.copyfile(ROOT/'builds/MountainStill-Source.zip',source)
for f in [win,mac,source]:
    with zipfile.ZipFile(f) as z:
        assert z.testzip() is None
        for entry in z.infolist():
            assert exclusion_reason(entry.filename.removeprefix("MountainStill/")) is None, entry.filename
with zipfile.ZipFile(source) as z:
    for name in ['.gitignore','BUILD_VERIFICATION.md','FIRST_TEST_README.md','PUBLICATION_NOTES.md','tools/package_updater_delivery.py']:
        assert 'MountainStill/'+name in z.namelist(),name
    for name in z.namelist():
        rel=Path(name)
        assert not any(x in {'.git','.godot','__pycache__','builds'} for x in rel.parts),name
        assert rel.suffix not in {'.log','.pyc','.bak','.mp4','.avi'},name
        assert 'cultivation_save.json' not in name,name
files = [win,mac,source]
for name in ['MountainStill-windows.pck','MountainStill-macos.pck','MountainStill-update.json']:
    target=out/name; shutil.copyfile(build/name,target); files.append(target)
(out/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+f.name+'\n' for f in files))
files.append(out/'SHA256SUMS.txt')
records=[{'name':f.name,'path':str(f),'size':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in files]
(out/'UPLOAD_LIST.json').write_text(json.dumps(records,indent=2)+'\n')
print(json.dumps(records,indent=2))
