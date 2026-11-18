import time
import urllib.request
import sys

version = "2.1.223"
apks = [
    f"https://github.com/agentiabr/financas-casal-flutter/releases/download/v{version}/ControlPig_v{version}_Universal.apk",
    f"https://github.com/agentiabr/financas-casal-flutter/releases/download/v{version}/ControlPig_v{version}_64bit_arm64.apk",
    f"https://github.com/agentiabr/financas-casal-flutter/releases/download/v{version}/ControlPig_v{version}_32bit_armeabi.apk"
]

print(f"Monitoring release v{version} APKs on agentiabr...", flush=True)
start = time.time()
while True:
    all_ok = True
    statuses = []
    for url in apks:
        req = urllib.request.Request(url, method='HEAD')
        req.add_header('User-Agent', 'Mozilla/5.0')
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                statuses.append(resp.status)
                if resp.status not in (200, 302):
                    all_ok = False
        except Exception as e:
            statuses.append(str(e))
            all_ok = False
    
    elapsed = int(time.time() - start)
    print(f"[{elapsed}s] APK statuses: {statuses}", flush=True)
    if all_ok:
        print("ALL 3 APKS ARE READY (HTTP 200/302)!", flush=True)
        break
    if elapsed > 1800:
        print("Timeout waiting for APKs", flush=True)
        sys.exit(1)
    time.sleep(15)
