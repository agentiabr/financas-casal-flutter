with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

start = text.find('<style id="ctrlpigLiquidGlassTheme">')
end = text.find('</style>', start)
print(text[start:end+8])
