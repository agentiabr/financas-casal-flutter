# Especificação de Componentes ControlPig (HTML & Tailwind)
**Padrão Fintech**: Nubank / Itaú / Revolut  
**IDs e Funções Reais do Aplicativo** (`assets/index.html`)

---

## 1. Cabeçalho Bancário Integrado à Status Bar

Pinta integralmente a barra de status do Android via `padding-top: max(10px, env(safe-area-inset-top))` com o azul institucional profundo (`#0A3981` a `#051C44`).

```html
<!-- CABEÇALHO BANCÁRIO UNIFICADO (STATUS BAR INTEGRADA) -->
<header class="app-header">
  <div class="app-header-inner">
    
    <!-- Lado Esquerdo: Avatar Circular & Boas-Vindas do Membro Ativo -->
    <div class="flex items-center gap-3 cursor-pointer group flex-shrink-0" onclick="openMemberModal()" title="Toque para alternar o membro ativo">
      <div class="relative w-10 h-10 rounded-full border-2 border-sky-400/80 bg-blue-900/60 flex items-center justify-center overflow-hidden shadow-sm">
        <span id="headerUserAvatar" class="text-xl leading-none select-none">👨</span>
        <img id="headerUserAvatarImg" src="" alt="Avatar" class="hidden w-full h-full object-cover">
        <!-- Indicador Online Verde -->
        <span class="absolute bottom-0 right-0 w-3 h-3 rounded-full bg-emerald-400 border-2 border-[#0A3981]"></span>
      </div>

      <!-- Textos: Boas-vindas, Nome e Perfil -->
      <div class="flex flex-col text-left leading-tight">
        <span class="text-[11px] text-blue-200/90 font-medium">Bem-vindo de volta,</span>
        <div class="flex items-center gap-1.5">
          <span id="headerUserName" class="text-base sm:text-lg font-black text-white">Rodrigo</span>
          <span class="text-base">👋</span>
        </div>
        <span id="headerUserRole" class="text-[10px] text-blue-300 font-semibold tracking-wider uppercase">Gestor Familiar</span>
      </div>
    </div>

    <!-- Lado Direito: Ações Rápidas em Pílulas Translúcidas -->
    <div class="flex items-center gap-2">
      <!-- 1. Botão de Busca -->
      <button type="button" onclick="document.getElementById('sectionTable').scrollIntoView({behavior: 'smooth'})" class="header-glass-btn" title="Buscar Lançamentos">
        <i data-lucide="search" class="w-4 h-4 text-white"></i>
      </button>

      <!-- 2. Central de Notificações com Badge Vermelha -->
      <button type="button" onclick="openNotificationsCenterModal()" class="header-glass-btn relative" title="Central de Notificações">
        <i data-lucide="bell" class="w-4 h-4 text-white"></i>
        <span id="headerNotifBadge" class="absolute top-2.5 right-2.5 w-2 h-2 rounded-full bg-rose-500 animate-pulse border border-[#0A3981]"></span>
      </button>

      <!-- 3. Painel Admin / Configurações -->
      <button type="button" onclick="openAdminModal()" class="header-glass-btn" title="Painel Admin e Família">
        <i data-lucide="user" class="w-4 h-4 text-white"></i>
      </button>
    </div>

  </div>

  <!-- Select nativo invisível mantido para compatibilidade total de filtros -->
  <select id="cycleSelector" onchange="onCycleChange()" class="hidden">
    <option value="05/Out a 04/Nov 2026">05/Out a 04/Nov 2026</option>
  </select>
  <div id="dynamicMembersContainer" class="hidden"></div>
</header>
```

---

## 2. Card Herói Azul do Dashboard

Concentra o saldo disponível, controle de privacidade (olhinho), ciclo mensal com menu suspenso, balão interativo do Piggy com setinhas de navegação, e tira inferior de mini-indicadores.

