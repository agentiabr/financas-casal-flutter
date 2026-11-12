with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

m_idx = text.find('id="modalManageCards"')
print(text[m_idx:m_idx+2000])
