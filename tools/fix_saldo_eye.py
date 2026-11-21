import re

path = r'C:\Users\rodri\.gemini\antigravity\scratch\financas_casal_flutter\assets\index.html'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update HTML button for larger touch target and clean click handling
old_btn = '''                <button type="button" onclick="togglePrivacy()" id="btnHeroPrivacyToggle" class="w-7 h-7 flex items-center justify-center text-slate-600 hover:text-slate-900 bg-transparent transition-all cursor-pointer relative z-40" title="Ocultar ou mostrar saldo e valores">
                  <i data-lucide="eye-off" id="iconHeroPrivacy" class="w-4 h-4 text-slate-600" style="color: #475569 !important;"></i>
                </button>'''

new_btn = '''                <button type="button" onclick="togglePrivacy()" id="btnHeroPrivacyToggle" class="w-9 h-9 -mr-1 flex items-center justify-center rounded-full hover:bg-slate-100/80 active:scale-95 text-slate-600 hover:text-slate-900 transition-all cursor-pointer relative z-40" title="Ocultar ou mostrar saldo e valores">
                  <i data-lucide="eye-off" id="iconHeroPrivacy" class="w-4 h-4 text-slate-600" style="color: #475569 !important;"></i>
                </button>'''

assert old_btn in content, "old_btn not found!"
content = content.replace(old_btn, new_btn, 1)
print("1. Updated btnHeroPrivacyToggle HTML touch target")

# 2. Update updateDashboard eye icon handling around line 11431
old_dash_eye = '''      const heroEyeIcon = document.getElementById('iconHeroPrivacy');
      if (heroEyeIcon) {
        heroEyeIcon.setAttribute('data-lucide', isHeroBalanceHidden ? 'eye-off' : 'eye');
      }'''

new_dash_eye = '''      const btnHeroDash = document.getElementById('btnHeroPrivacyToggle');
      if (btnHeroDash) {
        btnHeroDash.innerHTML = `<i data-lucide="${isHeroBalanceHidden ? 'eye-off' : 'eye'}" id="iconHeroPrivacy" class="w-4 h-4 text-slate-600" style="color: #475569 !important;"></i>`;
        btnHeroDash.title = isHeroBalanceHidden ? 'Mostrar Saldo e Valores do Card' : 'Ocultar Saldo e Valores do Card';
      }'''

assert old_dash_eye in content, "old_dash_eye not found!"
content = content.replace(old_dash_eye, new_dash_eye, 1)
print("2. Updated updateDashboard eye icon renderer")

# 3. Update window.syncHeroCardEyeAndBalance and window.toggleHeroCardPrivacy around lines 33636-33682
old_sync_block = '''  window.syncHeroCardEyeAndBalance = function() {
    const valEl = document.getElementById('heroSaldoDisponivelVal');
    const btnEl = document.getElementById('btnHeroPrivacyToggle');
    const badgeEl = document.getElementById('heroSaldoStatusBadge');

    const hidden = localStorage.getItem('ctrlpig_hero_balance_hidden') === 'true';
    isHeroBalanceHidden = hidden;

    if (valEl) {
      const currentTxt = (valEl.textContent || '').trim();
      if (currentTxt && currentTxt !== 'R$ •••••') {
        valEl.dataset.realValue = currentTxt;
      }
      if (hidden) {
        valEl.textContent = 'R$ •••••';
      } else if (valEl.dataset.realValue) {
        valEl.textContent = valEl.dataset.realValue;
      }
    }

    if (btnEl) {
      const iconName = hidden ? 'eye-off' : 'eye';
      btnEl.title = hidden ? 'Mostrar Saldo Livre Disponível' : 'Ocultar Saldo Livre Disponível';
      btnEl.innerHTML = `<i data-lucide="${iconName}" id="iconHeroPrivacy" class="w-4 h-4 text-slate-700" style="color: #334155 !important;"></i>`;
      if (window.lucide) lucide.createIcons();
    }

    // Garante que o badge Saldo Positivo / Negativo nunca quebre de linha
    if (badgeEl) {
      badgeEl.classList.add('whitespace-nowrap', 'flex-shrink-0');
    }
  };

  window.applyHeroBalancePrivacyState = window.syncHeroCardEyeAndBalance;

  window.toggleHeroCardPrivacy = function() {
    const currentHidden = localStorage.getItem('ctrlpig_hero_balance_hidden') === 'true';
    const nextHidden = !currentHidden;
    isHeroBalanceHidden = nextHidden;
    localStorage.setItem('ctrlpig_hero_balance_hidden', nextHidden ? 'true' : 'false');

    if (!nextHidden && typeof updateDashboard === 'function') {
      updateDashboard();
    }
    window.syncHeroCardEyeAndBalance();
  };'''

