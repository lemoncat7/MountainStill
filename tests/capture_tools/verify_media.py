#!/usr/bin/env python3
"""Decode every native/MP4 stream and reconcile Theora duplicate frame slots."""
import concurrent.futures, json, pathlib, re, struct, subprocess, sys
out=pathlib.Path(sys.argv[1]); manifest=json.loads((out/'clips-manifest.json').read_text()); logs=out/'media-validation';logs.mkdir(exist_ok=True)
def raw_ogg(p):
 streams={}
 with p.open('rb') as f:
  while True:
   h=f.read(27)
   if not h: break
   assert len(h)==27 and h[:4]==b'OggS','Invalid Ogg page boundary'
   serial=struct.unpack('<I',h[14:18])[0];table=f.read(h[26]);body=f.read(sum(table));off=0
   s=streams.setdefault(serial,{'signature':b'','size':0,'packets':0,'empty_packets':0})
   for n in table:
    if len(s['signature'])<16:s['signature']+=body[off:off+n][:16-len(s['signature'])]
    off+=n;s['size']+=n
    if n<255:
     s['packets']+=1
     if s['size']==0:s['empty_packets']+=1
     s['size']=0
 video=next(s for s in streams.values() if s['signature'].startswith(b'\x80theora'))
 return {'header_packets':3,'total_packets':video['packets'],'frame_slot_packets':video['packets']-3,'zero_length_duplicate_packets':video['empty_packets'],'nonempty_frame_packets':video['packets']-3-video['empty_packets']}
def decode(p):
 stem=p.stem; logfile=logs/(stem+'-full-decode.log')
 with logfile.open('w') as f:r=subprocess.run(['ffmpeg','-hide_banner','-loglevel','repeat+level+warning','-i',str(p),'-map','0','-f','null','-'],stdout=subprocess.DEVNULL,stderr=f)
 text=logfile.read_text(errors='replace')
 c=subprocess.run(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=nb_read_frames,r_frame_rate,width,height','-of','json',str(p)],capture_output=True,text=True)
 count=json.loads(c.stdout)['streams'][0] if c.returncode==0 else {}
 return {'file':p.name,'ffmpeg_full_decode_exit_code':r.returncode,'ffmpeg_error_count':sum(text.count('['+level+']') for level in ('error','fatal','panic')),'ffmpeg_warning_count':text.count('[warning]'),'warning_message_kinds':sorted(set(re.sub(r'^.*?\[warning\] ','',line) for line in text.splitlines() if '[warning]' in line)),'ffprobe_full_frame_decode_exit_code':c.returncode,'ffprobe_error_lines':c.stderr.splitlines(),'decoded_nonempty_video_frames':int(count.get('nb_read_frames',0)),'rate':count.get('r_frame_rate'),'width':count.get('width'),'height':count.get('height'),'decode_log':str(logfile.relative_to(out))}
source=out/manifest['native_source']['file']
paths=[source]+[out/'clips'/c['file'] for c in manifest['clips']]
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:results=list(pool.map(decode,paths))
raw=raw_ogg(source)
writer_frames=int(manifest['native_source']['frames']);represented=results[0]['decoded_nonempty_video_frames']+raw['zero_length_duplicate_packets']
mp4_frames=sum(x['decoded_nonempty_video_frames'] for x in results[1:])
checks={'all_full_decode_exit_zero':all(x['ffmpeg_full_decode_exit_code']==0 and x['ffprobe_full_frame_decode_exit_code']==0 for x in results),'all_full_decode_error_counts_zero':all(x['ffmpeg_error_count']==0 and not x['ffprobe_error_lines'] for x in results),'native_packet_slots_match_writer':raw['frame_slot_packets']==writer_frames,'native_decoded_plus_duplicates_match_writer':represented==writer_frames,'mp4_decoded_frames_match_manifest':mp4_frames==manifest['total_playback_frames_30fps'],'mp4_each_clip_frames_match':all(x['decoded_nonempty_video_frames']==c['video_frames_30fps'] for x,c in zip(results[1:],manifest['clips'])),'mp4_warning_counts_zero':all(x['ffmpeg_warning_count']==0 for x in results[1:]),'elapsed_timeline_difference_at_most_one_output_frame':abs(mp4_frames/30-writer_frames/60)<=1/30+1e-8}
report={'passed':all(checks.values()),'checks':checks,'native_writer_frame_slots':writer_frames,'native_ogg_packets':raw,'native_decoded_plus_duplicate_frame_slots':represented,'mp4_decoded_frames_total':mp4_frames,'native_seconds':writer_frames/60,'mp4_video_seconds':mp4_frames/30,'source':results[0],'clips':results[1:],'duplicate_frame_explanation':'Theora represents an unchanged frame with a zero-length packet. FFmpeg exposes nonempty decoded frames; adding raw zero-length duplicate packets exactly reconciles the native writer frame count. CFR 30 fps conversion preserves the ordinary game timeline. No elapsed gameplay was cut or accelerated.','primary_reference':'https://theora.org/doc/Theora.pdf (section 3.2: zero-length packets represent duplicate frames)','source_warning_note':'The native OGV emits FFmpeg keyframe-marking warnings. They are retained verbatim in the source decode log; full stream decode succeeds, all frame slots reconcile, and delivered H.264 MP4 files are checked separately.'}
(out/'media-verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'passed':report['passed'],'checks':checks,'native_frame_slots':writer_frames,'native_nonempty_decoded':results[0]['decoded_nonempty_video_frames'],'duplicate_packets':raw['zero_length_duplicate_packets'],'mp4_frames':mp4_frames,'source_warnings':results[0]['ffmpeg_warning_count']},indent=2))
sys.exit(0 if report['passed'] else 1)