```html
<!-- CARD HERÓI AZUL FLAT COM MASCOTE PIGGY E DICAS -->
<div class="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 pt-3 pb-1 w-full">
  <div id="heroCardBanner" class="hero-card-banner">
    <!-- Brilho radial especular -->
    <div class="hero-specular-sheen"></div>

    <div class="relative z-10 space-y-4">
      
      <!-- LINHA 1: SALDO DISPONÍVEL & SELETOR DE CICLO -->
      <div class="flex items-start justify-between gap-3">
        <div>
          <div class="flex items-center gap-2">
            <span class="text-xs font-bold text-blue-200 uppercase tracking-wider">Saldo Atual</span>
            <button id="btnHeroPrivacyToggle" type="button" onclick="toggleHeroPrivacy()" class="text-blue-300 hover:text-white transition-colors" title="Ocultar/Exibir valores">
              <i id="iconHeroPrivacy" data-lucide="eye" class="w-4 h-4"></i>
            </button>
          </div>
          <div class="flex items-baseline gap-2 mt-1 flex-wrap">
            <h2 id="heroSaldoDisponivel" class="text-2xl sm:text-3xl font-black text-white tracking-tight">
              R$ 3.270,00
            </h2>
            <span id="heroSaldoStatusBadge" class="inline-flex items-center gap-1 text-[11px] font-bold px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-400/30">
              <span>↑ 12%</span> em relação ao mês anterior
            </span>
          </div>
        </div>

        <!-- Ciclo Vigente com Dropdown Flutuante -->
        <div class="relative flex-shrink-0">
          <button id="btnHeroCycleTrigger" type="button" onclick="toggleCycleMenu()" class="flex items-center gap-2 bg-white/10 hover:bg-white/20 active:scale-95 border border-white/20 text-white px-3 py-1.5 rounded-2xl transition-all shadow-xs cursor-pointer">
            <i data-lucide="calendar" class="w-3.5 h-3.5 text-amber-300 flex-shrink-0"></i>
            <div class="flex flex-col text-left leading-none">
              <span class="text-[8px] font-black uppercase tracking-wider text-amber-200/90">Ciclo Vigente</span>
              <span id="heroCycleTag" class="text-[11px] font-extrabold text-white whitespace-nowrap">05/Out a 04/Nov 2026</span>
            </div>
            <i data-lucide="chevron-down" class="w-3 h-3 text-white/70"></i>
          </button>

          <!-- Dropdown Flutuante de Ciclos -->
          <div id="cycleDropdownMenu" class="hidden absolute right-0 mt-2 w-64 bg-white dark:bg-slate-900 rounded-2xl shadow-2xl border border-slate-200 dark:border-slate-800 py-2 z-50 text-xs text-slate-800 dark:text-slate-100">
            <div class="px-3.5 py-1 text-[10px] font-extrabold uppercase tracking-wider text-slate-400 flex items-center justify-between">
              <span>Selecionar Período</span>
              <i data-lucide="calendar" class="w-3.5 h-3.5 text-blue-500"></i>
            </div>
            <div id="cycleDropdownItems" class="space-y-0.5 mt-1 px-1"></div>
            <div class="border-t border-slate-100 dark:border-slate-800 mt-2 pt-1.5 px-2">
              <button type="button" onclick="closeCycleMenu(); openNewCycleModal();" class="w-full flex items-center gap-2 px-3 py-2 rounded-xl text-left font-bold text-blue-600 dark:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-950/40 transition-colors">
                <i data-lucide="plus-circle" class="w-4 h-4"></i>
                <span>+ Criar Novo Ciclo...</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- LINHA 2: BALÃO INTERATIVO DO PIGGY COM SETINHAS + MASCOTE -->
      <div class="flex flex-col md:flex-row items-center justify-between gap-3 pt-1">
        
        <!-- Balão de Dicas -->
        <div id="heroPiggyTipCard" class="w-full md:flex-1 hero-piggy-balloon" onmouseenter="pausePiggyTipAutoPlay()" onmouseleave="resumePiggyTipAutoPlay()">
          <div class="flex items-center justify-between mb-1.5 flex-shrink-0">
            <div class="flex items-center gap-1.5 min-w-0">
              <span id="piggyTipIconBadge" class="inline-flex items-center justify-center w-5 h-5 rounded-full bg-amber-400 text-slate-900 text-[11px] font-black shadow-xs flex-shrink-0">💡</span>
              <span id="piggyTipCategoryBadge" class="text-[11px] font-black uppercase tracking-wider text-amber-200 truncate">Dica do Piggy</span>
              <span id="piggyTipIndexBadge" class="text-[10px] font-bold px-1.5 py-0.5 rounded-full bg-white/20 text-white flex-shrink-0">1/4</span>
            </div>
            <!-- Setinhas Anterior / Próxima -->
            <div class="flex items-center gap-1 flex-shrink-0">
              <button type="button" onclick="navigatePiggyTip(-1)" class="w-6 h-6 rounded-lg bg-white/20 hover:bg-white/30 flex items-center justify-center text-white transition-all active:scale-95 cursor-pointer" title="Dica anterior">
                <i data-lucide="chevron-left" class="w-3.5 h-3.5"></i>
              </button>
              <button type="button" onclick="navigatePiggyTip(1)" class="w-6 h-6 rounded-lg bg-white/20 hover:bg-white/30 flex items-center justify-center text-white transition-all active:scale-95 cursor-pointer" title="Próxima dica">
                <i data-lucide="chevron-right" class="w-3.5 h-3.5"></i>
              </button>
            </div>
          </div>

          <!-- Conteúdo da Dica -->
          <div id="piggyTipContentArea" class="min-h-[48px] overflow-hidden flex flex-col justify-between flex-shrink-0"></div>

          <!-- Dots de Paginação -->
          <div id="piggyTipDots" class="flex items-center justify-center gap-1.5 mt-2 pt-1.5 border-t border-white/10 flex-shrink-0"></div>
        </div>

        <!-- Mascote 3D com Micro-Reação ao Toque -->
        <div class="flex-shrink-0 flex items-center justify-center self-center md:self-auto cursor-pointer" onclick="triggerMascotMicroReaction(event)" title="Toque no porquinho para interagir!">
          <img id="mascotImage" src="images/professor_pig_character_only.png" alt="Mascote Finanças" class="w-24 sm:w-28 md:w-32 h-auto object-contain select-none drop-shadow-md hover:scale-105 active:scale-95 transition-transform duration-200">
        </div>
      </div>

      <!-- LINHA 3: MINI-INDICADORES -->
      <div class="pt-3 border-t border-white/20 grid grid-cols-3 gap-2 sm:gap-4 text-center">
        <div class="bg-black/15 backdrop-blur-xs rounded-xl p-2 sm:p-2.5">
          <div class="text-[10px] sm:text-xs text-blue-100 font-medium">Dias Restantes</div>
          <div id="heroMiniDias" class="text-xs sm:text-sm lg:text-base font-extrabold text-white mt-0.5">18 dias</div>
        </div>
        <div class="bg-black/15 backdrop-blur-xs rounded-xl p-2 sm:p-2.5">
          <div class="text-[10px] sm:text-xs text-blue-100 font-medium">% Comprometido</div>
          <div id="heroMiniComprometimento" class="text-xs sm:text-sm lg:text-base font-extrabold text-white mt-0.5">61%</div>
        </div>
        <div class="bg-black/15 backdrop-blur-xs rounded-xl p-2 sm:p-2.5 cursor-pointer hover:bg-black/25 transition-all" onclick="navigateToAccordionSection('cardHeroInstallments', 'cardHeroInstallmentsContent')" title="Ver compras parceladas">
          <div class="text-[10px] sm:text-xs text-blue-100 font-medium">Parcelados</div>
          <div id="heroMiniFixas" class="text-xs sm:text-sm lg:text-base font-extrabold text-white mt-0.5">5 ativas</div>
        </div>
      </div>

    </div>
  </div>
</div>
```

