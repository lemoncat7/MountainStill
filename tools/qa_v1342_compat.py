"""Linux-only actual previous-client payload compatibility; not native OS testing."""
import argparse,hashlib,os,subprocess,urllib.request,zipfile,json
from pathlib import Path
PINS={
 'windows':('MountainStill-v1.3.41-Windows-x86_64.zip',114644018,'b3affc1ac80d7ac22f7107103531f8895225435852ba226c4d6034c1530a17c4','.exe'),
 'macos':('MountainStill-v1.3.41-macOS-Universal.zip',141375680,'8998cc23f0065ea0caa0e7a88c23b231b949d459b14eb3f50c80eabca550f4ee','.pck')}
def main():
 p=argparse.ArgumentParser();p.add_argument('candidate',type=Path);p.add_argument('workspace',type=Path);p.add_argument('--godot',required=True);a=p.parse_args()
 root=a.workspace.resolve();root.mkdir(parents=True,exist_ok=False);probe=Path(__file__).resolve().parents[1]/'tests/update_v1342_previous_client.gd'
 for platform,(name,size,sha,suffix) in PINS.items():
  archive=root/name
  with urllib.request.urlopen('https://github.com/lemoncat7/MountainStill/releases/download/v1.3.41/'+name,timeout=90) as src,archive.open('xb') as dst:
   while chunk:=src.read(1024*1024):dst.write(chunk)
  with archive.open('rb') as f:assert archive.stat().st_size==size and hashlib.file_digest(f,'sha256').hexdigest()==sha
  with zipfile.ZipFile(archive) as z:
   names=[n for n in z.namelist() if n.endswith(suffix)];assert len(names)==1
   payload=root/(platform+suffix);payload.write_bytes(z.read(names[0]))
  empty=root/platform;empty.mkdir();env=dict(os.environ,XDG_DATA_HOME=str(empty/'data'),XDG_CONFIG_HOME=str(empty/'config'),XDG_CACHE_HOME=str(empty/'cache'))
  result=subprocess.run([a.godot,'--headless','--path',str(empty),'--main-pack',str(payload),'--script',str(probe),'--',str(a.candidate.resolve()),platform],env=env,capture_output=True,text=True,timeout=90)
  output=result.stdout+result.stderr;(root/(platform+'.log')).write_text(output);print(output,flush=True)
  assert result.returncode==0 and 'SCRIPT ERROR:' not in output and '\nERROR:' not in output and 'PREVIOUS_CLIENT_V1342_PASS '+platform in output
 print('Actual v1.3.41 Windows/macOS payloads, stable/testing candidate manifests and PCK health: PASS (Linux headless only)')
if __name__=='__main__':main()
