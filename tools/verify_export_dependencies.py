#!/usr/bin/env python3
"""Fail export on missing literal preload/load or imported-resource dependencies.

Checks actual exported ZIP bytes, not editor cache or exit status. Static paths only;
final runtime audits and old-installed-bootstrap upgrade remain required.
"""
import argparse, re, zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('export_zip', type=Path)
a = p.parse_args()
with zipfile.ZipFile(a.export_zip) as z:
    names = set(z.namelist()); checked = set(); errors = []
    def require(path, origin):
        path = path.removeprefix('res://')
        if path in checked: return
        checked.add(path)
        if path in names: return
        sidecar = path+'.import'
        if sidecar not in names:
            errors.append(f'{origin}: missing {path}'); return
        text = z.read(sidecar).decode()
        remaps = re.findall(r'"(res://\.godot/imported/[^"\n]+)"', text)
        if not remaps: errors.append(f'{sidecar}: no imported remap')
        for remap in remaps: require(remap, sidecar)
    # Source scripts are expected byte-for-byte, and their literal dependency graph
    # must be satisfied by this export, even when Godot exits zero on omissions.
    sources = sorted((ROOT/'scripts').rglob('*.gd')) + [ROOT/'main.tscn', ROOT/'bootstrap.tscn']
    for source in sources:
        rel = str(source.relative_to(ROOT)); require(rel, 'runtime source')
        if rel in names and z.read(rel) != source.read_bytes():
            errors.append(f'{rel}: stale/different exported source')
        text = source.read_text()
        paths = re.findall(r'(?:preload|load)\s*\(\s*["\'](res://[^"\']+)["\']\s*(?=[,)])', text)
        paths += re.findall(r'\[ext_resource[^\]]*path="(res://[^"]+)"', text)
        for path in paths: require(path, rel)
    assert not errors, '\n'.join(errors)
    print(f'EXPORT DEPENDENCIES: {len(sources)} source files and {len(checked)} dependency paths present/current PASS')
