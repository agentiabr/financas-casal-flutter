import os, re, sys, json
sys.stdout.reconfigure(encoding='utf-8')
from py_mini_racer import MiniRacer
P = sys.argv[1] if len(sys.argv) > 1 else os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'assets', 'index.html'))
s = open(P, encoding='utf-8').read()
blocks = re.findall(r'<script(?![^>]*\bsrc=)([^>]*)>(.*?)</script>', s, re.S)
ctx = MiniRacer()
ctx.eval("function __chk(src){ try { new Function(src); return null; } catch(e) { return String(e && e.message || e); } }")
bad = 0
for i, (attrs, code) in enumerate(blocks):
    if 'type=' in attrs and 'javascript' not in attrs and 'module' not in attrs:
        continue
    err = ctx.call('__chk', code)
    if err:
        bad += 1
        print(f'BLOCO {i} ({len(code)} chars) ERRO: {err}')
print(f'{len(blocks)} blocos verificados, {bad} com erro')
sys.stdout.flush()
os._exit(1 if bad else 0)
