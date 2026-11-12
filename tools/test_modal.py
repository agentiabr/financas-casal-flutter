with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

import re

m_idx = text.find('id="modalManageCards"')
print("modalManageCards index:", m_idx)
if m_idx != -1:
    print(text[m_idx:m_idx+600])
