import pathlib,subprocess,json,os,hashlib,time,statistics
workspace=pathlib.Path('/workspace/scratch/778a2592935f');out=workspace/'quality-qa/benchmark';out.mkdir(exist_ok=True)
scenarios=[('bamboo_pass','sword'),('cloud_slope','fan'),('cloud_slope','unarmed')]
results=[]
for route,weapon in scenarios:
 for candidate in ['recovery-v1311','quality-v1312']:
  label=f'{route}-{weapon}-{candidate}'
  env=dict(os.environ)
  for k,s in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:env[k]=str(out/'isolated'/candidate/s)
  cmd=['godot','--headless','--path',str(workspace/candidate),'--script',str(workspace/'performance-qa/benchmark_matrix.gd'),'--',f'--route={route}',f'--weapon={weapon}','--ticks=480','--warmups=2','--trials=7',f'--label={label}',f'--report={out/ (label+".json")}']
  started=time.time()
  with (out/(label+'.log')).open('w') as log: p=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT)
  assert p.returncode==0,(label,p.returncode)
  raw=json.loads((out/(label+'.json')).read_text()); rows=raw['results']
  result={'label':label,'start_unix':started,'end_unix':time.time(),'median_total_ms':statistics.median(x['total_ms'] for x in rows),'median_p50_ms':statistics.median(x['tick']['p50_us'] for x in rows)/1000,'median_p95_ms':statistics.median(x['tick']['p95_us'] for x in rows)/1000,'worst_tick_ms':max(x['tick']['max_us'] for x in rows)/1000}
  results.append(result); print(result,flush=True)
  (out/'summary.json').write_text(json.dumps(results,indent=2))
comparisons=[]
for route,weapon in scenarios:
 a=json.loads((out/f'{route}-{weapon}-recovery-v1311.json').read_text())
 b=json.loads((out/f'{route}-{weapon}-quality-v1312.json').read_text())
 equal=[x['state'] for x in a['results']]==[x['state'] for x in b['results']]
 comparisons.append({'route':route,'weapon':weapon,'all_seven_final_states_equal':equal})
 assert equal,(route,weapon)
(out/'state-equality.json').write_text(json.dumps(comparisons,indent=2))
frozen=json.loads((workspace/'quality-qa/runtime-freeze.json').read_text())['files']
changed=[p for p,h in frozen.items() if hashlib.sha256((workspace/'quality-v1312'/p).read_bytes()).hexdigest()!=h]
assert not changed,changed
(out/'final-source-check.json').write_text(json.dumps({'all_frozen_files_equal':True,'count':len(frozen)},indent=2))
