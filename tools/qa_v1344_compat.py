"""Linux-only actual previous-client payload compatibility; not native OS testing."""
import argparse,hashlib,os,subprocess,urllib.request,zipfile,json
from pathlib import Path
PINS={
 'windows':('MountainStill-v1.3.43-Windows-x86_64.zip',114667263,'d02b916a8e619c75110cccceb3aec76b8c5ec39df09f8b9b81d17a79f2e3449f','.exe'),
 'macos':('MountainStill-v1.3.43-macOS-Universal.zip',141398612,'a9f2b5b4c94baa05c5d96886385ed48d904d7cc47c72fcc252aca684a222b947','.pck')}
def main():
 p=argparse.ArgumentParser();p.add_argument('candidate',type=Path);p.add_argument('workspace',type=Path);p.add_argument('--godot',required=True);a=p.parse_args()
 root=a.workspace.resolve();root.mkdir(parents=True,exist_ok=False);probe=Path(__file__).resolve().parents[1]/'tests/update_v1344_previous_client.gd'
 for platform,(name,size,sha,suffix) in PINS.items():
  archive=root/name
  with urllib.request.urlopen('https://github.com/lemoncat7/MountainStill/releases/download/v1.3.43/'+name,timeout=90) as src,archive.open('xb') as dst:
   while chunk:=src.read(1024*1024):dst.write(chunk)
  with archive.open('rb') as f:assert archive.stat().st_size==size and hashlib.file_digest(f,'sha256').hexdigest()==sha
  with zipfile.ZipFile(archive) as z:
   names=[n for n in z.namelist() if n.endswith(suffix)];assert len(names)==1
   payload=root/(platform+suffix);payload.write_bytes(z.read(names[0]))
  empty=root/platform;empty.mkdir();env=dict(os.environ,XDG_DATA_HOME=str(empty/'data'),XDG_CONFIG_HOME=str(empty/'config'),XDG_CACHE_HOME=str(empty/'cache'))
  result=subprocess.run([a.godot,'--headless','--path',str(empty),'--main-pack',str(payload),'--script',str(probe),'--',str(a.candidate.resolve()),platform],env=env,capture_output=True,text=True,timeout=90)
  output=result.stdout+result.stderr;(root/(platform+'.log')).write_text(output);print(output,flush=True)
  assert result.returncode==0 and 'SCRIPT ERROR:' not in output and '\nERROR:' not in output and 'PREVIOUS_CLIENT_V1344_PASS '+platform in output
 print('Actual v1.3.43 Windows/macOS payloads, stable/testing candidate manifests and PCK health: PASS (Linux headless only)')
if __name__=='__main__':main()