---

## 3. Cartões de Métricas Principais (Receitas e Despesas)

Visual fintech com números de alta escala e identificação imediata.

```html
<!-- CARTÕES DE MÉTRICAS RECEITAS & DESPESAS -->
<div id="sectionMetrics" class="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 py-2 w-full">
  <div class="grid grid-cols-2 gap-3">
    
    <!-- Card Receitas -->
    <div id="receitas" class="card-fintech p-4 flex flex-col justify-between">
      <div class="flex items-center justify-between">
        <span class="text-xs font-bold text-slate-500 dark:text-slate-400">Receitas</span>
        <div class="w-8 h-8 rounded-xl bg-emerald-50 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400 flex items-center justify-center font-bold text-sm">
          ↓
        </div>
      </div>
      <div class="mt-2">
        <div id="metricReceitasVal" class="text-xl sm:text-2xl font-black text-emerald-600 dark:text-emerald-400">
          R$ 8.500,00
        </div>
        <span class="inline-flex items-center gap-1 text-[10px] font-bold text-emerald-600 dark:text-emerald-400 mt-1">
          <span>↑ 12%</span> no mês
        </span>
      </div>
    </div>

    <!-- Card Despesas Totais -->
    <div id="fixas" class="card-fintech p-4 flex flex-col justify-between">
      <div class="flex items-center justify-between">
        <span class="text-xs font-bold text-slate-500 dark:text-slate-400">Despesas</span>
        <div class="w-8 h-8 rounded-xl bg-rose-50 dark:bg-rose-950/60 text-rose-600 dark:text-rose-400 flex items-center justify-center font-bold text-sm">
          ↑
        </div>
      </div>
      <div class="mt-2">
        <div id="metricDespesasVal" class="text-xl sm:text-2xl font-black text-rose-600 dark:text-rose-400">
          R$ 5.230,00
        </div>
        <span class="inline-flex items-center gap-1 text-[10px] font-bold text-rose-600 dark:text-rose-400 mt-1">
          <span>↑ 3%</span> no mês
        </span>
      </div>
    </div>

  </div>
</div>
```

