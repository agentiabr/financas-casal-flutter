import os
import re

html_path = r'C:\Users\rodri\.gemini\antigravity\scratch\financas_casal_flutter\assets\index.html'

with open(html_path, 'r', encoding='utf-8') as f:
    content = f.read()

replacements = []

# 1. modalPetArea - Carteirinhas dos Pets header & nav
old_pet_header = '''      <!-- Cabeçalho do Carrossel com Indicador de Navegação -->
      <div class="flex items-center justify-between px-1">
        <div class="flex items-center gap-2">
          <span class="text-xs font-black uppercase tracking-wider text-slate-600 dark:text-slate-300">Carteirinhas dos Pets</span>
          <span id="petCardsCountBadge" class="text-[10px] font-black px-2 py-0.5 rounded-full bg-amber-100 text-amber-900 border border-amber-300">1 de 3</span>
        </div>
        <div class="flex items-center gap-1 text-[11px] font-bold text-slate-500">
          <span>Deslize para o lado</span>
          <span class="animate-pulse">➔</span>
        </div>
      </div>'''

new_pet_header = '''      <!-- Cabeçalho do Carrossel com Indicador de Navegação -->
      <div class="flex items-center justify-between px-1">
        <div class="flex items-center gap-2">
          <span class="text-xs font-black uppercase tracking-wider text-white drop-shadow-xs">Carteirinhas dos Pets</span>
          <span id="petCardsCountBadge" class="text-[10px] font-black px-2.5 py-0.5 rounded-full bg-amber-400 text-slate-950 font-black shadow-xs">1 de 3</span>
        </div>
        <div class="flex items-center gap-1.5 text-[11px] font-extrabold text-blue-100 bg-white/15 px-3 py-1 rounded-full border border-white/20 backdrop-blur-md shadow-2xs">
          <span>Deslize para o lado</span>
          <span class="animate-pulse">➔</span>
        </div>
      </div>'''
replacements.append((old_pet_header, new_pet_header, "modalPetArea header contrast"))

# 1b. modalPetArea - Pets carousel dots in JS
old_pet_dots = "p.id === activeId ? 'w-6 bg-amber-500' : 'w-2 bg-slate-300 dark:bg-slate-700 hover:bg-amber-300'"
new_pet_dots = "p.id === activeId ? 'w-6 bg-amber-400 shadow-xs' : 'w-2 bg-white/40 hover:bg-white/70'"
replacements.append((old_pet_dots, new_pet_dots, "modalPetArea dots contrast"))

# 2. modalProductWarranties - Title on blue, quick buttons, 3 summary cards
old_warr_title = '<span class="text-[11px] font-black uppercase tracking-wider text-slate-600">Painel de Garantias &amp; Manutenções</span>'
new_warr_title = '<span class="text-xs font-black uppercase tracking-wider text-white drop-shadow-xs">Painel de Garantias &amp; Manutenções</span>'
replacements.append((old_warr_title, new_warr_title, "modalProductWarranties title contrast"))

old_warr_stat_labels = '''        <div class="bg-white rounded-2xl p-3 border border-slate-200/80 shadow-2xs text-center">
          <span class="text-[10px] font-bold uppercase text-slate-400 block">Em Dia / Ativas</span>
          <strong id="warrantyStatActive" class="text-base font-black text-emerald-600">0</strong>
        </div>
        <div class="bg-white rounded-2xl p-3 border border-slate-200/80 shadow-2xs text-center">
          <span class="text-[10px] font-bold uppercase text-slate-400 block">Vencendo (30d)</span>
          <strong id="warrantyStatExpiring" class="text-base font-black text-amber-600">0</strong>
        </div>
        <div class="bg-white rounded-2xl p-3 border border-slate-200/80 shadow-2xs text-center">
          <span class="text-[10px] font-bold uppercase text-slate-400 block">Manutenções / Ext.</span>
          <strong id="warrantyStatExtended" class="text-base font-black text-purple-600">0</strong>
        </div>'''

