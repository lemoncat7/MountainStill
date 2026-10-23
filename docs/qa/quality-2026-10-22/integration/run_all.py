import pathlib,subprocess,os,concurrent.futures,json,time,tempfile
root=pathlib.Path('/workspace/scratch/778a2592935f/quality-v1312');out=root.parent/'quality-qa/full';out.mkdir(exist_ok=True)
isolated_base=pathlib.Path(tempfile.mkdtemp(prefix='quality-tests-clean-'))
(out/'isolation-root.txt').write_text(str(isolated_base)+'\n')
tests=sorted(set(root.glob('tests/test_*.gd'))|set(root.glob('tests/update_*test.gd')))
exclude={'test_encounter_sensitivity.gd','update_release_artifacts_test.gd'}
def run(p):
 env=dict(os.environ)
 for k,v in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:env[k]=str(isolated_base/p.stem/v);pathlib.Path(env[k]).mkdir(parents=True,exist_ok=True)
 args=['godot','--headless','--path',str(root),'--script','tests/'+p.name]
 if p.name=='test_encounter_balance.gd':args+=['--','--report='+str(out.parent/'final-earned.json')]
 start=time.monotonic()
 with (out/(p.stem+'.log')).open('w') as log:
  proc=subprocess.Popen(args,env=env,stdout=log,stderr=subprocess.STDOUT)
  while proc.poll() is None:
   time.sleep(.5)
   if 'SCRIPT ERROR:' in (out/(p.stem+'.log')).read_text():proc.terminate();break
  proc.wait()
 r={'test':p.name,'exit':proc.returncode,'seconds':round(time.monotonic()-start,2)};print(r,flush=True);return r
server=subprocess.Popen(['python3',str(root/'tests/update_http_fixture.py')],stdout=open(out/'http.log','w'),stderr=subprocess.STDOUT)
try:
 with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:results=list(pool.map(run,[t for t in tests if t.name not in exclude]))
 (out/'results.json').write_text(json.dumps({'results':results,'separate_required':sorted(exclude)},indent=2))
finally:server.terminate();server.wait()
