with open("assets/index.html", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, l in enumerate(lines):
    if 'id="modalBillsReminder"' in l:
        print("modalBillsReminder line:", i+1)
    if 'id="modalRegisterBill"' in l:
        print("modalRegisterBill line:", i+1)
    if 'function renderBillsReminderList()' in l:
        print("renderBillsReminderList line:", i+1)
