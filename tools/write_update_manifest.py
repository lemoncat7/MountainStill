#!/usr/bin/env python3
"""Bind reviewed PCK assets to this bootstrap ABI. No network/publication side effects."""
import argparse, hashlib, json
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('directory',type=Path)
p.add_argument('--version',default='1.3.14-test.1')
p.add_argument('--content',action='store_true',help='Build a strict JSON content-only manifest (no restart)')
a=p.parse_args()
packages={}
for platform in ('windows','macos'):
    f=a.directory/('MountainStill-content.json' if a.content else f'MountainStill-{platform}.pck')
    if a.content:
        d=json.loads(f.read_text())
        import re
        assert set(d)=={'schema','accent','message'} and d['schema']==1
        assert re.fullmatch(r'#[0-9a-fA-F]{6}',d['accent'])
        assert isinstance(d['message'],str) and 0<len(d['message'].strip())<=120
        assert all(ord(c)>=32 and ord(c)!=127 for c in d['message'])
        assert f.stat().st_size<=16384
    packages[platform]={'kind':'content_json' if a.content else 'pck','asset':f.name,'size':f.stat().st_size,
                        'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'restart_required':not a.content}
manifest={'schema':1,'version':a.version,'engine':'4.6.3','bootstrap':1,'save_schema':4,'packages':packages}
(a.directory/'MountainStill-update.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
