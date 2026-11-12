import re

with open("assets/index.html", "r", encoding="utf-8") as f:
    text = f.read()

screens = re.findall(r'<section[^>]+id="([^"]+)"', text)
print("Sections:", screens)

full_pages = re.findall(r'id="([^"]+)"[^>]*class="[^"]*full-screen-page', text)
print(f"Full screen pages ({len(full_pages)}):", full_pages)

# Check all elements with dark backgrounds like bg-[#071933], bg-[#0a192f], bg-slate-900, etc.
dark_classes = re.findall(r'class="[^"]*(?:bg-\[#[0-9a-fA-F]+\]|bg-slate-9\d\d|bg-blue-9\d\d|bg-indigo-9\d\d)[^"]*"', text)
print(f"Elements with dark bg classes count: {len(dark_classes)}")

# Also look for CSS rules that define background on screens or cards
css_blocks = re.findall(r'<style[^>]*>(.*?)</style>', text, re.DOTALL)
print(f"Found {len(css_blocks)} style blocks")
for i, block in enumerate(css_blocks):
    if "ctrlpigLiquidGlassTheme" in text[text.find(block)-60:text.find(block)]:
        print("ctrlpigLiquidGlassTheme block found, length:", len(block))