new_warr_stat_labels = '''        <div class="bg-white rounded-2xl p-3 border border-slate-200/80 shadow-2xs text-center">
          <span class="text-[10px] font-extrabold uppercase text-slate-600 block">Em Dia / Ativas</span>
          <strong id="warrantyStatActive" class="text-base font-black text-emerald-600">0</strong>
        </div>
        <div class="bg-white rounded-2xl p-3 border border-slate-200/80 shadow-2xs text-center">
          <span class="text-[10px] font-extrabold uppercase text-slate-600 block">Vencendo (30d)</span>
          <strong id="warrantyStatExpiring" class="text-base font-black text-amber-600">0</strong>
        </div>
        <div class="bg-white rounded-2xl p-3 border border-slate-200/80 shadow-2xs text-center">
          <span class="text-[10px] font-extrabold uppercase text-slate-600 block">Manutenções / Ext.</span>
          <strong id="warrantyStatExtended" class="text-base font-black text-purple-600">0</strong>
        </div>'''
replacements.append((old_warr_stat_labels, new_warr_stat_labels, "modalProductWarranties stats contrast"))

# 3. modalShoppingListHistory - Tabs
old_shop_tab_g = '<button type="button" onclick="switchShoppingModalTab(\'gondola\')" id="tabBtnShoppingGondola" class="hidden flex-1 py-2 px-3 rounded-2xl text-xs font-bold text-slate-700 bg-white/70 hover:bg-white/95 border border-white/60 shadow-xs flex items-center justify-center gap-1.5 transition-all cursor-pointer backdrop-blur-md">'
new_shop_tab_g = '<button type="button" onclick="switchShoppingModalTab(\'gondola\')" id="tabBtnShoppingGondola" class="hidden flex-1 py-2 px-3 rounded-2xl text-xs font-bold text-blue-100 hover:text-white bg-white/15 hover:bg-white/25 border border-white/20 shadow-xs flex items-center justify-center gap-1.5 transition-all cursor-pointer backdrop-blur-md">'
replacements.append((old_shop_tab_g, new_shop_tab_g, "modalShoppingListHistory gondola tab contrast"))

old_shop_tab_c = '''        <button type="button" onclick="switchShoppingModalTab('comparator')" id="tabBtnShoppingComparator" class="flex-1 py-2 px-3 rounded-2xl text-xs font-bold text-slate-700 hover:text-slate-950 bg-white/70 hover:bg-white/95 border border-white/60 shadow-xs flex items-center justify-center gap-1.5 transition-all cursor-pointer backdrop-blur-md">
          <i data-lucide="bar-chart-2" class="w-3.5 h-3.5 text-slate-600"></i>
          <span>Histórico</span>
        </button>

        <button type="button" id="tabBtnShoppingMarkets" onclick="switchShoppingModalTab('markets')" class="flex-1 py-2 px-3 rounded-2xl text-xs font-bold text-slate-700 hover:text-slate-950 bg-white/70 hover:bg-white/95 border border-white/60 shadow-xs flex items-center justify-center gap-1.5 transition-all cursor-pointer backdrop-blur-md" title="Ver ranking comparativo entre mercados">
          <i data-lucide="scale" class="w-3.5 h-3.5 text-slate-600"></i>
          <span>Comparativo</span>
        </button>'''

new_shop_tab_c = '''        <button type="button" onclick="switchShoppingModalTab('comparator')" id="tabBtnShoppingComparator" class="flex-1 py-2 px-3 rounded-2xl text-xs font-bold text-blue-100 hover:text-white bg-white/15 hover:bg-white/25 border border-white/20 shadow-xs flex items-center justify-center gap-1.5 transition-all cursor-pointer backdrop-blur-md">
          <i data-lucide="bar-chart-2" class="w-3.5 h-3.5 text-blue-200"></i>
          <span>Histórico</span>
        </button>

        <button type="button" id="tabBtnShoppingMarkets" onclick="switchShoppingModalTab('markets')" class="flex-1 py-2 px-3 rounded-2xl text-xs font-bold text-blue-100 hover:text-white bg-white/15 hover:bg-white/25 border border-white/20 shadow-xs flex items-center justify-center gap-1.5 transition-all cursor-pointer backdrop-blur-md" title="Ver ranking comparativo entre mercados">
          <i data-lucide="scale" class="w-3.5 h-3.5 text-blue-200"></i>
          <span>Comparativo</span>
        </button>'''
