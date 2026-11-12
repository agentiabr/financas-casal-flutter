with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

idx2 = text.find('id="modalRegisterBill"')
idx3 = text.find('<!-- ==============================================================', idx2)
print(text[idx2:idx3])
