with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

import re

for modal_id in ['modalShoppingListHistory', 'modalManageCards', 'modalPetArea', 'modalHealthMeds', 'modalVeiculosHub', 'modalEducacaoHub', 'modalProductWarranties']:
    m_idx = text.find(f'id="{modal_id}"')
    if m_idx != -1:
        m_chunk = text[m_idx:m_idx+1200]
        # find rounded-2xl or rounded-3xl or bg-white
        cards = re.findall(r'<div[^>]*class="[^"]*(?:rounded-3xl|rounded-2xl|bg-white)[^"]*"', m_chunk)
        print(f"=== {modal_id} ===")
        for c in cards[:3]:
            print(" ", c[:100])
