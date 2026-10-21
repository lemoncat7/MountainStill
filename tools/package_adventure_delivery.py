#!/usr/bin/env python3
"""Create <=8MiB byte-exact release segments and transparent offline join helpers."""
from pathlib import Path
import hashlib, json, shutil, subprocess, tarfile, zipfile
ROOT=Path(__file__).resolve().parents[1]
B=ROOT/'builds'
D=B/'adventure-v1'/'delivery-small'
LIMIT=8*1024*1024
SPECS=[('Windows','Windows-x86_64.zip'),('macOS','macOS-Universal.zip'),('Linux','Linux-x86_64.tar.gz'),('Source','Source.zip')]
if D.exists() or D.is_symlink():raise SystemExit('Delivery folder already exists; choose a fresh release directory. Nothing overwritten.')
D.mkdir(parents=True);H=D/'helpers';H.mkdir();records=[]
for kind,suffix in SPECS:
    source=B/('MountainStill-'+suffix)
    original='MountainStill-Adventure-v1-'+suffix
    payload=source.read_bytes();digest=hashlib.sha256(payload).hexdigest();parts=[]
    for index,start in enumerate(range(0,len(payload),LIMIT),1):
        path=D/(original+f'.seg{index:03d}');path.write_bytes(payload[start:start+LIMIT]);parts.append(path)
    combined=b''.join(p.read_bytes() for p in parts)
    assert combined==payload and hashlib.sha256(combined).hexdigest()==digest
    if suffix.endswith('.zip'):
        with zipfile.ZipFile(source) as z:assert z.testzip() is None
    else:
        with tarfile.open(source,'r:gz') as t:
            for entry in t.getmembers():
                if entry.isfile():assert t.extractfile(entry).read() is not None
    destination='MountainStill-Adventure-'+kind
    sh=f'''#!/bin/sh
# Offline byte join, SHA-256 verification and extraction only.
set -eu
cd "$(dirname "$0")"
archive='{original}'
destination='{destination}'
if [ -e "$archive" ] || [ -L "$archive" ] || [ -e "$destination" ] || [ -L "$destination" ]; then
  echo 'Output exists. Use a new empty folder. Nothing was overwritten.' >&2
  exit 1
fi
'''
    for p in parts:sh+=f"test -f '{p.name}' || {{ echo 'Missing {p.name}' >&2; exit 1; }}\n"
    sh+='( set -C; cat '+' '.join("'"+p.name+"'" for p in parts)+' > "$archive" )\n'
    sh+=f'''actual=$(shasum -a 256 "$archive" | awk '{{print $1}}')
if [ "$actual" != '{digest}' ]; then
  echo 'SHA-256 mismatch. Do not extract or run. Download all pieces into a new folder.' >&2
  exit 1
fi
mkdir "$destination"
'''
    sh+=('tar -xzf "$archive" -C "$destination"\n' if suffix.endswith('.tar.gz') else 'unzip -q "$archive" -d "$destination"\n')
    sh+='echo "Verified and extracted to $destination."\n'
    (H/f'Join-{kind}.sh').write_text(sh)
    subprocess.run(['sh','-n',str(H/f'Join-{kind}.sh')],check=True)
    if kind in ('Windows','Source'):
        # Get-Item also detects dangling links; CreateNew refuses existing output.
        quoted=','.join("'"+p.name+"'" for p in parts)
        ps=f"$ErrorActionPreference='Stop'; $a='{original}'; $d='{destination}'; foreach($p in @($a,$d)) {{ if (Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue) {{ throw 'Output exists. Use a new empty folder.' }} }}; $parts=@({quoted}); foreach($p in $parts) {{ if (!(Test-Path -LiteralPath $p -PathType Leaf)) {{ throw ('Missing '+$p) }} }}; $out=[IO.File]::Open($a,[IO.FileMode]::CreateNew); try {{ foreach($p in $parts) {{ $input=[IO.File]::OpenRead($p); try {{ $input.CopyTo($out) }} finally {{ $input.Dispose() }} }} }} finally {{ $out.Dispose() }}; if ((Get-FileHash -LiteralPath $a -Algorithm SHA256).Hash -ne '{digest}') {{ throw 'SHA-256 mismatch. Do not run.' }}; Expand-Archive -LiteralPath $a -DestinationPath $d -ErrorAction Stop; Write-Host ('Verified and extracted to '+$d)"
        cmd='@echo off\r\nrem Offline join, hash check and extraction. No admin or policy changes.\r\nsetlocal\r\ncd /d "%~dp0" || exit /b 1\r\npowershell -NoProfile -Command "'+ps+'"\r\nif errorlevel 1 (\r\n echo Failed. Keep system protections enabled; inspect the message above.\r\n pause\r\n exit /b 1\r\n)\r\npause\r\n'
        (H/f'Join-{kind}.cmd').write_bytes(cmd.encode('ascii'))
    records.append({'platform':kind,'original':original,'source_archive':source.name,'bytes':len(payload),'sha256':digest,'parts':[{'name':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in parts]})
(H/'SHA256SUMS.txt').write_text(''.join(r['sha256']+'  '+r['original']+'\n' for r in records))
counts='\n'.join(f"- {r['platform']}：{len(r['parts'])} 个分片" for r in records)
(H/'READ-ME-ZH.txt').write_text('''山隐 Adventure-v1 分片说明

这些是已校验压缩包的原始字节分片，每个不超过 8 MiB，不能分别解压。
按需下载一组的全部分片，另下载 Join-Tools 工具包：
'''+counts+'''

1. 新建空文件夹，放入同一组的全部 .seg001、.seg002……，不要改名。
2. 解压 Join-Tools，把对应 Join 脚本复制到该文件夹。脚本为明文，仅离线拼接、校验 SHA-256、解压；不安装、不联网、不自动运行游戏、不提升权限或改变安全设置。
3. Windows：双击 Join-Windows.cmd；源码用 Join-Source.cmd，使用系统 PowerShell。
4. macOS：在终端输入 sh 和空格，拖入 Join-macOS.sh 后回车。Linux 用 sh Join-Linux.sh；源码也可用 sh Join-Source.sh。
5. 出现 Verified and extracted 后，打开生成的文件夹。源码由 Godot 4.6.3 打开 project.godot。

缺件则补齐，校验失败则勿运行并重新下载到新文件夹。已有输出或悬空链接会让脚本停止，保护已有数据。遇到系统安全拦截请停止并提供原始警告，不要关闭系统保护或绕过限制。

Windows/macOS 未在目标系统实机执行；Windows 未签名，macOS 为 ad-hoc、未公证。Windows .cmd 未在 Windows 执行；.sh 相同流程会在 Linux验证，并不能据此声称 macOS 运行通过。分片均已逐字节重组、SHA-256 和压缩包完整性校验。其余试玩范围和已知限制详见包内说明。
''')
helper=D/'MountainStill-Adventure-v1-Join-Tools.zip'
with zipfile.ZipFile(helper,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(H.iterdir()):z.write(p,p.name)
(D/'parts-manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
print(json.dumps(records,ensure_ascii=False,indent=2));print('Helpers:',helper)
