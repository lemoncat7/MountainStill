import pathlib,subprocess,os,concurrent.futures,json,time
root=pathlib.Path('/workspace/scratch/778a2592935f/quality-v1312');out=root.parent/'quality-qa/sensitivity';out.mkdir(exist_ok=True)
def run(build):
 env=dict(os.environ)
 for key,sub in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
  env[key]=f'/tmp/quality-sensitivity/{build}/{sub}';pathlib.Path(env[key]).mkdir(parents=True,exist_ok=True)
 with (out/(build+'.log')).open('w') as log:
  p=subprocess.run(['godot','--headless','--path',str(root),'--script','tests/test_encounter_sensitivity.gd','--','--input='+str(root.parent/'quality-qa/final-earned.json'),'--build='+build,'--report='+str(out/(build+'.json'))],env=env,stdout=log,stderr=subprocess.STDOUT)
 result={'build':build,'exit':p.returncode};(out/(build+'-exit.json')).write_text(json.dumps(result));print(result,flush=True);return result
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 results=list(pool.map(run,['sword','fire','guard','control','support']))
(out/'results.json').write_text(json.dumps(results,indent=2))