replacements.append((old_shop_tab_c, new_shop_tab_c, "modalShoppingListHistory tabs contrast"))

old_shop_js_inactive = "const inactiveCls = 'flex-1 py-2 px-3 rounded-2xl text-xs font-bold text-slate-700 hover:text-slate-950 bg-white/70 hover:bg-white/95 border border-white/60 shadow-xs flex items-center justify-center gap-1.5 transition-all cursor-pointer backdrop-blur-md';"
new_shop_js_inactive = "const inactiveCls = 'flex-1 py-2 px-3 rounded-2xl text-xs font-bold text-blue-100 hover:text-white bg-white/15 hover:bg-white/25 border border-white/20 shadow-xs flex items-center justify-center gap-1.5 transition-all cursor-pointer backdrop-blur-md';"
replacements.append((old_shop_js_inactive, new_shop_js_inactive, "switchShoppingModalTab inactive JS contrast"))

# 4. modalKidsArea - Segmented Tab Bar & Subtab Bar
old_kids_tabs = '''      <!-- NAVEGAÇÃO SEGMENTADA POR ABAS DO ESPAÇO KIDS (3 ABAS: BOLETIM À ESQUERDA) -->
      <div class="grid grid-cols-3 gap-1.5 p-1 bg-white/90 dark:bg-slate-800/90 rounded-2xl border border-slate-200/90 shadow-xs text-center select-none">
        <button type="button" id="tabBtnKids_escola" onclick="switchKidsAreaTab('escola')" class="py-2.5 px-2 rounded-xl font-black text-xs transition-all bg-pink-600 text-white shadow-xs flex flex-col sm:flex-row items-center justify-center gap-1.5 cursor-pointer">
          <span class="text-base">📝</span><span class="truncate">Boletim &amp; Aulas</span>
        </button>
        <button type="button" id="tabBtnKids_gastos" onclick="switchKidsAreaTab('gastos')" class="py-2.5 px-2 rounded-xl font-bold text-xs transition-all text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 flex flex-col sm:flex-row items-center justify-center gap-1.5 cursor-pointer">
          <span class="text-base">🎓</span><span class="truncate">Despesas</span>
        </button>
        <button type="button" id="tabBtnKids_game" onclick="switchKidsAreaTab('game')" class="py-2.5 px-2 rounded-xl font-bold text-xs transition-all text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 flex flex-col sm:flex-row items-center justify-center gap-1.5 cursor-pointer">
          <span class="text-base">🎮</span><span class="truncate">Games &amp; Missões</span>
        </button>
      </div>'''

new_kids_tabs = '''      <!-- NAVEGAÇÃO SEGMENTADA POR ABAS DO ESPAÇO KIDS (3 ABAS: BOLETIM À ESQUERDA) -->
      <div class="grid grid-cols-3 gap-1.5 p-1.5 bg-white/15 backdrop-blur-md rounded-2xl border border-white/20 shadow-xs text-center select-none">
        <button type="button" id="tabBtnKids_escola" onclick="switchKidsAreaTab('escola')" class="py-2.5 px-2 rounded-xl font-black text-xs transition-all bg-pink-600 text-white shadow-sm flex flex-col sm:flex-row items-center justify-center gap-1.5 cursor-pointer">
          <span class="text-base">📝</span><span class="truncate">Boletim &amp; Aulas</span>
        </button>
        <button type="button" id="tabBtnKids_gastos" onclick="switchKidsAreaTab('gastos')" class="py-2.5 px-2 rounded-xl font-bold text-xs transition-all text-blue-100 hover:text-white hover:bg-white/10 flex flex-col sm:flex-row items-center justify-center gap-1.5 cursor-pointer">
          <span class="text-base">🎓</span><span class="truncate">Despesas</span>
        </button>
        <button type="button" id="tabBtnKids_game" onclick="switchKidsAreaTab('game')" class="py-2.5 px-2 rounded-xl font-bold text-xs transition-all text-blue-100 hover:text-white hover:bg-white/10 flex flex-col sm:flex-row items-center justify-center gap-1.5 cursor-pointer">
          <span class="text-base">🎮</span><span class="truncate">Games &amp; Missões</span>
        </button>
      </div>'''
