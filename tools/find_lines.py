with open("assets/index.html", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, l in enumerate(lines):
    if 'id="ctrlpigLiquidGlassTheme"' in l:
        print("Start line:", i+1)
    if i > 4190 and '</style>' in l and i < 4480:
        print("End line:", i+1)
