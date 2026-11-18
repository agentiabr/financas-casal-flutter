with open('assets/index.html', 'r', encoding='utf-8') as f:
    html = f.read()

# 1. Remove bg-[#071933] from all 13 full-screen-page modal div tags
modals_to_fix = [
    'modalManageCards', 'modalFamilyChat', 'modalPetArea', 'modalHealthMeds',
    'modalVeiculosHub', 'modalEducacaoHub', 'modalServiceProviders', 'modalSelectCycle',
    'modalUserProfileSurvey', 'modalProductWarranties', 'modalKidsArea'
]

count_removed = 0
for m in modals_to_fix:
    # Look for id="m" ... bg-[#071933]
    pos = html.find(f'id="{m}"')
    if pos != -1:
        end_tag = html.find('>', pos)
        tag_str = html[pos:end_tag]
        if 'bg-[#071933]' in tag_str:
            new_tag_str = tag_str.replace('bg-[#071933]', '').replace('  ', ' ')
            html = html[:pos] + new_tag_str + html[end_tag:]
            count_removed += 1
            print(f"Removed bg-[#071933] from {m}")

print(f"Total modals updated: {count_removed}")

# 2. Update Style #9 transparent rule
target_rule = '''    /* Remove fundos escuros pretos/sólidos e bacias cinzas em todas as seções e modais */
    .bg-\\[\\#071933\\],
    \\[class\\*="bg-\\[\\#071933\\]"\\],
    section\\[class\\*="bg-\\[\\#071933\\]"\\],
    div\\[class\\*="bg-\\[\\#071933\\]"\\],
    header\\[class\\*="bg-\\[\\#071933\\]"\\],
    .bg-\\[\\#DFEAF7\\],
    \\[class\\*="bg-\\[\\#DFEAF7\\]"\\],
    div\\[class\\*="bg-\\[\\#DFEAF7\\]"\\],
    div\\[id\\*="Container"\\]\\.bg-\\[\\#DFEAF7\\],
    #screen_transacoes,
    #screen_familia,
    #screen_chat,
    #fintechAuroraHero,
    #comparativoMercadosDynamicBody,
    #chatMembersDirectoryView {
      background: transparent !important;
      box-shadow: none !important;
    }'''

import re

# Find the exact string in html
old_block = """    /* Remove fundos escuros pretos/sólidos e bacias cinzas em todas as seções e modais */
    .bg-\[\#071933\],
    [class*="bg-[#071933]"],
    section[class*="bg-[#071933]"],
    div[class*="bg-[#071933]"],
    header[class*="bg-[#071933]"],
    .bg-\[\#DFEAF7\],
    [class*="bg-[#DFEAF7]"],
    div[class*="bg-[#DFEAF7]"],
    div[id*="Container"].bg-\[\#DFEAF7\],
    #screen_transacoes,
    #screen_familia,
    #screen_chat,
    #fintechAuroraHero,
    #comparativoMercadosDynamicBody,
    #chatMembersDirectoryView {
      background: transparent !important;
      box-shadow: none !important;
    }"""

new_block = """    /* Remove fundos escuros pretos/sólidos em seções internas (NUNCA em .full-screen-page nem seu card #DFEAF7) */
    :not(.full-screen-page).bg-\[\#071933\],
    :not(.full-screen-page)[class*="bg-[#071933]"],
    section:not(.full-screen-page)[class*="bg-[#071933]"],
    div:not(.full-screen-page)[class*="bg-[#071933]"],
    header[class*="bg-[#071933]"],
    #screen_transacoes,
    #screen_familia,
    #screen_chat,
    #fintechAuroraHero,
    #comparativoMercadosDynamicBody,
    #chatMembersDirectoryView {
      background: transparent !important;
      box-shadow: none !important;
    }

    /* Telas Full Screen & Modais de Módulos (100% Opacos com Degradê Aurora Oficial, Bloqueando Qualquer Conteúdo Por Trás) */
    .full-screen-page,
    div.full-screen-page,
    div[id^="modal"].full-screen-page {
      position: fixed !important;
      inset: 0 !important;
      z-index: 1050 !important;
      width: 100vw !important;
      height: 100vh !important;
      background-color: var(--liquid-bg-main) !important;
      background-image: var(--liquid-bg-ambient), var(--liquid-bg-gradient) !important;
      background-attachment: fixed !important;
      background-repeat: no-repeat !important;
      background-size: cover !important;
      opacity: 1 !important;
      display: flex !important;
      flex-direction: column !important;
      isolation: isolate !important;
    }
    .full-screen-page.hidden {
      display: none !important;
    }

    /* Cabeçalho Aurora Contínuo Transparente */
    .page-header-back,
    .full-screen-page > .page-header-back,
    .full-screen-page > header,
    .full-screen-page > div:first-child {
      background: transparent !important;
      background-color: transparent !important;
      background-image: none !important;
      color: #FFFFFF !important;
      padding: 0.75rem 1.25rem !important;
      padding-top: max(env(safe-area-inset-top, 0px), 0.75rem) !important;
      padding-bottom: 0.75rem !important;
      display: flex !important;
      align-items: center !important;
      justify-content: space-between !important;
    }

    /* Card Arredondado Interno (#DFEAF7) */
    .full-screen-page > div.bg-\[\#DFEAF7\],
    .full-screen-page > div[class*="bg-[#DFEAF7]"],
    .full-screen-page > .full-screen-inner,
    .full-screen-page > div:nth-child(2) {
      flex: 1 1 0% !important;
      width: calc(100% - 2rem) !important;
      max-width: calc(100% - 2rem) !important;
      margin-left: 1rem !important;
      margin-right: 1rem !important;
      margin-bottom: 1.25rem !important;
      margin-top: 0.25rem !important;
      background-color: #DFEAF7 !important;
      border-radius: 1.5rem !important;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.25), 0 8px 10px -6px rgba(0, 0, 0, 0.2) !important;
      overflow-y: auto !important;
      -webkit-overflow-scrolling: touch !important;
    }"""

if old_block in html:
    html = html.replace(old_block, new_block, 1)
    print("Successfully replaced old_block in Style #9!")
else:
    print("ERROR: old_block not found in html!")

with open('assets/index.html', 'w', encoding='utf-8') as f:
    f.write(html)
print("Updated assets/index.html")
