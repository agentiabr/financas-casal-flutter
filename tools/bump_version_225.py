import re

# 1. Update pubspec.yaml
pubspec_path = r'C:\Users\rodri\.gemini\antigravity\scratch\financas_casal_flutter\pubspec.yaml'
with open(pubspec_path, 'r', encoding='utf-8') as f:
    pubspec = f.read()

new_pubspec = re.sub(r'version:\s*2\.1\.224\+302', 'version: 2.1.225+303', pubspec)
assert new_pubspec != pubspec, "pubspec version not updated!"
with open(pubspec_path, 'w', encoding='utf-8') as f:
    f.write(new_pubspec)
print("Updated pubspec.yaml to 2.1.225+303")

# 2. Update dashboard_container_screen.dart
dart_path = r'C:\Users\rodri\.gemini\antigravity\scratch\financas_casal_flutter\lib\screens\dashboard_container_screen.dart'
with open(dart_path, 'r', encoding='utf-8') as f:
    dart = f.read()

new_dart = dart.replace('2.1.224', '2.1.225')
assert new_dart != dart, "dart version not updated!"
with open(dart_path, 'w', encoding='utf-8') as f:
    f.write(new_dart)
print("Updated dashboard_container_screen.dart to 2.1.225")