new_sync_block = '''  window.syncHeroCardEyeAndBalance = function() {
    const hidden = localStorage.getItem('ctrlpig_hero_balance_hidden') === 'true';
    isHeroBalanceHidden = hidden;

    const btnEl = document.getElementById('btnHeroPrivacyToggle');
    if (btnEl) {
      const iconName = hidden ? 'eye-off' : 'eye';
      btnEl.title = hidden ? 'Mostrar Saldo e Valores do Card' : 'Ocultar Saldo e Valores do Card';
      btnEl.innerHTML = `<i data-lucide="${iconName}" id="iconHeroPrivacy" class="w-4 h-4 text-slate-600" style="color: #475569 !important;"></i>`;
      if (window.lucide) lucide.createIcons();
    }

    const valEl = document.getElementById('heroSaldoDisponivelVal');
    if (valEl) {
      const currentTxt = (valEl.textContent || '').trim();
      if (currentTxt && currentTxt !== 'R$ •••••') {
        valEl.dataset.realValue = currentTxt;
      }
      if (hidden) {
        valEl.textContent = 'R$ •••••';
      } else if (valEl.dataset.realValue) {
        valEl.textContent = valEl.dataset.realValue;
      }
    }

    const sEl = document.getElementById('heroSaldoText');
    if (sEl) {
      const currentTxt = (sEl.textContent || '').trim();
      if (currentTxt && currentTxt !== 'R$ •••••') {
        sEl.dataset.real = currentTxt;
      }
      if (hidden) {
        sEl.textContent = 'R$ •••••';
      } else if (sEl.dataset.real && !sEl.dataset.real.includes('•')) {
        sEl.textContent = sEl.dataset.real;
      }
    }
  };

  window.applyHeroBalancePrivacyState = window.syncHeroCardEyeAndBalance;
  window.toggleHeroCardPrivacy = function() {
    if (typeof window.togglePrivacy === 'function') {
      window.togglePrivacy();
    }
  };'''

assert old_sync_block in content, "old_sync_block not found!"
content = content.replace(old_sync_block, new_sync_block, 1)
print("3. Updated syncHeroCardEyeAndBalance and toggleHeroCardPrivacy")