replacements.append((old_kids_tabs, new_kids_tabs, "modalKidsArea tabs contrast"))

old_kids_js_inactive = "btn.className = 'py-2.5 px-2 rounded-xl font-bold text-xs transition-all text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 flex flex-col sm:flex-row items-center justify-center gap-1.5 cursor-pointer';"
new_kids_js_inactive = "btn.className = 'py-2.5 px-2 rounded-xl font-bold text-xs transition-all text-blue-100 hover:text-white hover:bg-white/10 flex flex-col sm:flex-row items-center justify-center gap-1.5 cursor-pointer';"
replacements.append((old_kids_js_inactive, new_kids_js_inactive, "switchKidsAreaTab inactive JS contrast"))

old_kids_subtabs = '''        <!-- Sub-navegação interna elegante: Missões dos Pais & Mini-Games -->
        <div class="flex items-center justify-center gap-2 p-1 bg-white/80 dark:bg-slate-800/80 rounded-2xl max-w-sm mx-auto shadow-xs border border-slate-200/80 select-none">
          <button type="button" id="subBtnKidsGame_missoes" onclick="switchKidsGameSubTab('missoes')" class="flex-1 py-2 px-3 rounded-xl font-black text-xs transition-all bg-pink-600 text-white shadow-xs cursor-pointer flex items-center justify-center gap-1.5">
            <span>🏅</span><span>Missões dos Pais</span>
          </button>
          <button type="button" id="subBtnKidsGame_jogos" onclick="switchKidsGameSubTab('jogos')" class="flex-1 py-2 px-3 rounded-xl font-bold text-xs transition-all text-slate-600 dark:text-slate-300 hover:bg-slate-100 cursor-pointer flex items-center justify-center gap-1.5">
            <span>🎮</span><span>Mini-Games</span>
          </button>
        </div>'''

new_kids_subtabs = '''        <!-- Sub-navegação interna elegante: Missões dos Pais & Mini-Games -->
        <div class="flex items-center justify-center gap-2 p-1.5 bg-white/15 backdrop-blur-md rounded-2xl max-w-sm mx-auto shadow-xs border border-white/20 select-none">
          <button type="button" id="subBtnKidsGame_missoes" onclick="switchKidsGameSubTab('missoes')" class="flex-1 py-2 px-3 rounded-xl font-black text-xs transition-all bg-pink-600 text-white shadow-xs cursor-pointer flex items-center justify-center gap-1.5">
            <span>🏅</span><span>Missões dos Pais</span>
          </button>
          <button type="button" id="subBtnKidsGame_jogos" onclick="switchKidsGameSubTab('jogos')" class="flex-1 py-2 px-3 rounded-xl font-bold text-xs transition-all text-blue-100 hover:text-white hover:bg-white/10 cursor-pointer flex items-center justify-center gap-1.5">
            <span>🎮</span><span>Mini-Games</span>
          </button>
        </div>'''
replacements.append((old_kids_subtabs, new_kids_subtabs, "modalKidsArea subtabs contrast"))