---

## 4. Gráfico Donut de Despesas por Categoria

```html
<!-- GRÁFICO DONUT DE DESPESAS POR CATEGORIA -->
<div id="sectionCharts" class="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 py-2 w-full">
  <div class="card-fintech p-5">
    <div class="flex items-center justify-between mb-4">
      <h3 class="font-black text-base text-slate-900 dark:text-white">Despesas por categoria</h3>
      <button type="button" onclick="document.getElementById('sectionTable').scrollIntoView({behavior: 'smooth'})" class="text-xs font-bold text-blue-600 dark:text-blue-400 hover:underline">
        Ver tudo &gt;
      </button>
    </div>

    <div class="flex flex-col sm:flex-row items-center justify-around gap-6">
      <!-- Donut Chart Canvas com Valor Centralizado -->
      <div class="relative w-44 h-44 flex items-center justify-center flex-shrink-0">
        <canvas id="categoryPieChart" width="176" height="176"></canvas>
        <div class="absolute inset-0 flex flex-col items-center justify-center pointer-events-none text-center">
          <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Total</span>
          <span class="text-lg font-black text-slate-900 dark:text-white leading-tight">R$ 5.230</span>
          <span class="text-[9px] text-slate-400">no mês</span>
        </div>
      </div>

      <!-- Legenda de Fatias -->
      <div class="grid grid-cols-2 sm:grid-cols-1 gap-2.5 w-full max-w-xs text-xs">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <span class="w-3 h-3 rounded-full bg-blue-600"></span>
            <span class="text-slate-700 dark:text-slate-300 font-medium">Moradia</span>
          </div>
          <span class="font-bold text-slate-900 dark:text-white">42%</span>
        </div>
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <span class="w-3 h-3 rounded-full bg-amber-500"></span>
            <span class="text-slate-700 dark:text-slate-300 font-medium">Alimentação</span>
          </div>
          <span class="font-bold text-slate-900 dark:text-white">28%</span>
        </div>
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <span class="w-3 h-3 rounded-full bg-sky-500"></span>
            <span class="text-slate-700 dark:text-slate-300 font-medium">Educação</span>
          </div>
          <span class="font-bold text-slate-900 dark:text-white">18%</span>
        </div>
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <span class="w-3 h-3 rounded-full bg-purple-500"></span>
            <span class="text-slate-700 dark:text-slate-300 font-medium">Saúde</span>
          </div>
          <span class="font-bold text-slate-900 dark:text-white">7%</span>
        </div>
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <span class="w-3 h-3 rounded-full bg-slate-400"></span>
            <span class="text-slate-700 dark:text-slate-300 font-medium">Outros</span>
          </div>
          <span class="font-bold text-slate-900 dark:text-white">5%</span>
        </div>
      </div>
    </div>
  </div>
</div>
```

---

## 5. Visualização de Transações (Tela 2)

