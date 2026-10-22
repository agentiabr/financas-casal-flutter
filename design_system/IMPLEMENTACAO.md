# Roteiro de Implementação — Design System ControlPig
**Destinado ao**: Agente Implementador  
**Arquivo Alvo**: `assets/index.html`  
**Folha de Estilos Base**: `design_system/ctrlpig-theme.css`  
**Tokens**: `design_system/tokens.json`

---

## 1. Regras de Ouro da Implementação

1. **Não quebre IDs nem Event Listeners**: Todas as funções (`openNewTxModal()`, `openShoppingListModal()`, `toggleHeroPrivacy()`, `navigatePiggyTip()`, etc.) e IDs (`heroSaldoDisponivel`, `headerUserName`, `categoryPieChart`) devem ser rigorosamente preservados.
2. **Sem Botões Chat/Remédio/Lançar no Card Azul**: O card azul é reservado para Saldo, Ciclo, Balão do Piggy com setinhas, Mascote 3D e Tira de mini-indicadores.
3. **Padrão de Telas Inteiras**: Ao ajustar modais (como o `#modalFamilyChat`), use `.full-screen-page` com a barra `.page-header-back` em vez de janelas flutuantes com margens transparentes.
4. **Sem Scroll Horizontal**: Mantenha containers com `max-w-full`, classes responsivas do Tailwind (`grid-cols-2 sm:grid-cols-4`, etc.) e `overflow-x: hidden`.

---

## 2. Passo a Passo Seguro de Alterações

### Passo 1: Injeção do CSS no `<head>`
No início de `assets/index.html`, logo após o carregamento do Tailwind e do script do Lucide:
```html
<!-- CONTROL PIG FINTECH DESIGN SYSTEM THEME -->
<link rel="stylesheet" href="design_system/ctrlpig-theme.css">
```
*(Ou copie e cole o conteúdo de `ctrlpig-theme.css` dentro de uma tag `<style id="ctrlpig-theme-styles">` no `<head>` caso prefira arquivo único bundle).*

---

### Passo 2: Atualização do Cabeçalho (`<header>`)
* **Localização**: Busque pela tag `<header class="sticky top-0 ...">`.
* **Substituição**:
  * Adicione a classe `app-header`.
  * Garanta que o avatar e nome do membro ativo estejam à esquerda com o seletor `onclick="openMemberModal()"`.
  * Insira os 3 botões translúcidos à direita com as classes `header-glass-btn`:
    1. Busca: `onclick="document.getElementById('sectionTable').scrollIntoView({behavior: 'smooth'})"`
    2. Notificações: `onclick="openNotificationsCenterModal()"` com `<span id="headerNotifBadge">`
    3. Perfil/Admin: `onclick="openAdminModal()"`
  * Mantenha `<select id="cycleSelector">` e `<div id="dynamicMembersContainer">` intactos.

---

### Passo 3: Ajuste do Card Herói Azul (`#heroCardBanner`)
* **Localização**: Busque por `id="heroCardBanner"`.
* **Classes**: Aplique a classe `hero-card-banner`.
* **Verificação de Itens**:
  * Saldo com privacidade: `#heroSaldoDisponivel`, `#btnHeroPrivacyToggle`, `#iconHeroPrivacy`.
  * Ciclo com dropdown: `#btnHeroCycleTrigger`, `#heroCycleTag`, `#cycleDropdownMenu`, `#cycleDropdownItems`.
  * Balão interativo do Piggy: `#heroPiggyTipCard` com botões `navigatePiggyTip(-1)` e `navigatePiggyTip(1)`, `#piggyTipContentArea`, `#piggyTipDots`.
  * Mascote: `#mascotImage` com `triggerMascotMicroReaction(event)`.
  * Mini-indicadores: `#heroMiniDias`, `#heroMiniComprometimento`, `#heroMiniFixas`.
  * **Atenção**: Certifique-se de que nenhum botão de atalho (Chat, Remédio, Lançar) esteja inserido dentro do banner azul.

---

### Passo 4: Atualização dos Cards de Métricas (`#sectionMetrics`)
* **Localização**: Seção `#sectionMetrics` com `#metricsGridContainer`.
* **Substituição**:
  * Estruturar como grade de dois cards principais (`#receitas` e `#fixas`) utilizando a classe `.card-fintech`.
  * Preservar os IDs `#metricReceitasVal` e o valor total de despesas.

---

