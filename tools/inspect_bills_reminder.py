with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

idx = text.find('id="modalBillsReminder"')
print("=== modalBillsReminder ===")
print(text[idx:idx+3000])

idx2 = text.find('id="modalRegisterBill"')
print("\n=== modalRegisterBill ===")
print(text[idx2:idx2+1500])
