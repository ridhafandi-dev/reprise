#!/usr/bin/env python3
"""Package the PNG representations into the documented ICNS chunk container."""
from pathlib import Path
import struct
root = Path(__file__).resolve().parent
representations = {'icp4':'16x16', 'icp5':'32x32', 'icp6':'32x32@2x', 'ic07':'128x128', 'ic08':'256x256', 'ic09':'512x512', 'ic10':'512x512@2x', 'ic11':'16x16@2x', 'ic12':'32x32@2x', 'ic13':'128x128@2x', 'ic14':'256x256@2x'}
chunks=[]
for kind,name in representations.items():
    data=(root/'Reprise.iconset'/f'icon_{name}.png').read_bytes()
    chunks.append(kind.encode('ascii')+struct.pack('>I',len(data)+8)+data)
body=b''.join(chunks)
(root/'Reprise.icns').write_bytes(b'icns'+struct.pack('>I',len(body)+8)+body)
