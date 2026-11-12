with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

idx1 = text.find('id="modalBillsReminder"')
idx2 = text.find('id="modalRegisterBill"')
idx3 = text.find('<!--', idx2 + 100)
# print modalBillsReminder
print("Length between modalBillsReminder and modalRegisterBill:", idx2 - idx1)
print(text[idx1:idx2])
