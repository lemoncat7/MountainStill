#!/usr/bin/env python3
"""Inspect artifact architectures/ZIP integrity. This is not an OS runtime test."""
from pathlib import Path
import hashlib
import plistlib
import stat
import struct
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
B = ROOT / "builds"

windows = (B / "windows/MountainStill.exe").read_bytes()
assert windows[:2] == b'MZ', 'Windows DOS header missing'
pe = struct.unpack_from('<I', windows, 0x3c)[0]
assert windows[pe:pe+4] == b'PE\0\0', 'Windows PE header missing'
assert struct.unpack_from('<H', windows, pe+4)[0] == 0x8664, 'Windows executable is not AMD64'
print('PASS: Windows PE x86_64 structure')
with zipfile.ZipFile(B / "MountainStill-Windows-x86_64.zip") as z:
    assert z.testzip() is None, 'Windows ZIP checksum failure'
    assert z.read('MountainStill/MountainStill.exe') == windows, 'Windows ZIP has a stale executable'
    assert 'MountainStill/docs/licenses/MaShanZheng-OFL.txt' in z.namelist(), 'Brush font license missing'
print('PASS: Windows ZIP integrity and exact executable match')

linux = (B / "linux/MountainStill.x86_64").read_bytes()
assert linux[:5] == b'\x7fELF\x02', 'Linux ELF64 header missing'
assert struct.unpack_from('<H', linux, 18)[0] == 62, 'Linux executable is not x86_64'
assert (B / 'linux/MountainStill.x86_64').stat().st_mode & stat.S_IXUSR, 'Linux execute permission missing'
print('PASS: Linux ELF x86_64 structure and execute permission')
with tarfile.open(B / "MountainStill-Linux-x86_64.tar.gz", "r:gz") as archive:
    member = archive.getmember('MountainStill/MountainStill.x86_64')
    assert member.mode & stat.S_IXUSR, 'Linux archive lost execute permission'
    assert archive.extractfile(member).read() == linux, 'Linux archive has a stale executable'
print('PASS: Linux gzip/tar integrity, executable match, and archived execute permission')

with zipfile.ZipFile(B / "MountainStill-macOS-Universal.zip") as z:
    assert z.testzip() is None, 'macOS ZIP checksum failure'
    names = z.namelist()
    app_roots = {n.split('.app/')[0]+'.app/' for n in names if '.app/' in n}
    assert len(app_roots) == 1, 'Expected exactly one macOS app bundle'
    app = app_roots.pop()
    plist = plistlib.loads(z.read(app+'Contents/Info.plist'))
    exe = app+'Contents/MacOS/'+plist['CFBundleExecutable']
    blob = z.read(exe)
    assert blob[:4] == b'\xca\xfe\xba\xbe', 'macOS universal FAT header missing'
    slices = struct.unpack_from('>I', blob, 4)[0]
    architectures = {struct.unpack_from('>I', blob, 8+i*20)[0] for i in range(slices)}
    assert {0x01000007, 0x0100000c}.issubset(architectures), 'Missing Intel or Apple Silicon slice'
    assert (z.getinfo(exe).external_attr >> 16) & stat.S_IXUSR, 'macOS executable permission missing'
    assert app+'Contents/_CodeSignature/CodeResources' in names, 'Ad-hoc signature resources missing'
    assert 'docs/licenses/Godot-LICENSE.txt' in names, 'Runtime license missing'
    assert 'docs/licenses/MaShanZheng-OFL.txt' in names, 'Brush font license missing'
print('PASS: macOS ZIP integrity, bundle plist, Intel/ARM64 slices, permissions, signature-resource presence')

for line in (B / 'SHA256SUMS.txt').read_text().splitlines():
    expected, name = line.split('  ', 1)
    actual = hashlib.sha256((B / name).read_bytes()).hexdigest()
    assert actual == expected, f'Checksum mismatch: {name}'
print('PASS: all published SHA-256 archive checksums')
if (B / 'MountainStill-Source.zip').is_file():
    with zipfile.ZipFile(B / 'MountainStill-Source.zip') as z:
        assert z.testzip() is None, 'Source ZIP checksum failure'
        assert 'MountainStill/assets/cultivation/sources/sanctuary-diorama-source.png' in z.namelist(), 'Current diorama source missing'
        assert 'MountainStill/scripts/ink_pages.gd' in z.namelist(), 'Current ink-page source missing'
    print('PASS: source ZIP integrity and current diorama/ink implementation present')
print('Not tested here: Windows/macOS execution, actual signature validation, Gatekeeper, native window behavior.')
