import qrcode
import os

version = "2.1.223"
artifacts_dir = r"C:\Users\rodri\.gemini\antigravity\brain\7bb33dc2-0385-4aa1-8b4b-09f1c48c0750"

apks = {
    "Universal": f"https://github.com/agentiabr/financas-casal-flutter/releases/download/v{version}/ControlPig_v{version}_Universal.apk",
    "64bit_arm64": f"https://github.com/agentiabr/financas-casal-flutter/releases/download/v{version}/ControlPig_v{version}_64bit_arm64.apk",
    "32bit_armeabi": f"https://github.com/agentiabr/financas-casal-flutter/releases/download/v{version}/ControlPig_v{version}_32bit_armeabi.apk"
}

for name, url in apks.items():
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=10,
        border=4,
    )
    qr.add_data(url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    
    file_path = os.path.join(artifacts_dir, f"qr_ControlPig_v{version}_{name}.png")
    img.save(file_path)
    print(f"Generated QR Code: {file_path}")
