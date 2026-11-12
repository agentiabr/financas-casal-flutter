with open("assets/index.html", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i in range(5365, 5420):
    print(f"{i+1}: {lines[i]}", end="")
