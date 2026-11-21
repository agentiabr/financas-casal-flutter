import urllib.request
import time
import ssl
import sys

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

headers = {
    "User-Agent": "Release-Monitor/1.0"
}

def check_apk(url):
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return 0

version = "2.1.226"
apks = [
    ("Universal", f"https://github.com/agentiabr/financas-casal-flutter/releases/download/v{version}/ControlPig_v{version}_Universal.apk"),
    ("64bit_arm64", f"https://github.com/agentiabr/financas-casal-flutter/releases/download/v{version}/ControlPig_v{version}_64bit_arm64.apk"),
    ("32bit_armeabi", f"https://github.com/agentiabr/financas-casal-flutter/releases/download/v{version}/ControlPig_v{version}_32bit_armeabi.apk")
]

print(f"Starting APK wait loop for v{version}...", flush=True)

for attempt in range(50):
    codes = [check_apk(url) for _, url in apks]
    print(f"Check #{attempt+1} - Status APKs: {codes}", flush=True)
    if all(c == 200 for c in codes):
        print("SUCCESS_ALL_APKS_200", flush=True)
        sys.exit(0)
    time.sleep(15)

print("TIMEOUT_WAITING_APKS", flush=True)
sys.exit(1)