```html
<!-- SEÇÃO DE TRANSAÇÕES (LISTA AGRUPADA FINTECH) -->
<div id="sectionTable" class="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 py-3 w-full">
  
  <!-- Barra de Filtros e Busca -->
  <div class="flex items-center justify-between gap-2 mb-3">
    <h2 class="text-lg font-black text-slate-900 dark:text-white">Transações</h2>
    <div class="relative w-48">
      <input id="filterInputTable" type="text" placeholder="Buscar..." class="w-full text-xs rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 py-1.5 pl-8 pr-3 text-slate-900 dark:text-white focus:outline-none focus:border-blue-500" />
      <i data-lucide="search" class="w-3.5 h-3.5 text-slate-400 absolute left-2.5 top-2.5"></i>
    </div>
  </div>

  <!-- Pílulas de Filtro Rápido -->
  <div class="flex items-center gap-1.5 overflow-x-auto pb-2 custom-scrollbar">
    <button class="chip-pill active">Todas</button>
    <button class="chip-pill">Entradas</button>
    <button class="chip-pill">Saídas</button>
    <button class="chip-pill">Parceladas</button>
  </div>

  <!-- Botões de Ação Rápida -->
  <div class="grid grid-cols-3 gap-2 my-3">
    <button type="button" onclick="openNewTxModal()" class="py-2.5 px-3 rounded-2xl bg-blue-700 hover:bg-blue-800 active:scale-95 text-white font-black text-xs flex items-center justify-center gap-1.5 shadow-md transition-all cursor-pointer">
      <i data-lucide="plus" class="w-4 h-4"></i>
      <span>+ Nova Transação</span>
    </button>
    <button type="button" onclick="openInvoiceScanModal()" class="py-2.5 px-3 rounded-2xl bg-white dark:bg-slate-900 hover:bg-slate-50 border border-slate-200 dark:border-slate-800 text-slate-800 dark:text-slate-100 font-bold text-xs flex items-center justify-center gap-1.5 shadow-sm transition-all cursor-pointer">
      <i data-lucide="camera" class="w-4 h-4 text-blue-600"></i>
      <span>Escanear NFe</span>
    </button>
    <button type="button" onclick="document.getElementById('establishmentPillFilters').scrollIntoView({behavior: 'smooth'})" class="py-2.5 px-3 rounded-2xl bg-white dark:bg-slate-900 hover:bg-slate-50 border border-slate-200 dark:border-slate-800 text-slate-800 dark:text-slate-100 font-bold text-xs flex items-center justify-center gap-1.5 shadow-sm transition-all cursor-pointer">
      <i data-lucide="tag" class="w-4 h-4 text-purple-600"></i>
      <span>Categorias</span>
    </button>
  </div>

  <!-- Grupo: Hoje · 20 de outubro -->
  <div class="mt-4">
    <span class="text-xs font-bold text-slate-400 uppercase tracking-wider block mb-2">Hoje · 20 de outubro</span>
    
    <!-- Item 1: Supermercado Extra -->
    <div class="list-item-fintech" onclick="openEditTxModal(1)">
      <div class="flex items-center gap-3">
        <div class="list-item-icon-box bg-blue-50 text-blue-600 dark:bg-blue-950/60 dark:text-blue-400">
          🛒
        </div>
        <div>
          <h4 class="font-extrabold text-sm text-slate-900 dark:text-white leading-tight">Supermercado Extra</h4>
          <span class="text-[11px] text-slate-500 dark:text-slate-400 font-medium">Alimentação • Rodrigo</span>
        </div>
      </div>
      <div class="text-right">
        <span class="font-black text-sm text-rose-600 dark:text-rose-400 block">- R$ 156,80</span>
        <span class="text-[10px] text-slate-400">14:32</span>
      </div>
    </div>

    <!-- Item 2: Salário -->
    <div class="list-item-fintech" onclick="openEditTxModal(2)">
      <div class="flex items-center gap-3">
        <div class="list-item-icon-box bg-emerald-50 text-emerald-600 dark:bg-emerald-950/60 dark:text-emerald-400">
          💼
        </div>
        <div>
          <h4 class="font-extrabold text-sm text-slate-900 dark:text-white leading-tight">Salário</h4>
          <span class="text-[11px] text-slate-500 dark:text-slate-400 font-medium">Receita Familiar</span>
        </div>
      </div>
      <div class="text-right">
        <span class="font-black text-sm text-emerald-600 dark:text-emerald-400 block">+ R$ 5.200,00</span>
        <span class="text-[10px] text-slate-400">08:00</span>
      </div>
    </div>
  </div>

</div>
```

---

## 6. Módulo Família & Vida (Tela 3)

Central organizada em grade de 2 colunas com os 8 módulos familiares reais.

