with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

idx = text.find('function renderBillsReminderList()')
print(text[idx+1800:idx+4500])
