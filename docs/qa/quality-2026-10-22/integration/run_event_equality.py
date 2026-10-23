import subprocess,pathlib,os,concurrent.futures,json
root=pathlib.Path('/workspace/scratch/778a2592935f')
def run(name):
 env=dict(os.environ)
 for key,sub in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:env[key]=f'/tmp/quality-event-equality/{name}/{sub}'
 with open(root/f'quality-qa/{name}-events.log','w') as f:p=subprocess.run(['godot','--headless','--path',str(root/name),'--script',str(root/'quality-qa/event_equality.gd'),'--','--output='+str(root/f'quality-qa/{name}-events.json')],env=env,stdout=f,stderr=subprocess.STDOUT)
 return p.returncode
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:exits=list(pool.map(run,['recovery-v1311','quality-v1312']))
a=json.load(open(root/'quality-qa/recovery-v1311-events.json'));b=json.load(open(root/'quality-qa/quality-v1312-events.json'))
r={'exit_codes':exits,'encounters':len(a),'events':sum(x['events'] for x in a),'full_event_digests_and_reports_equal':a==b};print(r)
(root/'quality-qa/event-equality-result.json').write_text(json.dumps(r,indent=2))