old_kids_subjs_inactive = "btnMissoes.className = isMissoes\n          ? 'flex-1 py-2 px-3 rounded-xl font-black text-xs transition-all bg-pink-600 text-white shadow-xs cursor-pointer flex items-center justify-center gap-1.5'\n          : 'flex-1 py-2 px-3 rounded-xl font-bold text-xs transition-all text-slate-600 dark:text-slate-300 hover:bg-slate-100 cursor-pointer flex items-center justify-center gap-1.5';"
new_kids_subjs_inactive = "btnMissoes.className = isMissoes\n          ? 'flex-1 py-2 px-3 rounded-xl font-black text-xs transition-all bg-pink-600 text-white shadow-xs cursor-pointer flex items-center justify-center gap-1.5'\n          : 'flex-1 py-2 px-3 rounded-xl font-bold text-xs transition-all text-blue-100 hover:text-white hover:bg-white/10 cursor-pointer flex items-center justify-center gap-1.5';"
replacements.append((old_kids_subjs_inactive, new_kids_subjs_inactive, "switchKidsGameSubTab missoes inactive JS"))

old_kids_subjs_jogos = "btnJogos.className = !isMissoes\n          ? 'flex-1 py-2 px-3 rounded-xl font-black text-xs transition-all bg-pink-600 text-white shadow-xs cursor-pointer flex items-center justify-center gap-1.5'\n          : 'flex-1 py-2 px-3 rounded-xl font-bold text-xs transition-all text-slate-600 dark:text-slate-300 hover:bg-slate-100 cursor-pointer flex items-center justify-center gap-1.5';"
new_kids_subjs_jogos = "btnJogos.className = !isMissoes\n          ? 'flex-1 py-2 px-3 rounded-xl font-black text-xs transition-all bg-pink-600 text-white shadow-xs cursor-pointer flex items-center justify-center gap-1.5'\n          : 'flex-1 py-2 px-3 rounded-xl font-bold text-xs transition-all text-blue-100 hover:text-white hover:bg-white/10 cursor-pointer flex items-center justify-center gap-1.5';"
replacements.append((old_kids_subjs_jogos, new_kids_subjs_jogos, "switchKidsGameSubTab jogos inactive JS"))

# 5. modalFamilyChat - Add member dashed button on blue
old_chat_add_btn = '<button type="button" onclick="closeFamilyChatModal(); if(typeof openAddUserModal === \'function\'){ openAddUserModal(); } else if(typeof switchScreen === \'function\'){ switchScreen(\'config\'); }" class="w-full py-3.5 px-4 rounded-3xl bg-white hover:bg-slate-50 border border-dashed border-slate-300 text-slate-700 font-black text-xs flex items-center justify-center gap-2 shadow-xs transition-all active:scale-98 cursor-pointer">\n            <i data-lucide="user-plus" class="w-4 h-4 text-blue-600"></i>\n            <span>Adicionar ou Gerenciar Membros da Família</span>\n          </button>'
new_chat_add_btn = '<button type="button" onclick="closeFamilyChatModal(); if(typeof openAddUserModal === \'function\'){ openAddUserModal(); } else if(typeof switchScreen === \'function\'){ switchScreen(\'config\'); }" class="w-full py-3.5 px-4 rounded-3xl bg-white/15 hover:bg-white/25 border-2 border-dashed border-white/40 text-white font-black text-xs flex items-center justify-center gap-2 shadow-sm backdrop-blur-md transition-all active:scale-98 cursor-pointer">\n            <i data-lucide="user-plus" class="w-4 h-4 text-sky-300"></i>\n            <span>Adicionar ou Gerenciar Membros da Família</span>\n          </button>'
replacements.append((old_chat_add_btn, new_chat_add_btn, "modalFamilyChat add member button contrast"))

