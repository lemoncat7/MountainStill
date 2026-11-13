#!/usr/bin/env python3
"""Require actual release manifest/PCK bytes to match BOTH compatibility pin sets.

Offline artifact contract only; never downloads or runs native applications.
Usage: python3 tools/verify_native_compatibility_assets.py RELEASE_ASSET_DIRECTORY
"""
import argparse
import hashlib
import importlib
import json
from pathlib import Path
import sys
from unittest.mock import patch
import native_compatibility as compat


def verify(root):
    checked = []
    try:
        for platform in ('win32', 'darwin'):
            with patch.object(sys, 'platform', platform):
                importlib.reload(compat)
                manifest_bytes = None
                for key in ('manifest', 'pck'):
                    tag, name, size, digest = compat.PINS[key]
                    path = root / name
                    if path.is_symlink() or not path.is_file():
                        raise ValueError('Missing/unsafe actual release asset: ' + name)
                    data = path.read_bytes()
                    if tag != compat.NEW_TAG or len(data) != size or hashlib.sha256(data).hexdigest() != digest:
                        raise ValueError('Actual release asset does not match compatibility pin: ' + name)
                    if key == 'manifest':
                        manifest_bytes = data
                value = json.loads(manifest_bytes)
                record = compat.installed_record(value)
                _, name, size, digest = compat.PINS['pck']
                actual = value['packages'][compat.PLATFORM]
                if (actual['asset'], actual['size'], actual['sha256']) != (name, size, digest):
                    raise ValueError('Manifest and actual PCK disagree: ' + compat.PLATFORM)
                if record['sha256'] != digest:
                    raise ValueError('Installed record does not retain actual PCK digest')
                checked.append(compat.PLATFORM)
    finally:
        importlib.reload(compat)
    return checked


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    print('ACTUAL COMPATIBILITY ASSETS: ' + ', '.join(verify(args.directory)) + ' PASS')
