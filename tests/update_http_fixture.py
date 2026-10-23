#!/usr/bin/env python3
"""Local-only deterministic HTTP fixture; never used by shipping updater."""
import hashlib, json, time, copy
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
PACK = b'GDPC' + b'fixture-content-only-not-a-loadable-pack' * 1024
ROOT = 'https://github.com/lemoncat7/MountainStill/releases/download/v1.3.17-test.2/'
MANIFEST = dict(schema=1, save_schema=4, bootstrap=1, engine='4.6.3', version='1.3.17-test.2', packages={'windows': dict(kind='pck', asset='MountainStill-windows.pck', size=len(PACK), sha256=hashlib.sha256(PACK).hexdigest(), restart_required=True)})
BODY = json.dumps(MANIFEST).encode()
RELEASE = dict(tag_name='v1.3.17-test.2', draft=False, prerelease=True, assets=[dict(name=n,state='uploaded',size=len(b),browser_download_url=ROOT+n) for n,b in [('MountainStill-update.json',BODY),('MountainStill-windows.pck',PACK)]])
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        mode, kind = self.path.strip('/').split('/', 1)
        if mode == 'disconnect':
            self.close_connection = True; return
        if mode in ('primary', 'retry', 'past', 'future', 'forbidden', 'bodylimit', 'secondary'):
            self.send_response(429 if mode == 'retry' else 403)
            if mode in ('primary', 'past', 'future'):
                self.send_header('X-RateLimit-Remaining', '0')
                self.send_header('X-RateLimit-Limit', '60')
                self.send_header('X-RateLimit-Reset', str(int(time.time()) + {'primary': 120, 'past': -10, 'future': 999999}[mode]))
            if mode == 'retry': self.send_header('Retry-After', '2')
            body = json.dumps({'message': 'API rate limit exceeded' if mode == 'bodylimit' else 'You have exceeded a secondary rate limit' if mode == 'secondary' else 'Resource not accessible'}).encode()
            self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body); return
        if mode == 'rate':
            self.send_response(429); self.end_headers(); return
        if mode == 'cdn' and kind in ('manifest', 'pack'):
            self.send_response(302); self.send_header('Location','https://release-assets.githubusercontent.com/' + kind); self.end_headers(); return
        if mode == 'redirect' and kind == 'manifest':
            self.send_response(302); self.send_header('Location','http://evil.invalid/untrusted'); self.end_headers(); return
        body = json.dumps([RELEASE]).encode() if kind == 'releases' else BODY if kind in ('manifest','manifest-cdn') else PACK
        if mode in ('hot','badhot'):
            content = dict(schema=1, accent='#843927', message='山色已新，修行依旧。')
            if mode == 'badhot': content['script'] = 'evil.gd'
            payload = json.dumps(content).encode()
            manifest = copy.deepcopy(MANIFEST)
            manifest['packages']['windows'].update(kind='content_json', asset='MountainStill-content.json', size=len(payload), sha256=hashlib.sha256(payload).hexdigest(), restart_required=False)
            manifest_body = json.dumps(manifest).encode()
            release = copy.deepcopy(RELEASE)
            release['assets'] = [dict(name=n,state='uploaded',size=len(b),browser_download_url=ROOT+n) for n,b in [('MountainStill-update.json',manifest_body),('MountainStill-content.json',payload)]]
            body = json.dumps([release]).encode() if kind == 'releases' else manifest_body if kind == 'manifest' else payload
        if mode == 'badjson' and kind == 'releases': body = b'bad-json'
        if mode == 'corrupt' and kind == 'pack': body = b'X' + PACK[1:]
        if mode == 'oversize' and kind == 'pack': body = PACK + b'overflow'
        self.send_response(200); self.send_header('Content-Length',str(len(body))); self.end_headers()
        try:
            if mode == 'slow' and kind == 'pack':
                for i in range(0,len(body),64): self.wfile.write(body[i:i+64]); self.wfile.flush(); time.sleep(.02)
            else: self.wfile.write(body)
        except (BrokenPipeError,ConnectionResetError): pass
    def log_message(self,*args): pass
if __name__ == '__main__': ThreadingHTTPServer(('127.0.0.1',18765),Handler).serve_forever()