# 4. Update window.togglePrivacy around lines 43073-43204
old_toggle_privacy = '''  // 3. Olhinho: Alternância de Ícones Eye / Eye-Off e Ocultação EXCLUSIVA do Card Saldo Atual
  window.togglePrivacy = function() {
    const currentHidden = localStorage.getItem('ctrlpig_hero_balance_hidden') === 'true';
    const isHidden = !currentHidden;
    localStorage.setItem('ctrlpig_hero_balance_hidden', isHidden ? 'true' : 'false');
    window.privacyHidden = false; // Garante que NUNCA esconde os demais cards ou métricas fora do card Saldo Atual
    if (typeof isPrivacyGlobal !== 'undefined') isPrivacyGlobal = false;
    if (typeof isTablePrivacy !== 'undefined') isTablePrivacy = false;

    // Atualiza os ícones de olhinho do card de Saldo Atual
    const eyeIcons = document.querySelectorAll('#iconHeroPrivacy, [data-hero-privacy-icon], #iconHeroPrivacy2');
    eyeIcons.forEach(eyeIcon => {
      eyeIcon.setAttribute('data-lucide', isHidden ? 'eye-off' : 'eye');
      eyeIcon.className = 'w-4 h-4 text-slate-600';
      eyeIcon.style.color = '#475569';
    });

    // Oculta ou exibe EXCLUSIVAMENTE o que está no card de Saldo Atual
    const saldoText = document.getElementById('heroSaldoText');
    if (saldoText) {
      if (isHidden) {
        if (!saldoText.dataset.real || saldoText.dataset.real.includes('•')) {
          if (saldoText.textContent && !saldoText.textContent.includes('•')) {
            saldoText.dataset.real = saldoText.textContent;
          }
        }
        saldoText.textContent = 'R$ •••••';
      } else {
        saldoText.textContent = saldoText.dataset.real || 'R$ 0,00';
      }
    }

    const recVal = document.getElementById('heroReceitasVal');
    if (recVal) {
      if (isHidden) {
        if (!recVal.dataset.real || recVal.dataset.real.includes('•')) {
          if (recVal.textContent && !recVal.textContent.includes('•')) {
            recVal.dataset.real = recVal.textContent;
          }
        }
        recVal.textContent = '+ R$ •••••';
      } else {
        recVal.textContent = recVal.dataset.real || '+ R$ 0,00';
      }
    }

    const despVal = document.getElementById('heroDespesasVal');
    if (despVal) {
      if (isHidden) {
        if (!despVal.dataset.real || despVal.dataset.real.includes('•')) {
          if (despVal.textContent && !despVal.textContent.includes('•')) {
            despVal.dataset.real = despVal.textContent;
          }
        }
        despVal.textContent = '- R$ •••••';
      } else {
        despVal.textContent = despVal.dataset.real || '- R$ 0,00';
      }
    }

    const valEl = document.getElementById('heroSaldoDisponivelVal');
    if (valEl) {
      if (isHidden) {
        if (!valEl.dataset.realValue || valEl.dataset.realValue.includes('•')) {
          if (valEl.textContent && !valEl.textContent.includes('•')) {
            valEl.dataset.realValue = valEl.textContent;
          }
        }
        valEl.textContent = 'R$ •••••';
      } else if (valEl.dataset.realValue) {
        valEl.textContent = valEl.dataset.realValue;
      }
    }

    // Mini métricas dentro do card de Saldo Atual
    const diasEl = document.getElementById('valDiasRestantes');
    if (diasEl) {
      if (isHidden) {
        if (!diasEl.dataset.real && !diasEl.textContent.includes('•')) diasEl.dataset.real = diasEl.textContent;
        diasEl.textContent = '•• dias';
      } else {
        diasEl.textContent = diasEl.dataset.real || '9 dias';
      }
    }

    const compEl = document.getElementById('valComprometido');
    if (compEl) {
      if (isHidden) {
        if (!compEl.dataset.real && !compEl.textContent.includes('•')) compEl.dataset.real = compEl.textContent;
        compEl.textContent = '••%';
      } else {
        compEl.textContent = compEl.dataset.real || '78%';
      }
    }

    const parcEl = document.getElementById('valParcelados');
    if (parcEl) {
      if (isHidden) {
        if (!parcEl.dataset.real && !parcEl.textContent.includes('•')) parcEl.dataset.real = parcEl.textContent;
        parcEl.textContent = '• ativas';
      } else {
        parcEl.textContent = parcEl.dataset.real || '0 ativas';
      }
    }

    const badgeEl = document.getElementById('heroSaldoBadge');
    if (badgeEl) {
      if (isHidden) {
        if (!badgeEl.dataset.real && !badgeEl.textContent.includes('•••••')) badgeEl.dataset.real = badgeEl.innerHTML;
        badgeEl.style.display = 'none';
      } else {
        badgeEl.style.display = '';
        if (badgeEl.dataset.real) badgeEl.innerHTML = badgeEl.dataset.real;
      }
    }

    const btnHero = document.getElementById('btnHeroPrivacyToggle');
    if (btnHero) {
      btnHero.title = isHidden ? 'Mostrar Saldo e Valores do Card' : 'Ocultar Saldo e Valores do Card';
    }

    // Se reexibir, ressincroniza dados do ciclo no card
    if (!isHidden) {
      if (typeof window.syncApprovedDesignWithAppData === 'function') {
        window.syncApprovedDesignWithAppData();
      } else if (typeof updateDashboard === 'function') {
        updateDashboard();
      }
    }

    if (window.lucide && typeof lucide.createIcons === 'function') lucide.createIcons();
  };'''