```html
<!-- CENTRAL FAMÍLIA & VIDA -->
<div id="fintechQuickHub" class="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 py-3 w-full">
  
  <!-- Banner Apresentação -->
  <div class="hero-card-banner p-4 sm:p-5 flex items-center justify-between gap-4">
    <div>
      <h3 class="font-black text-base sm:text-lg text-white">Tudo da sua família em um só lugar.</h3>
      <p class="text-xs text-blue-200 mt-0.5">Organize, planeje e viva com mais tranquilidade.</p>
    </div>
    <img src="images/professor_pig_character_only.png" alt="Piggy" class="w-16 h-16 object-contain flex-shrink-0 drop-shadow-md">
  </div>

  <!-- Grade de 8 Módulos Reais -->
  <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-4">
    
    <!-- 1. Lista de Compras -->
    <div class="module-tile" onclick="openMascotPitaco('compras', openShoppingListModal)">
      <div class="module-icon-halo bg-blue-50 text-blue-600 dark:bg-blue-950/60 dark:text-blue-400">
        🛒
      </div>
      <div class="min-w-0">
        <h4 class="font-extrabold text-xs text-slate-900 dark:text-white truncate">Lista de Compras</h4>
        <span class="text-[10px] text-slate-400 truncate block">Colaborativa</span>
      </div>
    </div>

    <!-- 2. Minha Saúde -->
    <div class="module-tile" onclick="openMascotPitaco('saude', openHealthMedsModal)">
      <div class="module-icon-halo bg-emerald-50 text-emerald-600 dark:bg-emerald-950/60 dark:text-emerald-400">
        🩺
      </div>
      <div class="min-w-0">
        <h4 class="font-extrabold text-xs text-slate-900 dark:text-white truncate">Minha Saúde</h4>
        <span class="text-[10px] text-slate-400 truncate block">Remédios e exames</span>
      </div>
    </div>

    <!-- 3. Pets e Vacinas -->
    <div class="module-tile" onclick="openMascotPitaco('pet', openPetAreaModal)">
      <div class="module-icon-halo bg-amber-50 text-amber-600 dark:bg-amber-950/60 dark:text-amber-400">
        🐾
      </div>
      <div class="min-w-0">
        <h4 class="font-extrabold text-xs text-slate-900 dark:text-white truncate">Pets e Vacinas</h4>
        <span class="text-[10px] text-slate-400 truncate block">Cuidados e gastos</span>
      </div>
    </div>

    <!-- 4. Veículos & Garagem -->
    <div class="module-tile" onclick="openMascotPitaco('veiculos', openVeiculosHub)">
      <div class="module-icon-halo bg-indigo-50 text-indigo-600 dark:bg-indigo-950/60 dark:text-indigo-400">
        🚗
      </div>
      <div class="min-w-0">
        <h4 class="font-extrabold text-xs text-slate-900 dark:text-white truncate">Veículos</h4>
        <span class="text-[10px] text-slate-400 truncate block">Manutenção e IPVA</span>
      </div>
    </div>

    <!-- 5. Prestadores de Serviço -->
    <div class="module-tile" onclick="openMascotPitaco('prestadores', openServiceProvidersModal)">
      <div class="module-icon-halo bg-teal-50 text-teal-600 dark:bg-teal-950/60 dark:text-teal-400">
        🔧
      </div>
      <div class="min-w-0">
        <h4 class="font-extrabold text-xs text-slate-900 dark:text-white truncate">Prestadores</h4>
        <span class="text-[10px] text-slate-400 truncate block">Contatos e diárias</span>
      </div>
    </div>

    <!-- 6. Cofrinho e Metas -->
    <div class="module-tile" onclick="openMascotPitaco('cofrinhos', openCreatePiggyModal)">
      <div class="module-icon-halo bg-pink-50 text-pink-600 dark:bg-pink-950/60 dark:text-pink-400">
        🐷
      </div>
      <div class="min-w-0">
        <h4 class="font-extrabold text-xs text-slate-900 dark:text-white truncate">Cofrinhos</h4>
        <span class="text-[10px] text-slate-400 truncate block">Objetivos da família</span>
      </div>
    </div>

    <!-- 7. Educação -->
    <div class="module-tile" onclick="openMascotPitaco('educacao', openEducacaoHub)">
      <div class="module-icon-halo bg-purple-50 text-purple-600 dark:bg-purple-950/60 dark:text-purple-400">
        🎓
      </div>
      <div class="min-w-0">
        <h4 class="font-extrabold text-xs text-slate-900 dark:text-white truncate">Educação</h4>
        <span class="text-[10px] text-slate-400 truncate block">Mensalidades e cursos</span>
      </div>
    </div>

    <!-- 8. Cartões & Faturas (Substitui 'Documentos' por utilidade bancária real) -->
    <div class="module-tile" onclick="openMascotPitaco('cartoes', openManageCardsModal)">
      <div class="module-icon-halo bg-sky-50 text-sky-600 dark:bg-sky-950/60 dark:text-sky-400">
        💳
      </div>
      <div class="min-w-0">
        <h4 class="font-extrabold text-xs text-slate-900 dark:text-white truncate">Cartões &amp; Faturas</h4>
        <span class="text-[10px] text-slate-400 truncate block">Limites e vencimentos</span>
      </div>
    </div>

  </div>
</div>
```

