import os
import time
from playwright.sync_api import sync_playwright

output_dir = r"C:\Users\rodri\.gemini\antigravity\scratch\financas_casal_flutter\design_system"
html_path = os.path.join(output_dir, "preview.html")
file_url = f"file:///{html_path.replace(os.sep, '/')}"

print(f"Loading preview from: {file_url}")

with sync_playwright() as p:
    browser = p.chromium.launch()
    # Viewport large enough to capture the device frame or full frame
    context = browser.new_context(viewport={"width": 1280, "height": 1100})
    page = context.new_page()
    page.goto(file_url, wait_until="networkidle")
    time.sleep(2)  # Wait for icons and Chart.js

    # Helper to capture device frame element
    frame_el = page.locator("#phoneFrame")

    # 1. Dashboard (Screen 1)
    page.evaluate("switchScreen('dashboard')")
    time.sleep(0.5)
    frame_el.screenshot(path=os.path.join(output_dir, "screen1_dashboard.png"))
    print("Saved screen1_dashboard.png")

    # 2. Transações (Screen 2)
    page.evaluate("switchScreen('transacoes')")
    time.sleep(0.5)
    frame_el.screenshot(path=os.path.join(output_dir, "screen2_transacoes.png"))
    print("Saved screen2_transacoes.png")

    # 3. Família & Vida (Screen 3)
    page.evaluate("switchScreen('familia')")
    time.sleep(0.5)
    frame_el.screenshot(path=os.path.join(output_dir, "screen3_familia_vida.png"))
    print("Saved screen3_familia_vida.png")

    # 4. Chat da Família (Screen 4)
    page.evaluate("switchScreen('chat')")
    time.sleep(0.5)
    frame_el.screenshot(path=os.path.join(output_dir, "screen4_chat_familia.png"))
    print("Saved screen4_chat_familia.png")

    # 5. Mascot Overlay (Pitaco Saúde)
    page.evaluate("switchScreen('familia'); triggerSectionMascot('saude');")
    time.sleep(0.6)
    frame_el.screenshot(path=os.path.join(output_dir, "mascot_overlay_saude.png"))
    print("Saved mascot_overlay_saude.png")

    # 6. Landscape Mode
    page.evaluate("toggleMascotOverlay(false); switchScreen('dashboard'); setDeviceFrame('landscape');")
    time.sleep(0.6)
    frame_el.screenshot(path=os.path.join(output_dir, "landscape_dashboard.png"))
    print("Saved landscape_dashboard.png")

    # 7. Full preview overview
    page.evaluate("setDeviceFrame('m62')")
    time.sleep(0.5)
    page.screenshot(path=os.path.join(output_dir, "preview_full_browser.png"))
    print("Saved preview_full_browser.png")

    browser.close()
    print("All screenshots generated successfully!")