new_toggle_privacy = '''  // 3. Olhinho: Alternância de Ícones Eye / Eye-Off e Ocultação EXCLUSIVA do Card Saldo Atual
  window.togglePrivacy = function() {
    const currentHidden = localStorage.getItem('ctrlpig_hero_balance_hidden') === 'true';
    const isHidden = !currentHidden;
    localStorage.setItem('ctrlpig_hero_balance_hidden', isHidden ? 'true' : 'false');
    window.privacyHidden = false; // Garante que NUNCA esconde os demais cards ou métricas fora do card Saldo Atual
    if (typeof isHeroBalanceHidden !== 'undefined') isHeroBalanceHidden = isHidden;
    if (typeof isPrivacyGlobal !== 'undefined') isPrivacyGlobal = false;
    if (typeof isTablePrivacy !== 'undefined') isTablePrivacy = false;

    // 1. Atualiza imediatamente o botão do olhinho com nova tag <i> para Lucide recriar o SVG perfeitamente
    const btnHero = document.getElementById('btnHeroPrivacyToggle');
    if (btnHero) {
      btnHero.innerHTML = `<i data-lucide="${isHidden ? 'eye-off' : 'eye'}" id="iconHeroPrivacy" class="w-4 h-4 text-slate-600" style="color: #475569 !important;"></i>`;
      btnHero.title = isHidden ? 'Mostrar Saldo e Valores do Card' : 'Ocultar Saldo e Valores do Card';
    }

    const otherEyeIcons = document.querySelectorAll('[data-hero-privacy-icon], #iconHeroPrivacy2');
    otherEyeIcons.forEach(eyeIcon => {
      eyeIcon.setAttribute('data-lucide', isHidden ? 'eye-off' : 'eye');
    });

    // 2. Chama incondicionalmente updateDashboard() para recalcular saldos, receitas, despesas e aplicar as máscaras ou valores reais
    if (typeof updateDashboard === 'function') {
      updateDashboard();
    }
    if (typeof window.syncApprovedDesignWithAppData === 'function') {
      window.syncApprovedDesignWithAppData();
    }

    // 3. Atualização direta garantida caso updateDashboard não tenha dados em memória
    const saldoText = document.getElementById('heroSaldoText');
    if (saldoText) {
      if (isHidden) {
        if (!saldoText.dataset.real || saldoText.dataset.real.includes('•')) {
          if (saldoText.textContent && !saldoText.textContent.includes('•')) {
            saldoText.dataset.real = saldoText.textContent;
          }
        }
        saldoText.textContent = 'R$ •••••';
      } else if (saldoText.dataset.real && !saldoText.dataset.real.includes('•')) {
        saldoText.textContent = saldoText.dataset.real;
      }
    }

    const recVal = document.getElementById('heroReceitasVal');
    if (recVal) {
      if (isHidden) {
        if (!recVal.dataset.real || recVal.dataset.real.includes('•')) {
          if (recVal.textContent && !recVal.textContent.includes('•')) {
            recVal.dataset.real = recVal.textContent;
          }
        }
        recVal.textContent = '+ R$ •••••';
      } else if (recVal.dataset.real && !recVal.dataset.real.includes('•')) {
        recVal.textContent = recVal.dataset.real;
      }
    }

    const despVal = document.getElementById('heroDespesasVal');
    if (despVal) {
      if (isHidden) {
        if (!despVal.dataset.real || despVal.dataset.real.includes('•')) {
          if (despVal.textContent && !despVal.textContent.includes('•')) {
            despVal.dataset.real = despVal.textContent;
          }
        }
        despVal.textContent = '- R$ •••••';
      } else if (despVal.dataset.real && !despVal.dataset.real.includes('•')) {
        despVal.textContent = despVal.dataset.real;
      }
    }

    const valEl = document.getElementById('heroSaldoDisponivelVal');
    if (valEl) {
      if (isHidden) {
        if (!valEl.dataset.realValue || valEl.dataset.realValue.includes('•')) {
          if (valEl.textContent && !valEl.textContent.includes('•')) {
            valEl.dataset.realValue = valEl.textContent;
          }
        }
        valEl.textContent = 'R$ •••••';
      } else if (valEl.dataset.realValue) {
        valEl.textContent = valEl.dataset.realValue;
      }
    }

    const diasEl = document.getElementById('valDiasRestantes');
    if (diasEl) {
      if (isHidden) {
        if (!diasEl.dataset.real && !diasEl.textContent.includes('•')) diasEl.dataset.real = diasEl.textContent;
        diasEl.textContent = '•• dias';
      } else if (diasEl.dataset.real && !diasEl.dataset.real.includes('•')) {
        diasEl.textContent = diasEl.dataset.real;
      }
    }

    const compEl = document.getElementById('valComprometido');
    if (compEl) {
      if (isHidden) {
        if (!compEl.dataset.real && !compEl.textContent.includes('•')) compEl.dataset.real = compEl.textContent;
        compEl.textContent = '••%';
      } else if (compEl.dataset.real && !compEl.dataset.real.includes('•')) {
        compEl.textContent = compEl.dataset.real;
      }
    }

    const parcEl = document.getElementById('valParcelados');
    if (parcEl) {
      if (isHidden) {
        if (!parcEl.dataset.real && !parcEl.textContent.includes('•')) parcEl.dataset.real = parcEl.textContent;
        parcEl.textContent = '• ativas';
      } else if (parcEl.dataset.real && !parcEl.dataset.real.includes('•')) {
        parcEl.textContent = parcEl.dataset.real;
      }
    }

    const badgeEl = document.getElementById('heroSaldoBadge');
    if (badgeEl) {
      if (isHidden) {
        if (!badgeEl.dataset.real && !badgeEl.textContent.includes('•••••')) badgeEl.dataset.real = badgeEl.innerHTML;
        badgeEl.style.display = 'none';
      } else {
        badgeEl.style.display = '';
        if (badgeEl.dataset.real) badgeEl.innerHTML = badgeEl.dataset.real;
      }
    }

    // 4. Lucide recria os ícones SVG
    if (window.lucide && typeof lucide.createIcons === 'function') {
      lucide.createIcons();
    }
  };'''

