#!/usr/bin/env python3
"""Describe exact continuous native movie coverage and verify delivery size limits."""
import hashlib, json, pathlib, re, subprocess, sys
out = pathlib.Path(sys.argv[1])
source = next(p for p in (out/'native.ogv', out/'native.avi') if p.exists())
def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''): h.update(block)
    return h.hexdigest()
def probe(p):
    return json.loads(subprocess.check_output(['ffprobe','-v','error','-show_format','-show_streams','-of','json',str(p)]))
info=probe(source)
video=next(s for s in info['streams'] if s['codec_type']=='video')
log=(out/'native.log').read_text()
m=re.search(r'(\d+) frames at 60 FPS',log)
assert m, 'Native writer completion/frame count absent'
source_frames=int(m[1]); source_seconds=source_frames/60
clips=[]; next_frame=0
for i,p in enumerate(sorted((out/'clips').glob('*.mp4'))):
    inf=probe(p); v=next(s for s in inf['streams'] if s['codec_type']=='video')
    size=p.stat().st_size; assert size<=8*1024*1024,(p,size)
    n=int(v['nb_frames']); start=next_frame; next_frame+=n
    clips.append({'file':p.name,'bytes':size,'sha256':sha(p),'video_frames_30fps':n,
      'video_duration_seconds':n/30,'container_duration_seconds':float(inf['format']['duration']),
      'continuous_playback_start_seconds':start/30,'continuous_playback_end_seconds':next_frame/30,
      'source_start_frame_60fps':min(start*2,source_frames),'source_end_frame_exclusive_60fps':min(next_frame*2,source_frames),
      'source_start_seconds':min(start*2,source_frames)/60,'source_end_seconds':min(next_frame*2,source_frames)/60,
      'width':v['width'],'height':v['height'],'video_codec':v['codec_name'],
      'streams':[{'type':s['codec_type'],'codec':s['codec_name'],'rate':s.get('r_frame_rate')} for s in inf['streams']]})
assert abs(next_frame/30-source_seconds)<=1/30+1e-6, (next_frame,source_frames)
report={'method':'One uninterrupted native Godot MovieMaker take. Fixed 60 fps process delta and movie timeline; ordinary 1x gameplay, no skipped intervals, checkpoint substitution, speed scaling or cuts. Transcoded to 30 fps and split near 150-second keyframe boundaries. Exact measured boundaries are listed for each clip; the first part may be longer due to encoder keyframe/timestamp alignment.',
 'frame_convention':'Frame intervals are zero-based, start-inclusive/end-exclusive. 60-to-30 fps cadence conversion may round the last half-frame by at most 1/30 second. AAC/container padding is listed separately and is not omitted game time.',
 'native_source':{'file':source.name,'bytes':source.stat().st_size,'sha256':sha(source),'frames':source_frames,'fps':60,'duration_seconds':source_seconds,'container_duration_seconds':float(info['format']['duration']),'video_codec':video['codec_name'],'width':video['width'],'height':video['height']},
 'total_playback_frames_30fps':next_frame,'total_playback_video_seconds':next_frame/30,'clips':clips}
p=out/'clips-manifest.json'; p.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
(out/'clips-manifest.sha256').write_text(sha(p)+'  clips-manifest.json\n')
print(json.dumps({'clips':len(clips),'native_seconds':source_seconds,'playback_seconds':next_frame/30,'largest_bytes':max(c['bytes'] for c in clips),'manifest_sha256':sha(p)},indent=2))