# 6. modalServiceProviders - Select all bar & Filter pills in JS & Search input
old_sp_select_bar = '''      <!-- 2.5 Barra de Seleção e Ação em Massa -->
      <div class="flex items-center justify-between p-2.5 rounded-2xl bg-slate-100/90 dark:bg-slate-800/90 border border-slate-200 dark:border-slate-700">
        <label class="flex items-center gap-2 cursor-pointer text-slate-700 dark:text-slate-300 font-extrabold select-none text-xs">
          <input type="checkbox" id="spSelectAll" onchange="toggleSelectAllProviders(this.checked)" class="w-4 h-4 rounded text-blue-600 focus:ring-blue-500 cursor-pointer">
          <span id="spSelectAllLabel">Selecionar Todos</span>
        </label>
        <button type="button" id="btnShareSelectedSp" onclick="shareSelectedServiceProvidersWhatsApp()" class="hidden px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-black text-xs flex items-center gap-1.5 shadow-sm cursor-pointer transition-all">
          <span>📲 Compartilhar Selecionados (<span id="spSelectedCount">0</span>)</span>
        </button>
      </div>'''

new_sp_select_bar = '''      <!-- 2.5 Barra de Seleção e Ação em Massa -->
      <div class="flex items-center justify-between p-2.5 rounded-2xl bg-white/15 backdrop-blur-md border border-white/20 shadow-xs">
        <label class="flex items-center gap-2 cursor-pointer text-white font-extrabold select-none text-xs">
          <input type="checkbox" id="spSelectAll" onchange="toggleSelectAllProviders(this.checked)" class="w-4 h-4 rounded text-blue-600 focus:ring-blue-500 cursor-pointer">
          <span id="spSelectAllLabel">Selecionar Todos</span>
        </label>
        <button type="button" id="btnShareSelectedSp" onclick="shareSelectedServiceProvidersWhatsApp()" class="hidden px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-black text-xs flex items-center gap-1.5 shadow-sm cursor-pointer transition-all">
          <span>📲 Compartilhar Selecionados (<span id="spSelectedCount">0</span>)</span>
        </button>
      </div>'''
replacements.append((old_sp_select_bar, new_sp_select_bar, "modalServiceProviders select bar contrast"))

old_sp_search_input = '<input type="text" id="spSearchInput" oninput="renderServiceProvidersList()" placeholder="🔍 Buscar por nome, profissão (ex: eletricista, gás, móveis, pedreiro)..." class="w-full pl-3.5 pr-3 py-2 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white font-semibold text-xs">'
new_sp_search_input = '<input type="text" id="spSearchInput" oninput="renderServiceProvidersList()" placeholder="🔍 Buscar por nome, profissão (ex: eletricista, gás, móveis, pedreiro)..." class="w-full pl-3.5 pr-3 py-2 rounded-xl border border-white/70 bg-white/95 text-slate-900 placeholder-slate-400 font-semibold text-xs shadow-sm">'
replacements.append((old_sp_search_input, new_sp_search_input, "modalServiceProviders search input contrast"))

old_sp_pills_js = "isActive\n              ? 'bg-blue-600 text-white shadow-xs'\n              : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200'"
new_sp_pills_js = "isActive\n              ? 'bg-blue-600 text-white shadow-sm font-black border border-blue-400/40'\n              : 'bg-white/15 backdrop-blur-md text-blue-100 hover:text-white hover:bg-white/25 border border-white/20 font-bold'"
replacements.append((old_sp_pills_js, new_sp_pills_js, "spFilterPills inactive JS contrast"))

# 7. modalHealthMeds - Privacy Card on blue
old_health_priv = '''      <!-- OPCAO: NAO FALAR O NOME NO ALARME (DIRETA E RESPEITOSA) -->
      <div class="mb-3 p-3 rounded-2xl bg-slate-800/60 border border-slate-700 flex items-center justify-between gap-3 text-xs">
        <div class="flex items-center gap-2.5">
          <span class="text-base">&#129323;</span>
          <div>
            <div class="font-bold text-white">Privacidade de Voz no Alarme</div>
            <div class="text-[10px] text-slate-400">Nao falar o nome da pessoa ("Falar apenas: Atencao, hora de tomar seu remedio")</div>
          </div>
        </div>'''

