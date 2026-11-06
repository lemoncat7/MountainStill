#!/usr/bin/env python3
"""Fail before export on omitted runtime scripts and after export on missing bytes.

Every runtime .gd is already required by the actual-ZIP guard. The prebuild gate
checks that same set against each explicit resource list before launching Godot.
Neither check proves target-native execution or replaces actual payload tests.
"""
import argparse
import configparser
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def resource_uri(relative_path):
    return 'res://' + relative_path.as_posix()


def verify_prebuild(project):
    project = Path(project)
    expected = {resource_uri(p.relative_to(project))
                for p in (project/'scripts').rglob('*.gd')}
    assert expected, 'No runtime scripts found for export coverage'
    config = configparser.ConfigParser(interpolation=None)
    config.read_string((project/'export_presets.cfg').read_text())
    checked = []
    errors = []
    for section in config.sections():
        if not re.fullmatch(r'preset\.\d+', section):
            continue
        if config.get(section, 'export_filter', fallback='').strip('"') != 'resources':
            continue  # Non-explicit modes remain covered by the actual-ZIP guard.
        label = config.get(section, 'name', fallback=section).strip('"')
        checked.append(label)
        value = config.get(section, 'export_files', fallback='')
        match = re.fullmatch(r'PackedStringArray\((.*)\)', value, re.S)
        try:
            entries = json.loads('[' + match.group(1) + ']') if match else None
            assert isinstance(entries, list) and all(isinstance(x, str) for x in entries)
        except (ValueError, TypeError, AssertionError):
            errors.append(f'{label}: malformed or missing explicit export_files list')
            continue
        for missing in sorted(expected - set(entries)):
            errors.append(f'{label}: explicit export_files missing {missing}')
    assert checked, 'No explicit resource presets found for prebuild coverage'
    assert not errors, '\n'.join(errors)
    return {'scripts': len(expected), 'presets': checked}


def verify_payload(project, export_zip):
    project = Path(project)
    with zipfile.ZipFile(export_zip) as z:
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
        sources = sorted((project/'scripts').rglob('*.gd')) + [project/'main.tscn', project/'bootstrap.tscn']
        for source in sources:
            rel = source.relative_to(project).as_posix(); require(rel, 'runtime source')
            if rel in names and z.read(rel) != source.read_bytes():
                errors.append(f'{rel}: stale/different exported source')
            text = source.read_text()
            paths = re.findall(r'(?:preload|load)\s*\(\s*["\'](res://[^"\']+)["\']\s*(?=[,)])', text)
            paths += re.findall(r'\[ext_resource[^\]]*path="(res://[^"]+)"', text)
            for path in paths: require(path, rel)
        assert not errors, '\n'.join(errors)
        return {'sources': len(sources), 'dependencies': len(checked)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('export_zip', type=Path, nargs='?')
    parser.add_argument('--prebuild', action='store_true')
    args = parser.parse_args()
    if not args.prebuild and args.export_zip is None:
        parser.error('Provide an export ZIP or --prebuild')
    if args.prebuild:
        result = verify_prebuild(ROOT)
        print(f"EXPORT PREBUILD: {result['scripts']} runtime scripts x {len(result['presets'])} explicit presets present PASS")
    if args.export_zip is not None:
        result = verify_payload(ROOT, args.export_zip)
        print(f"EXPORT DEPENDENCIES: {result['sources']} source files and {result['dependencies']} dependency paths present/current PASS")


if __name__ == '__main__':
    main()
