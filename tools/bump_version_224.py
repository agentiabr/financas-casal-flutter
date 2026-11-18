with open('pubspec.yaml', 'r', encoding='utf-8') as f:
    pub = f.read()

import re
pub = re.sub(r'version:\s*[0-9\.\+]+', 'version: 2.1.224+302', pub)

with open('pubspec.yaml', 'w', encoding='utf-8') as f:
    f.write(pub)

print("Updated pubspec.yaml to 2.1.224+302")

with open('lib/screens/dashboard_container_screen.dart', 'r', encoding='utf-8') as f:
    dart = f.read()

dart = re.sub(r'2\.1\.[0-9]+', '2.1.224', dart)

with open('lib/screens/dashboard_container_screen.dart', 'w', encoding='utf-8') as f:
    f.write(dart)

print("Updated lib/screens/dashboard_container_screen.dart to 2.1.224")