### Passo 5: Atualização do Gráfico de Categorias (`#sectionCharts`)
* **Localização**: Busque por `id="sectionCharts"`.
* **Substituição**:
  * Utilizar `.card-fintech` com canvas `#categoryPieChart` centralizado.
  * O gráfico Chart.js existente desenhará o donut; posicione um elemento absoluto centralizado com o texto "Total R$ 5.230 no mês".
  * Exiba a legenda com porcentagens ao lado.

---

### Passo 6: Central Família & Vida (`#fintechQuickHub`)
* **Localização**: Busque por `id="fintechQuickHub"`.
* **Substituição**:
  * Adicione o banner de acolhimento.
  * Substitua a lista horizontal antiga por uma grade responsiva com classe `module-tile`:
    * Lista de Compras: `onclick="openMascotPitaco('compras', openShoppingListModal)"`
    * Minha Saúde: `onclick="openMascotPitaco('saude', openHealthMedsModal)"`
    * Pets e Vacinas: `onclick="openMascotPitaco('pet', openPetAreaModal)"`
    * Veículos: `onclick="openMascotPitaco('veiculos', openVeiculosHub)"`
    * Prestadores: `onclick="openMascotPitaco('prestadores', openServiceProvidersModal)"`
    * Cofrinhos: `onclick="openMascotPitaco('cofrinhos', openCreatePiggyModal)"`
    * Educação: `onclick="openMascotPitaco('educacao', openEducacaoHub)"`
    * Cartões & Faturas: `onclick="openMascotPitaco('cartoes', openManageCardsModal)"`

---

### Passo 7: Chat da Família em Tela Inteira (`#modalFamilyChat`)
* **Localização**: Busque por `id="modalFamilyChat"`.
* **Substituição**:
  * Altere a div externa para:
    `<div id="modalFamilyChat" class="full-screen-page hidden">`
  * Insira a barra de cabeçalho nativa `.page-header-back` com botão `closeFamilyChatModal()`.
  * Mantenha os containers internos de mensagens, a lista de membros e o formulário de envio de mensagens e áudio.

---

### Passo 8: Nova Navegação Inferior (4 Abas Fintech)
* **Localização**: Busque pela tag `<nav class="block md:hidden fixed bottom-0 ...">`.
* **Substituição**:
  * Aplique a classe `.bottom-nav`.
  * Substitua o grid de 7 botões pela estrutura de 4 abas:
    1. Início: `onclick="window.scrollTo({top: 0, behavior: 'smooth'})"`
    2. Transações: `onclick="document.getElementById('sectionTable').scrollIntoView({behavior: 'smooth'})"`
    3. Família & Vida: `onclick="document.getElementById('fintechQuickHub').scrollIntoView({behavior: 'smooth'})"`
    4. Chat: `onclick="openFamilyChatModal()"`

---

### Passo 9: Overlay do Mascote Oficial (`#modalMascotSectionPitaco`)
* **Localização**: Busque por `id="modalMascotSectionPitaco"`.
* **Substituição**:
  * Garanta as classes `.mascot-overlay-backdrop`, `.mascot-speech-bubble` e `.mascot-official-img`.
  * Mantenha os IDs `#mascotPitacoBadge`, `#mascotPitacoHeader`, `#mascotPitacoText`, `#btnEnterSectionFromPitaco`, `#mascotPitacoImg` e `#checkSkipPitacoThisMonth`.

---

## 3. Checklist de Validação Final

- [ ] **Android Status Bar**: A área da status bar no topo está pintada no mesmo tom azul `#0A3981` sem vãos em branco.
- [ ] **Modo Retrato (Galaxy A13 - 384px e M62 - 412px)**: Todos os cards cabem confortavelmente com padding horizontal de 12px a 16px.
- [ ] **Modo Paisagem**: Gire o dispositivo ou teste em viewport horizontal: nenhum scroll horizontal deve aparecer.
- [ ] **Piggy no Card Azul**: Setinhas de dicas respondem aos cliques avançando e retrocedendo as dicas. Mascote responde ao toque.
- [ ] **Sem Botões Proibidos no Herói**: Chat, Remédio e Lançar NÃO estão no card azul.
- [ ] **Pitaco com Mascotes Oficiais**: Ao abrir Saúde, Pets, Mercado, etc., o pitaco inteligente carrega a imagem oficial com fundo desfocado.
- [ ] **Bottom Nav**: Todas as 4 abas navegam com precisão e possuem área de toque de 48px.
