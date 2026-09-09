#!/usr/bin/env python3
"""Register only Reprise's native host. No browser settings/history are read."""
import argparse, base64, hashlib, json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--app',required=True);p.add_argument('--extension',required=True);p.add_argument('--browser',choices=['chrome','dia'],default='dia');a=p.parse_args()
app=Path(a.app).resolve(); ext=Path(a.extension).resolve()
assert (app/'Contents/MacOS/RepriseBridge').is_file(), 'Build the app first'
key=base64.b64decode(json.loads((ext/'manifest.json').read_text())['key'])
id=''.join(chr(ord('a')+int(n,16)) for n in hashlib.sha256(key).hexdigest()[:32])
# Dia's Chromium extension runtime uses the Chrome native-host registration.
folder=Path.home()/'Library/Application Support/Google/Chrome/NativeMessagingHosts'
folder.mkdir(parents=True,exist_ok=True)
manifest={'name':'tools.pulsar.reprise','description':'Capture locale Reprise','path':str(app/'Contents/MacOS/RepriseBridge'),'type':'stdio','allowed_origins':[f'chrome-extension://{id}/']}
file=folder/'tools.pulsar.reprise.json';file.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(f'Native host: {file}\nExtension ID: {id}\nLoad unpacked: {ext}')
