with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

import re
modals = re.findall(r'<div[^>]*id="(modal[^"]+)"[^>]*class="[^"]*(?:bg-slate-950|bg-slate-900)[^"]*"', text)
print("Modals with bg-slate-950 or bg-slate-900 in outer container:", modals)

inner_dark = re.findall(r'<div[^>]*id="(modal[^"]+)"[\s\S]{1,150}?<div[^>]*class="[^"]*bg-slate-900', text)
print("Modals with inner bg-slate-900:", inner_dark)
