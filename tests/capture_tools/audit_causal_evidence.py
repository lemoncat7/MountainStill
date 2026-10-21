#!/usr/bin/env python3
import json, pathlib, sys
p=pathlib.Path(sys.argv[1]); d=json.loads(p.read_text()); checks=[]
def check(ok,label):
 checks.append({'passed':bool(ok),'check':label})
 if not ok: print('FAIL:',label)
a=d['actions']; i=d['initial']; f=d['final']; obs=d['observations']
check(not d['failed'] and not d['errors'],'Run completed without driver failures')
check(d['source_frozen'],'Runtime source hashes unchanged through the run')
check(not d['intro_only'] and not d['smoke_only'],'Full journey, not an intro or smoke subset')
check(i['realm']==0 and i['herbs']==3 and i['dew']==1 and i['chests']==1 and not i['inventory'] and not i['materials']['inventory'] and i['victories']==0 and not i['auto'],'Absent save started with published base supplies only')
check(a[0]['button']=='guide_note','First action voluntarily opens the arrival guide')
check(all(x['rect']['width']>0 and x['rect']['height']>0 for x in a),'Every action records a live nonempty production button rectangle')
check(all(a[n]['time']<a[n+1]['time'] for n in range(len(a)-1)),'Action ledger is strictly chronological')
check(a[0]['before']['character_x']==a[0]['after']['character_x'] and a[0]['before']['character_y']==a[0]['after']['character_y'],'Opening first guide does not move the character')
chest=next(x for x in a if x['button']=='first_chest')
check(chest['before']['chests']==1 and chest['after']['chests']==0 and len(chest['after']['inventory'])==1 and not chest['after']['equipped'],'Starter chest earns one item without silently equipping')
study=next(x for x in a if x['button']=='train_technique')
check(study['before']['herbs']-study['after']['herbs']==6 and study['before']['dew']-study['after']['dew']==2,'First study really pays six herbs and two dew')
check(d['milestones']['first_study_finished']-study['time']>=8,'First study includes the ordinary nine-second process wait (click ledger includes reading pause)')
check(sum(x['button']=='breakthrough' for x in a)==15 and f['realm']==15,'All fifteen realm stages advance through separate breakthrough clicks')
check(d['observed_fights']==18 and d['observed_searches']==18,'All eighteen fights and pending corpse searches are observed')
paid=[o for o in obs if 'searched_victory' in o]
check([o['searched_victory'] for o in paid]==list(range(1,19)),'Eighteen rewards are paid consecutively without invisible checkpoint progress')
search=[o for o in obs if 'search_pending' in o]
check(len(search)==18 and all(b['time']-s['time']>=1.18 for s,b in zip(search,paid)),'Every observed 0.8-second pending search precedes payment by at least 1.18 seconds')
check(f['victories']==18 and len(f['clears'])==6 and all(v==1 for v in f['clears'].values()) and len(f['claims'])==6,'Six chapters cleared once and all six first-clear rewards claimed')
craft=[x for x in a if x['button']=='craft_selected']
check(len(craft)>=10 and all(x['before']['materials']!=x['after']['materials'] and x['before']['equipped']==x['after']['equipped'] for x in craft),'Every crafting action changes earned materials and never silently equips')
check(d['reload']['preserved'] and len(d['reload']['keys'])>=19,'Mid-journey ordinary scene reload preserves all recorded earned build fields')
check(any(x['button']=='ending_action' for x in a) and f['journey']['complete'],'Player explicitly writes the completed six-chapter ending')
fight_attempts=[o for o in obs if o.get('phase','').endswith(':fight')]
defeat_events=[o for o in obs if o.get('phase','').endswith(':teleport_return_out') and o['state'].get('stage',{}).get('failed',False)]
retry_actions=[x for x in a if x['button']=='depart_stage' and x['before'].get('stage',{}).get('paused',False)]
encounter_attempts={'total_fight_attempts':len(fight_attempts),'distinct_encounters_observed':d['observed_fights'],'searched_victories':len(paid),'defeat_returns':len(defeat_events),'ui_continuation_clicks':len(retry_actions),'attempts':[{'time':o['time'],'encounter':o['phase'],'hero_hp':o['state']['hero_hp']} for o in fight_attempts],'defeat_events':[{'time':o['time'],'phase':o['phase'],'stage':o['state']['stage'],'hero_hp':o['state']['hero_hp']} for o in defeat_events],'continuations':[{'time':x['time'],'stage':x['before']['stage']} for x in retry_actions]}
native_log=p.parent/'native.log'
runtime_messages={'native_log_present':native_log.exists()}
if native_log.exists():
 lines=native_log.read_text(errors='replace').splitlines()
 runtime_messages.update({'engine_error_lines':[line for line in lines if line.startswith('ERROR:')],'engine_warning_lines':[line for line in lines if line.startswith('WARNING:')],'note':'Driver assertion failures and engine render/backend messages are distinct. Causal checks passing does not mean the engine log is warning/error-free.'})
result={'runtime_messages':runtime_messages,'encounter_attempts':encounter_attempts,'passed':all(x['passed'] for x in checks),'checks':checks,'summary':{'display_server':d['display_server'],'seconds':d['seconds'],'wall_seconds':d['wall_seconds'],'actions':len(a),'crafts':len(craft),'realm':f['realm'],'victories':f['victories'],'chapters':len(f['clears']),'source_frozen':d['source_frozen']}}
q=p.parent/'causal-evidence-audit.json';q.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(result['summary'],ensure_ascii=False,indent=2));print('PASSED' if result['passed'] else 'FAILED',len(checks),'checks')
sys.exit(0 if result['passed'] else 1)