---

## 7. Chat da Família em Tela Inteira (Tela 4)

Substitui a caixa flutuante pela experiência de tela cheia com barra superior nativa e filtro de membros.

```html
<!-- CHAT DA FAMÍLIA EM TELA INTEIRA -->
<div id="modalFamilyChat" class="full-screen-page hidden">
  
  <!-- Barra de Topo com Voltar -->
  <div class="page-header-back">
    <div class="flex items-center gap-3">
      <button type="button" onclick="closeFamilyChatModal()" class="btn-back-circle" title="Voltar ao app">
        <i data-lucide="arrow-left" class="w-4 h-4"></i>
      </button>
      <div>
        <h3 class="font-black text-base text-white leading-tight">Chat da Família</h3>
        <p class="text-[10px] text-blue-200">Rodrigo &amp; Márcia • online</p>
      </div>
    </div>
    <button type="button" class="btn-back-circle" title="Opções">
      <i data-lucide="more-vertical" class="w-4 h-4"></i>
    </button>
  </div>

  <!-- Barra Horizontal de Membros -->
  <div class="bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 px-3 py-2 flex items-center gap-2 overflow-x-auto flex-shrink-0">
    <button class="chip-pill active">Todos</button>
    <button class="chip-pill">👨 Rodrigo</button>
    <button class="chip-pill">👩 Márcia</button>
  </div>

  <!-- Área de Mensagens Rolável -->
  <div class="flex-1 p-3 space-y-3 overflow-y-auto">
    <!-- Divisor de Data -->
    <div class="text-center">
      <span class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-slate-200 dark:bg-slate-800 text-slate-500">Hoje</span>
    </div>

    <!-- Mensagem de Texto -->
    <div class="flex items-end gap-2 max-w-[85%]">
      <div class="w-7 h-7 rounded-full bg-blue-100 flex items-center justify-center text-xs flex-shrink-0">👨</div>
      <div class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 p-3 rounded-2xl rounded-bl-none shadow-xs text-xs">
        <span class="font-bold text-[10px] text-blue-600 block mb-0.5">Rodrigo</span>
        <p class="text-slate-800 dark:text-slate-100">Pessoal, já paguei a conta de energia deste mês. ✅</p>
        <span class="text-[9px] text-slate-400 block text-right mt-1">10:24</span>
      </div>
    </div>

    <!-- Card Rico de Conta Compartilhada -->
    <div class="flex items-end gap-2 max-w-[85%]">
      <div class="w-7 h-7 rounded-full bg-blue-100 flex items-center justify-center text-xs flex-shrink-0">⚡</div>
      <div class="bg-amber-50 dark:bg-slate-800 border border-amber-200 dark:border-slate-700 p-3 rounded-2xl shadow-xs text-xs w-64">
        <div class="flex items-center justify-between mb-1">
          <span class="font-black text-xs text-slate-900 dark:text-white">Energia Elétrica</span>
          <span class="text-[9px] font-extrabold px-1.5 py-0.5 rounded-full bg-emerald-500 text-white">Pago</span>
        </div>
        <div class="text-base font-black text-slate-900 dark:text-white">R$ 245,00</div>
        <span class="text-[10px] text-slate-500 block mb-2">Venceu em 24 out 2026</span>
        <button type="button" class="w-full py-1 bg-white dark:bg-slate-700 text-blue-600 dark:text-blue-400 font-bold rounded-lg text-[11px] border border-slate-200 dark:border-slate-600">
          Ver detalhes &gt;
        </button>
      </div>
    </div>
  </div>

  <!-- Barra de Digitação Inferior -->
  <div class="bg-white dark:bg-slate-900 border-t border-slate-200 dark:border-slate-800 p-2 flex items-center gap-2 flex-shrink-0">
    <button type="button" class="w-9 h-9 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center text-slate-600 dark:text-slate-300">
      <i data-lucide="plus" class="w-4 h-4"></i>
    </button>
    <input type="text" placeholder="Mensagem..." class="flex-1 bg-slate-100 dark:bg-slate-800 rounded-2xl px-3.5 py-2 text-xs text-slate-900 dark:text-white focus:outline-none" />
    <button type="button" onclick="openVoiceRecordModal()" class="w-9 h-9 rounded-full bg-blue-600 text-white flex items-center justify-center shadow-sm">
      <i data-lucide="mic" class="w-4 h-4"></i>
    </button>
  </div>

</div>
```

