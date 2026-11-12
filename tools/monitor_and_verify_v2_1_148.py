import time
import json
import urllib.request
import urllib.error
import os
import sys
import qrcode

REPO = "agentiabr/financas-casal-flutter"
VERSION = "v2.1.148"
ARTIFACT_DIR = r"C:\Users\rodri\.gemini\antigravity\brain\7bb33dc2-0385-4aa1-8b4b-09f1c48c0750"
HEADERS = {"User-Agent": "Mozilla/5.0"}

print(f"Buscando run do workflow para a tag {VERSION}...")
run_id = None
for _ in range(15):
    try:
        url = f"https://api.github.com/repos/{REPO}/actions/runs?per_page=5"
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            for run in data.get('workflow_runs', []):
                head_branch = run.get('head_branch')
                head_sha = run.get('head_sha')
                event = run.get('event')
                if head_branch == VERSION or event == 'push':
                    run_id = run.get('id')
                    print(f"Run encontrada: {run_id} ({run.get('name')}) - Status: {run.get('status')}")
                    break
            if run_id:
                break
    except Exception as e:
        print(f"Aviso ao buscar runs: {e}")
    time.sleep(3)

if not run_id:
    print("ERRO: Nenhuma run recente encontrada.")
    sys.exit(1)

print(f"\nMonitorando build {run_id} ({VERSION})...")
while True:
    try:
        url = f"https://api.github.com/repos/{REPO}/actions/runs/{run_id}"
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            status = data.get('status')
            conclusion = data.get('conclusion')
            print(f"[{time.strftime('%H:%M:%S')}] Status: {status}, Conclusao: {conclusion}")
            if status == 'completed':
                if conclusion != 'success':
                    print(f"ERRO: Build completado com falha ({conclusion})")
                    sys.exit(1)
                break
    except Exception as e:
        print(f"Aviso ao consultar GitHub API: {e}")
    time.sleep(20)

print("\nBuild completado com sucesso! Aguardando 20s para propagação da release...")
time.sleep(20)

APKS = {
    "Universal": f"https://github.com/{REPO}/releases/download/{VERSION}/ControlPig_{VERSION}_Universal.apk",
    "64bit_arm64": f"https://github.com/{REPO}/releases/download/{VERSION}/ControlPig_{VERSION}_64bit_arm64.apk",
    "32bit_armeabi": f"https://github.com/{REPO}/releases/download/{VERSION}/ControlPig_{VERSION}_32bit_armeabi.apk"
}

verified_apks = {}
for name, apk_url in APKS.items():
    print(f"Verificando {name} -> {apk_url}")
    for attempt in range(15):
        try:
            req = urllib.request.Request(apk_url, headers=HEADERS)
            with urllib.request.urlopen(req) as resp:
                code = resp.getcode()
                if code == 200:
                    content_len = resp.headers.get('Content-Length', 'desconhecido')
                    print(f"  OK! HTTP 200 - Tamanho: {content_len} bytes")
                    verified_apks[name] = (apk_url, content_len)
                    break
        except urllib.error.HTTPError as he:
            print(f"  Tentativa {attempt+1}: HTTP {he.code}")
        except Exception as e:
            print(f"  Tentativa {attempt+1}: {e}")
        time.sleep(6)
    else:
        print(f"FALHA: Nao foi possivel confirmar 200 OK para {name}")
        sys.exit(1)

print("\nTodos os 3 APKs confirmados com HTTP 200 OK!")
print("Gerando QR Codes...")

for name, (apk_url, size) in verified_apks.items():
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=10,
        border=3,
    )
    qr.add_data(apk_url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="#0F172A", back_color="#FFFFFF")
    out_path = os.path.join(ARTIFACT_DIR, f"qr_ControlPig_{VERSION}_{name}.png")
    img.save(out_path)
    print(f"  QR Code salvo: {out_path}")

print("\nTudo pronto!")
