with open('pubspec.yaml', 'r', encoding='utf-8') as f:
    pub = f.read()

pub = pub.replace('version: 2.1.220+298', 'version: 2.1.221+299')

with open('pubspec.yaml', 'w', encoding='utf-8') as f:
    f.write(pub)

print("Updated pubspec.yaml to 2.1.221+299")

with open('lib/screens/dashboard_container_screen.dart', 'r', encoding='utf-8') as f:
    dart = f.read()

dart = dart.replace('2.1.220', '2.1.221')

with open('lib/screens/dashboard_container_screen.dart', 'w', encoding='utf-8') as f:
    f.write(dart)

print("Updated lib/screens/dashboard_container_screen.dart to 2.1.221")
