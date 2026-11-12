with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

import re

# Find all cards across sections
print("Checking screen_transacoes...")
tra_idx = text.find('id="screen_transacoes"')
tra_end = text.find('</section>', tra_idx)
tra_content = text[tra_idx:tra_end]

cards_transacoes = re.findall(r'<div[^>]*class="[^"]*(?:rounded-3xl|rounded-2xl|card-fintech)[^"]*"', tra_content)
print(f"Cards in transacoes: {len(cards_transacoes)}")
for c in cards_transacoes[:5]:
    print("  ", c[:100])

print("\nChecking screen_chat...")
chat_idx = text.find('id="screen_chat"')
chat_end = text.find('</section>', chat_idx)
chat_content = text[chat_idx:chat_end]
cards_chat = re.findall(r'<div[^>]*class="[^"]*(?:rounded-3xl|rounded-2xl)[^"]*"', chat_content)
print(f"Cards in chat: {len(cards_chat)}")
for c in cards_chat[:5]:
    print("  ", c[:100])

print("\nChecking full-screen-page cards...")
pages = re.findall(r'<div[^>]*id="([^"]+)"[^>]*class="[^"]*full-screen-page[^"]*"', text)
print(f"Full screen pages count: {len(pages)}")
for p in pages:
    p_idx = text.find(f'id="{p}"')
    p_end = text.find('</div>\n  </div>', p_idx)
    # Check if this page has bg-[#071933] or similar
    p_chunk = text[p_idx:p_idx+300]
    has_dark = re.findall(r'bg-\[#[0-9a-fA-F]+\]', p_chunk)
    print(f"  Page {p}: {has_dark}")
