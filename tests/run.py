"""Run meaningful lifecycle regressions against the actual shipped Lua source.
Usage: python tests/run.py /path/to/luau
This is a deterministic mock; it does not claim Roblox physics or visual validation.
"""
from pathlib import Path
import subprocess, sys
root=Path(__file__).resolve().parents[1]
sources={'hub':'HzReyzn Hub.lua','flight':'HzReyzn-Flight.lua',
         'loader':'HzReyzn_Halloween.client.lua','nofall':'runtime/NoFallDamage.luau'}
shared=(root/'runtime/NoFallDamage.luau').read_text().strip()
for filename in ['HzReyzn Hub.lua','HzReyzn-Flight.lua']:
    assert (root/filename).read_text().count(shared)==1, 'Shared controller copies drifted: '+filename
media=(root/'runtime/HalloweenMedia.luau').read_text().strip()
for filename in ['HzReyzn Hub.lua']:
    assert (root/filename).read_text().count(media)==1, 'Media resolver copies drifted: '+filename
parts=[]
for name,path in sources.items():
    contents=(root/path).read_text()
    assert ']====]' not in contents
    parts.append(f'{name}=[====[{contents}]====]')
generated=root/'tests/_generated_smoke.luau'
try:
    generated.write_text("local test=require('./behavior')\ntest({"+','.join(parts)+'})\n')
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(generated)],check=True,cwd=root/'tests')
finally:
    generated.unlink(missing_ok=True)