assert old_toggle_privacy in content, "old_toggle_privacy not found!"
content = content.replace(old_toggle_privacy, new_toggle_privacy, 1)
print("4. Updated window.togglePrivacy complete logic")

# 5. Update initialize around line 44074
old_init = '''  const initialize = () => {
    // Aplica imediatamente a persistência do olhinho salvo pelo usuário (apenas no Card Saldo Atual)
    const savedHeroPrivacy = localStorage.getItem('ctrlpig_hero_balance_hidden') === 'true';
    if (savedHeroPrivacy) {
      const elSaldo = document.getElementById('heroSaldoText');
      const elRec = document.getElementById('heroReceitasVal');
      const elDesp = document.getElementById('heroDespesasVal');
      const elDias = document.getElementById('valDiasRestantes');
      const elComp = document.getElementById('valComprometido');
      const elParc = document.getElementById('valParcelados');
      const elBadge = document.getElementById('heroSaldoBadge');
      if (elSaldo) elSaldo.textContent = 'R$ •••••';
      if (elRec) elRec.textContent = '+ R$ •••••';
      if (elDesp) elDesp.textContent = '- R$ •••••';
      if (elDias) elDias.textContent = '•• dias';
      if (elComp) elComp.textContent = '••%';
      if (elParc) elParc.textContent = '• ativas';
      if (elBadge) { elBadge.textContent = ''; elBadge.style.display = 'none'; }
      const eyeIcons = document.querySelectorAll('#iconHeroPrivacy, [data-hero-privacy-icon], #iconHeroPrivacy2');
      eyeIcons.forEach(eyeIcon => {
        eyeIcon.setAttribute('data-lucide', 'eye-off');
      });
    }'''

new_init = '''  const initialize = () => {
    // Aplica imediatamente a persistência do olhinho salvo pelo usuário (apenas no Card Saldo Atual)
    const savedHeroPrivacy = localStorage.getItem('ctrlpig_hero_balance_hidden') === 'true';
    const btnHeroInit = document.getElementById('btnHeroPrivacyToggle');
    if (btnHeroInit) {
      btnHeroInit.innerHTML = `<i data-lucide="${savedHeroPrivacy ? 'eye-off' : 'eye'}" id="iconHeroPrivacy" class="w-4 h-4 text-slate-600" style="color: #475569 !important;"></i>`;
      btnHeroInit.title = savedHeroPrivacy ? 'Mostrar Saldo e Valores do Card' : 'Ocultar Saldo e Valores do Card';
    }
    if (savedHeroPrivacy) {
      const elSaldo = document.getElementById('heroSaldoText');
      const elRec = document.getElementById('heroReceitasVal');
      const elDesp = document.getElementById('heroDespesasVal');
      const elDias = document.getElementById('valDiasRestantes');
      const elComp = document.getElementById('valComprometido');
      const elParc = document.getElementById('valParcelados');
      const elBadge = document.getElementById('heroSaldoBadge');
      if (elSaldo) elSaldo.textContent = 'R$ •••••';
      if (elRec) elRec.textContent = '+ R$ •••••';
      if (elDesp) elDesp.textContent = '- R$ •••••';
      if (elDias) elDias.textContent = '•• dias';
      if (elComp) elComp.textContent = '••%';
      if (elParc) elParc.textContent = '• ativas';
      if (elBadge) { elBadge.textContent = ''; elBadge.style.display = 'none'; }
    }'''

assert old_init in content, "old_init not found!"
content = content.replace(old_init, new_init, 1)
print("5. Updated initialize block")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("All updates applied successfully to index.html!")
