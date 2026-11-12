with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

fam_start = text.find('id="screen_familia"')
fam_end = text.find('</section>', fam_start)
print("=== screen_familia ===")
print(text[fam_start:fam_end+10])

tra_start = text.find('id="screen_transacoes"')
tra_end = text.find('</section>', tra_start)
print("\n=== screen_transacoes (first 1000 chars) ===")
print(text[tra_start:tra_start+1000])
