with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

import re

for screen_id in ['screen_dashboard', 'screen_transacoes', 'screen_familia', 'screen_chat']:
    idx = text.find(f'id="{screen_id}"')
    if idx != -1:
        snippet = text[idx-50:idx+350]
        print(f"=== {screen_id} snippet ===")
        print(snippet)
        print()
