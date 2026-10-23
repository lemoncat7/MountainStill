#!/usr/bin/env python3
"""Native structure verification only; not native execution/signature validation."""
import argparse, hashlib, json, plistlib, struct, zipfile
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('directory',type=Path); a=p.parse_args(); root=a.directory
exe=(root/'MountainStill.exe').read_bytes(); assert exe[:2]==b'MZ'
pe=struct.unpack_from('<I',exe,0x3c)[0]; assert exe[pe:pe+4]==b'PE\0\0' and struct.unpack_from('<H',exe,pe+4)[0]==0x8664
with zipfile.ZipFile(root/'MountainStill-macOS.zip') as z:
 assert z.testzip() is None
 plist_path=next(n for n in z.namelist() if n.endswith('/Contents/Info.plist'))
 info=plistlib.loads(z.read(plist_path)); assert info['CFBundleShortVersionString']=='1.3.21' and info['CFBundleVersion']=='1.3.21'
 prefix=plist_path.removesuffix('Info.plist')
 path=prefix+'MacOS/'+info['CFBundleExecutable']; binary=z.read(path)
 assert struct.unpack_from('>I',binary)[0]==0xcafebabe
 count=struct.unpack_from('>I',binary,4)[0]; cpus={struct.unpack_from('>I',binary,8+20*i)[0] for i in range(count)}
 assert cpus=={0x01000007,0x0100000c}
 assert (z.getinfo(path).external_attr>>16)&0o111
 assert any(n.endswith('/_CodeSignature/CodeResources') for n in z.namelist())
manifest=json.loads((root/'MountainStill-update.json').read_text())
assert manifest['version']=='1.3.21-test.1'
for platform in ['windows','macos']:
 record=manifest['packages'][platform]; data=(root/record['asset']).read_bytes()
 assert len(data)==record['size'] and hashlib.sha256(data).hexdigest()==record['sha256']
print('NATIVE STRUCTURE: Windows AMD64; macOS Universal x86_64/arm64, version1.3.21, executable mode, ad-hoc resources PASS')
print('MANIFEST ACTUAL SIZE/SHA: both platforms PASS')
