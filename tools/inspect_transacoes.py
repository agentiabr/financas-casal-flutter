with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

tra_idx = text.find('id="screen_transacoes"')
tra_end = text.find('</section>', tra_idx)
print(text[tra_idx:tra_idx+2500])
