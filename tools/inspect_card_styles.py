with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

import re

# Let's inspect the CSS rules in ctrlpigLiquidGlassTheme
start_theme = text.find('<style id="ctrlpigLiquidGlassTheme">')
end_theme = text.find('</style>', start_theme)
theme_css = text[start_theme:end_theme]
print("Theme CSS snippet:")
print(theme_css[:2000])

print("\n--- Card shadow and backgrounds in theme CSS ---")
for line in theme_css.split("\n"):
    if "shadow" in line or "card" in line or "background" in line:
        print(line[:120])