new_health_priv = '''      <!-- OPCAO: NAO FALAR O NOME NO ALARME (DIRETA E RESPEITOSA) -->
      <div class="mb-3 p-3 rounded-2xl bg-white/15 backdrop-blur-md border border-white/20 flex items-center justify-between gap-3 text-xs shadow-xs">
        <div class="flex items-center gap-2.5">
          <span class="text-base">&#129323;</span>
          <div>
            <div class="font-black text-white">Privacidade de Voz no Alarme</div>
            <div class="text-[10px] text-blue-100 font-medium">Nao falar o nome da pessoa ("Falar apenas: Atencao, hora de tomar seu remedio")</div>
          </div>
        </div>'''
replacements.append((old_health_priv, new_health_priv, "modalHealthMeds privacy card contrast"))

# 8. Inside card headers: Educacao & Veiculos & ManageCards & SelectCycle
old_edu_hdr = '<span class="text-[10px] font-bold uppercase tracking-wider text-slate-500">Total Gasto neste Ciclo com Educação</span>'
new_edu_hdr = '<span class="text-[10px] font-extrabold uppercase tracking-wider text-slate-700">Total Gasto neste Ciclo com Educação</span>'
replacements.append((old_edu_hdr, new_edu_hdr, "modalEducacaoHub cycle total label"))

old_veic_hdr = '<span class="text-[10px] font-bold uppercase tracking-wider text-slate-500">Total Gasto neste Ciclo com Transporte</span>'
new_veic_hdr = '<span class="text-[10px] font-extrabold uppercase tracking-wider text-slate-700">Total Gasto neste Ciclo com Transporte</span>'
replacements.append((old_veic_hdr, new_veic_hdr, "modalVeiculosHub cycle total label"))

old_cards_hdr = '<span class="text-xs font-black uppercase tracking-wider text-slate-500">Cartões Cadastrados</span>'
new_cards_hdr = '<span class="text-xs font-black uppercase tracking-wider text-slate-800">Cartões Cadastrados</span>'
replacements.append((old_cards_hdr, new_cards_hdr, "modalManageCards header label"))

old_cycles_hdr = '<span class="text-xs font-black uppercase tracking-wider text-slate-500">Selecione o Ciclo para Visualizar</span>'
new_cycles_hdr = '<span class="text-xs font-black uppercase tracking-wider text-slate-800">Selecione o Ciclo para Visualizar</span>'
replacements.append((old_cycles_hdr, new_cycles_hdr, "modalSelectCycle header label"))

# 9. Style #9 CSS Global Safeguards for Section Contrasts
css_target = "/* 5. MODAIS FULL SCREEN E DIÁLOGOS LIQUID GLASS */"
css_addition = """    /* Harmonização e Refinamento de Contraste nas Seções (Elimina Cinza sobre Azul) */
    .full-screen-page .section-header-contrast,
    .full-screen-page > div > .flex > span[class*="text-slate-600"],
    .full-screen-page > div > .flex > span[class*="text-slate-500"] {
      color: #FFFFFF !important;
      text-shadow: 0 1px 2px rgba(4, 20, 64, 0.5) !important;
    }
    .full-screen-page .section-sub-contrast,
    .full-screen-page > div > .flex > div[class*="text-slate-500"] {
      color: #DBEAFE !important;
    }

    /* 5. MODAIS FULL SCREEN E DIÁLOGOS LIQUID GLASS */"""
replacements.append((css_target, css_addition, "CSS contrast safeguards in style #9"))

# Execute replacements
applied_count = 0
for old, new, desc in replacements:
    if old in content:
        content = content.replace(old, new, 1)
        applied_count += 1
        print(f"[OK] Applied: {desc}")
    else:
        print(f"[FAILED] Target not found: {desc}")

print(f"\nTotal replacements applied: {applied_count}/{len(replacements)}")

if applied_count == len(replacements):
    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("SUCCESS: index.html updated successfully!")
else:
    print("WARNING: Some replacements failed. File was NOT written.")
