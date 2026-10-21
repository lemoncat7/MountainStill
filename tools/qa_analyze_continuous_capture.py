"""Analyze native recorded frame/event evidence. Does not claim audiovisual audition."""
import argparse, json, collections, statistics, pathlib
p=argparse.ArgumentParser();p.add_argument('events');p.add_argument('--output');a=p.parse_args()
d=json.load(open(a.events)); out={'source_frozen':d['source_frozen'],'engine_time_scale':d['engine_time_scale'],'failed':d['failed'],'seconds':d['seconds'],'bouts':[],'limits':'Event/geometry/frame audit only. Human continuous audiovisual audition is outstanding.'}
for i,b in enumerate(d['bouts']):
 es=[e for e in d['events'] if e['bout']==i];fs=[f for f in d['frames'] if f['bout']==i and f['hero'] and f['enemy']]
 contacts=[e for e in es if e['type']=='contact'];starts=[e for e in es if e['type']=='turn_started'];hero=[e for e in contacts if e['actor']=='hero'];enemy=[e for e in contacts if e['actor']=='enemy']
 sums=collections.Counter();changes=[];prior=None
 for f in fs:
  h=f['hero'];en=f['enemy'];sums[h.get('combat_phase')]+=1
  if prior and h.get('action_id')!=prior['hero'].get('action_id'):changes.append({'time':f['time'],'from':prior['hero'].get('combat_phase'),'to':h.get('combat_phase'),'from_move':prior['hero'].get('combat_move'),'to_move':h.get('combat_move')})
  prior=f
 total_hp_damage=sum(e['damage'] for e in enemy);healing=sum(e.get('heal',0) for e in contacts)
 causal_errors=[]; causal_counter_count=0; contact_by_id={e['contact_id']:e for e in contacts}
 for e in starts:
  if e['actor']!='hero' or not e.get('counter') or 'counter_source' not in e:continue
  cause=contact_by_id.get(e['counter_source'])
  valid=cause is not None and cause['time']<=e['time'] and e.get('counter_earned_at',-1)>=0
  if e.get('counter_kind')=='deflect_counter':valid=valid and cause.get('actor')=='enemy' and cause.get('resolution')=='guard'
  if e.get('counter_kind')=='dodge_chase':valid=valid and cause.get('actor')=='enemy' and cause.get('resolution')=='dodge' and cause.get('damage')==0
  if not valid:causal_errors.append({'action':e['action_id'],'source':e.get('counter_source'),'kind':e.get('counter_kind')})
  else:causal_counter_count+=1
 mismatches=[e['contact_id'] for e in contacts if e['damage'] != e['pre_hp']-e['post_hp'] and not e.get('heal')]
 out['bouts'].append({'route':b['route'],'native_enemy_hp':b['setup']['enemy']['hp'],'start':b['start'],'end':b['end'],'render_seconds':b['seconds'],'duel_seconds':b['duel_seconds'],'hitstop_and_frame_margin':b['seconds']-b['duel_seconds'],'victory':b['victory'],'hero_hp_start':b['setup']['hp'],'hero_hp_end':b['hp_end'],'health_conserved':b['setup']['hp']-total_hp_damage+healing==b['hp_end'],'damage_delta_mismatches':mismatches,'heart':b['setup']['heart'],'actives':b['setup']['actives'],'weapon':b['weapon'],'native_hp_preserved':b['loaded_enemy']['hp']==b['setup']['enemy']['hp'],'skill_counts':dict(collections.Counter(e.get('skill_id') for e in starts if e['actor']=='hero' and e.get('skill_id'))),'hero_basic_forms':dict(collections.Counter(e['move'] for e in starts if e['actor']=='hero' and e.get('action_kind')=='basic')),'enemy_move_families':dict(collections.Counter(e.get('move_family') for e in starts if e['actor']=='enemy')),'enemy_resolutions':dict(collections.Counter(e.get('resolution') for e in enemy)),'hero_resolutions':dict(collections.Counter(e.get('resolution') for e in hero)),'causal_counter_errors':causal_errors,'verified_causal_counter_count':causal_counter_count,'counter_starts':[{'time':e['capture_time'],'kind':e.get('counter_kind'),'move':e['move'],'cause':e.get('counter_source'),'earned_at':e.get('counter_earned_at')} for e in starts if e['actor']=='hero' and e.get('counter')],'poise_breaks':sum(e['type']=='poise_break' for e in es),'hero_phase_frames':dict(sums),'concurrent_active_frame_ratio':sum(f['hero'].get('combat_phase') not in ['idle','ready'] and f['enemy'].get('combat_phase') not in ['idle','ready'] for f in fs)/max(1,len(fs)),'action_transitions':changes})
errors=[]
if out['failed']: errors.append('recorder reported failure')
if not out['source_frozen']: errors.append('runtime source changed during capture')
if out['engine_time_scale'] != 1.0: errors.append('playback speed was altered')
if not 50 <= out['seconds'] <= 90: errors.append('paired review falls outside requested 50–90 second window')
for b in out['bouts']:
 for check in ['victory','health_conserved','native_hp_preserved']:
  if not b[check]:errors.append(b['route']+': '+check+' failed')
 if b['weapon']!='sword' or b['heart'] not in ['breath','stillness'] or b['actives']!=['barrier']:errors.append(b['route']+': review loadout changed')
 if b['damage_delta_mismatches']:errors.append(b['route']+': damage/HP mismatch')
 if b['causal_counter_errors']:errors.append(b['route']+': counter missing genuine causal defense')
 if len(b['hero_basic_forms'])!=3 or len(b['enemy_move_families'])!=3:errors.append(b['route']+': missing authored attack forms')
out['assertion_errors']=errors
text=json.dumps(out,ensure_ascii=False,indent=2);print(text)
if a.output:pathlib.Path(a.output).write_text(text+'\n')

raise SystemExit(1 if errors else 0)