---

## 8. Navegação Inferior com 4 Abas Fintech

```html
<!-- DOCK INFERIOR (4 ABAS FINTECH) -->
<nav class="bottom-nav">
  <div class="bottom-nav-grid">
    
    <!-- 1. Início -->
    <button onclick="window.scrollTo({top: 0, behavior: 'smooth'})" class="bottom-nav-item active">
      <i data-lucide="home" class="w-5 h-5 mb-0.5"></i>
      <span>Início</span>
    </button>

    <!-- 2. Transações -->
    <button onclick="document.getElementById('sectionTable').scrollIntoView({behavior: 'smooth'})" class="bottom-nav-item">
      <i data-lucide="receipt" class="w-5 h-5 mb-0.5"></i>
      <span>Transações</span>
    </button>

    <!-- 3. Família & Vida -->
    <button onclick="document.getElementById('fintechQuickHub').scrollIntoView({behavior: 'smooth'})" class="bottom-nav-item">
      <i data-lucide="sparkles" class="w-5 h-5 mb-0.5"></i>
      <span>Família &amp; Vida</span>
    </button>

    <!-- 4. Chat da Família -->
    <button onclick="openFamilyChatModal()" class="bottom-nav-item relative">
      <i data-lucide="message-circle" class="w-5 h-5 mb-0.5"></i>
      <span>Chat</span>
      <span class="absolute top-1 right-5 w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
    </button>

  </div>
</nav>
```

---

## 9. Overlay do Mascote Oficial com Fundo Desfocado (`#modalMascotSectionPitaco`)

```html
<!-- OVERLAY DE PITACO INTELIGENTE DO MASCOTE -->
<div id="modalMascotSectionPitaco" class="mascot-overlay-backdrop hidden">
  <div class="relative z-10 max-w-sm w-full flex flex-col items-center select-none">
    
    <!-- Balão com Borda Neon e Dica -->
    <div class="mascot-speech-bubble">
      <div id="mascotPitacoBadge" class="inline-block px-2.5 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider mb-2 border bg-emerald-500/20 text-emerald-300 border-emerald-400/40">
        🩺 Dica do Piggy Médico
      </div>
      <h3 id="mascotPitacoHeader" class="font-extrabold text-base text-white mb-2">
        Minha Saúde &amp; Remédios
      </h3>
      <div id="mascotPitacoText" class="text-xs text-slate-200 leading-relaxed font-medium mb-3.5 bg-slate-950/60 p-3 rounded-2xl border border-slate-800 text-left">
        Aqui você cadastra medicamentos contínuos e ativa alarmes para não esquecer os horários, além de controlar despesas com farmácia e consultas.
      </div>

      <!-- Botão de Ação Direta -->
      <button id="btnEnterSectionFromPitaco" type="button" onclick="confirmEnterSectionFromPitaco()" class="w-full py-2.5 px-4 rounded-xl bg-gradient-to-r from-sky-500 to-indigo-600 hover:from-sky-400 hover:to-indigo-500 text-white font-extrabold text-xs shadow-lg shadow-sky-500/30 transition-all flex items-center justify-center gap-2 cursor-pointer">
        <span id="btnEnterSectionLabel">Acessar Seção Agora</span>
        <span>→</span>
      </button>

      <label class="flex items-center justify-center gap-2 mt-3 cursor-pointer text-[11px] text-slate-400 hover:text-slate-200">
        <input type="checkbox" id="checkSkipPitacoThisMonth" class="rounded border-slate-700 bg-slate-800 text-sky-500 focus:ring-0 cursor-pointer" />
        <span>Não exibir este alerta novamente este mês</span>
      </label>
    </div>

    <!-- Mascote Oficial Caracterizado -->
    <div class="relative mt-1">
      <img id="mascotPitacoImg" src="images/mascote_oficial_saude.png" alt="Mascote Oficial" class="mascot-official-img" />
    </div>

  </div>
</div>
```
