# Design System ControlPig V2.2 — Fintech Mobile
**Lead UI/UX & Design Systems**: Padrão Fintech Mobile (Nubank, Itaú, Revolut)  
**Ambiente de Execução**: Android WebView (Samsung Galaxy A13 e Galaxy M62)  
**Arquivos de Destino**: `design_system/` (CSS injetável, tokens, componentes, implementação e preview)

---

## 1. Princípios e Filosofia de Design

O **ControlPig** adota a linguagem visual das principais fintechs globais e brasileiras (Nubank, Itaú Íon, Revolut), combinando solidez institucional bancária com a simpatia acolhedora do mascote Piggy:

1. **Confiança Bancária & Clareza Imediata**: O azul marinho institucional (`#0A3981` a `#082F6D`) unifica a identidade visual, pintando seamless a barra de status do Android (`safe-area-inset-top`). O usuário sabe exatamente onde está seu dinheiro em menos de 2 segundos.
2. **Curadoria Fiel ao App**: Nenhuma funcionalidade fantasma é criada. Cada elemento no design mapeia diretamente para os dados, IDs e rotinas já existentes em `assets/index.html`.
3. **Mascote Humano e Contextual (Não Ilustração Genérica)**: O Piggy não substitui ícones nem ilustrações funcionais; ele é um conselheiro proativo que aparece com dicas inteligentes (*pitacos*) e setinhas de navegação dentro do card azul, ou em tela com fundo desfocado (*backdrop-blur*) ao acessar seções importantes.
4. **Mobile First com Telas Inteiras**: Modais flutuantes ("janelinhas") foram banidos em favor do padrão de tela inteira nativa do Android (`.full-screen-page`), com barra de topo contendo botão de voltar, eliminando barras de rolagem duplas.
5. **Zero Scroll Horizontal**: O layout se adapta dinamicamente tanto em orientação vertical (retrato) quanto horizontal (paisagem) nos aparelhos alvo (Galaxy A13 e Galaxy M62).

---

## 2. Curadoria do Print de Referência

O print de referência enviado pelo usuário (`media_1792635150484_9251dbae.jpg`) traz uma concepção de 4 telas e interações. Abaixo está a curadoria analítica detalhada com o que foi aproveitado, adaptado e descartado:

| Elemento no Print | Status na Curadoria | Mapeamento no ControlPig | Motivo Técnico / Decisão de UX |
| :--- | :--- | :--- | :--- |
| **Cabeçalho com Logo "CtrlPig" & Avatar** | **Adaptado** (Ref. Aprovada) | `header` do app: Membro ativo com foto/emoji à esquerda + 3 botões translúcidos à direita (Busca, Notificações, Perfil) | Mantida a disposição aprovada da referência `media_1792629074184_449975c7.png`, sem o cartão de crédito e pintando a status bar. |
| **Card Azul do Dashboard** | **Mantido & Aprimorado** | `#heroCardBanner`: Saldo Disponível (`#heroSaldoDisponivel`), Ciclo (`#heroCycleTag`), Dicas do Piggy com setinhas (`#heroPiggyTipCard`, `#mascotImage`) | Respeitada a regra explícita: Piggy dentro do card azul com setinhas de dicas; sem botões Chat/Remédio/Lançar polindo o card azul. |
| **Card Saldo Atual + Receitas + Despesas** | **Mantido** | `#heroSaldoDisponivel` + `#sectionMetrics` (`#receitas`, `#fixas`, `#gastos`, `#saldo`) | Fintech look com alta legibilidade e pílulas semânticas (verde para receitas, vermelho para saídas). |
| **Gráfico Donut de Despesas por Categoria** | **Mantido** | `#sectionCharts` / `#categoryPieChart` | Renderizado via Chart.js existente no app, com total centralizado e legenda clara de fatias. |
| **Filtro de Período da Transações** | **Mantido** | Pílulas Todas, Entradas, Saídas, Parceladas | Mapeia para os filtros reais da tabela de lançamentos do app (`#filterInputTable`, tipos de despesas). |
| **Ação "+ Nova Transação"** | **Mantido** | Botão azul que dispara `openNewTxModal()` | Ação primária de lançamento. |
| **Ação "Escanear NFe"** | **Mantido** | Botão que dispara `openInvoiceScanModal()` | Integração real com o scanner OCR de cupons fiscais. |
| **Ação "Transferir"** | **DESCARTADO** | *Não aplicável* | **Motivo**: O ControlPig é um gestor financeiro familiar / aplicativo de orçamento, **NÃO uma instituição bancária autorizada a liquidar transferências PIX ou TED**. Incluir "Transferir" geraria falsa expectativa e viola o princípio de curadoria estrita. |
| **Ação "Categorias"** | **Mantido** | Filtros rápidos de gôndola e categoria | Mapeia para `#establishmentPillFilters` e filtro categórico do app. |
| **Lista de Transações Agrupadas por Data** | **Mantido** | Linhas `#mainTransactionsTable` com visual `.list-item-fintech` | Agrupamento cronológico (Hoje, Ontem, data) com ícones de categoria e toque para abrir detalhes (`openEditTxModal(id)`). |
| **Hero Card "Família & Vida"** | **Mantido** | Banner de acolhimento modular com Piggy | Apresenta a central de módulos familiares de forma organizada. |
| **Módulos: Educação, Compras, Pets, Saúde, Veículos, Prestadores, Cofrinhos** | **Mantidos** | Mapeamento direto para funções reais do app (ver mapa abaixo) | São funcionalidades completas já programadas e funcionais no app. |
| **Módulo "Documentos"** | **DESCARTADO** | Substituído por **Cartões & Faturas** e **Contas a Pagar** | **Motivo**: O ControlPig não possui um repositório genérico de arquivos em nuvem ("Google Drive"). Os comprovantes pertencem diretamente às transações ou são enviados no chat da família. No lugar, foram inseridos os módulos reais de alto valor **Cartões de Crédito** (`openManageCardsModal()`) e **Contas a Pagar** (`openBillsReminderModal()`). |
| **Chat da Família com Membros no Topo** | **Mantido** | `#modalFamilyChat`: Seletor de membros com avatares, timeline estilo WhatsApp/Fintech | Permite alternar e filtrar mensagens por membro (Rodrigo, Márcia, etc.). |
| **Card de Conta / Fatura no Chat** | **Mantido** | Cartão rico de conta/despesa com status "Pago" e botão "Ver detalhes" | Totalmente compatível com a função `testShoppingListReceivedAlertFlow()` e lembretes de contas compartilhadas. |
| **Comprovante PDF / Imagem no Chat** | **Mantido** | Anexo de recibo com ícone e tamanho | Suporta a rotina de envio de comprovantes de pagamento entre o casal. |
| **Ícone de Chamada Telefônica no Chat** | **DESCARTADO** | Substituído por envio de áudio no rodapé | **Motivo**: O app não possui servidor VoIP para chamadas telefônicas. O recurso de áudio real do app é a gravação de recados/transcrição (`openVoiceRecordModal()`). |
| **Navegação Inferior (Bottom Bar)** | **Atualizado (4 Abas)** | 1. Início, 2. Transações, 3. Família & Vida, 4. Chat | Simplificação de 7 botões aglomerados para 4 abas fintech nítidas com áreas de toque de no mínimo 48px. |

---

## 3. Mapa Tela-a-Tela (Print → Seção Real do App)

### Tela 1: Dashboard (Início)
* **Status Bar & Cabeçalho**: `.app-header` com fundo `#0A3981`, avatar do membro ativo (`#headerUserAvatar`), nome (`#headerUserName`), botão busca, sino com badge de alertas (`#headerNotifBadge`) e botão admin/perfil (`openAdminModal()`).
* **Card Herói Azul**: `#heroCardBanner` com Saldo Disponível (`#heroSaldoDisponivel`), botão de ocultar saldo (`#btnHeroPrivacyToggle`), seletor de ciclo vigente (`#heroCycleTag` + `#cycleDropdownMenu`), balão de dicas com navegação anterior/próxima (`navigatePiggyTip(-1)` / `navigatePiggyTip(1)`), mascote oficial 3D (`#mascotImage`), e mini-indicadores de dias restantes, % comprometido e parcelados.
* **Métricas Principais**: `#sectionMetrics` com receitas totais (`#metricReceitasVal`), despesas fixas, variáveis e saldo líquido.
* **Régua de Supermercado**: `#sectionFoodBudget` com progresso visual do orçamento de mercado e pino vertical do dia do mês (`#foodMonthDayPin`).
* **Gráficos de Categoria**: `#sectionCharts` com donut de despesas (`#categoryPieChart`) e evolução mensal.

### Tela 2: Transações (Lançamentos)
* **Cabeçalho de Seção**: Título "Transações" com busca rápida (`#filterInputTable`) e botão de privacidade da tabela (`#btnToggleTablePrivacy`).
* **Barra de Pílulas de Filtro**: Todas, Entradas (Receitas), Saídas (Despesas), Parceladas.
* **Barra de Ações Rápidas**:
  * `+ Nova Transação` → chama `openNewTxModal()`
  * `Escanear NFe` → chama `openInvoiceScanModal()`
  * `Categorias` → abre filtros categorizados
* **Lista Agrupada de Transações**: `#mainTransactionsTable` estruturada com estilo `.list-item-fintech`, ícone de categoria, descrição, membro responsável, valor com cor semântica e seta de navegação para edição (`openEditTxModal(id)`).

### Tela 3: Família & Vida (Central de Módulos)
* **Card de Apresentação**: Banner institucional com o mascote Piggy explorador e chamada "Tudo da sua família em um só lugar".
* **Grade 2 Colunas com Módulos Reais**:
  1. **Educação** (`openEducacaoHub()`): Mensalidades escolares, cursos e material.
  2. **Lista de Compras** (`openShoppingListModal()`): Lista colaborativa, histórico de preços e itens por gôndola.
  3. **Pets e Vacinas** (`openPetAreaModal()`): Carteirinha digital, vacinas em dia e custos veterinários.
  4. **Minha Saúde & Remédios** (`openHealthMedsModal()`): Remédios contínuos, consultas, exames e rotina fitness.
  5. **Veículos & Garagem** (`openVeiculosHub()`): Manutenções, IPVA, seguro, abastecimento e multas.
  6. **Prestadores de Serviço** (`openServiceProvidersModal()`): Diaristas, eletricistas, encanadores e orçamentos.
  7. **Cofrinhos e Metas** (`navigateToAccordionSection('sectionPiggy', 'sectionPiggyContent')`): Metas de economia do casal.
  8. **Cartões & Faturas** (`openManageCardsModal()`): Limites, fechamento e controle por cartão.

### Tela 4: Chat da Família
* **Cabeçalho**: `< Voltar` (`closeFamilyChatModal()`), título "Chat da Família", status online de Rodrigo & Márcia.
* **Filtro de Membros Horizontal**: Pílulas com avatares de todos os membros cadastrados no plano da família.
* **Timeline de Mensagens**:
  * Balões de fala com avatar, hora e status de entrega.
  * Cards inteligentes de despesas lançadas (ex.: "Energia Elétrica - R$ 245,00 - [Pago]").
  * Anexos de comprovantes fiscais (ex.: "Comprovante_energia.pdf").
* **Rodapé de Entrada**:
  * Botão `+` para anexar cupom ou foto.
  * Campo de texto "Mensagem...".
  * Botão de microfone para mensagem de voz (`openVoiceRecordModal()`).

---

## 4. Regras para Android WebView (Galaxy A13 e Galaxy M62)

### A. Integração com a Status Bar do Android
* O cabeçalho do app utiliza a propriedade CSS `padding-top: max(10px, env(safe-area-inset-top, 0px))`.
* A cor de fundo `#0A3981` (com gradiente para `#051C44`) preenche toda a barra de status do sistema sem linhas brancas ou cortes visuais indesejados.
* A barra inferior respeita a barra de gestos do Android com `padding-bottom: max(6px, env(safe-area-inset-bottom, 0px))`.

### B. Modo Retrato vs. Modo Paisagem (Zero Scroll Horizontal)
* **Trava de Largura**: O elemento raiz possui `overflow-x: hidden !important` e largura `100%`.
* **Reflow em Paisagem (`@media (orientation: landscape)`)**:
  * A grade do Dashboard passa a exibir duas colunas lado a lado (`.landscape-grid-2col`), aproveitando a largura estendida sem forçar rolagem vertical excessiva.
  * A altura mínima do balão de dicas é rebaixada para `96px`.
  * Os cards de módulos de "Família & Vida" adaptam-se para 4 colunas em vez de 2, garantindo visualização completa.

### C. Área de Toque Mínima (Ergonomia Android)
* Todos os botões, abas e itens clicáveis possuem área de interação mínima de **48x48px**, atendendo às diretrizes de acessibilidade do Google Material Design e WCAG.

---

## 5. Padrão de Telas Inteiras (Full-Screen Page)

Substitui a antiga abordagem de modais flutuantes com fundo semi-transparente por páginas completas imersivas:

```
┌──────────────────────────────────────────────┐
│ [←] Mundo Pet & Saúde            [+ Pet]     │ ← .page-header-back (Azul #0A3981)
├──────────────────────────────────────────────┤
│                                              │
│ Conteúdo rolável de forma fluida e nativa    │
│ sem caixas de rolagem aninhadas.             │
│                                              │
│                                              │
│                                              │
├──────────────────────────────────────────────┤
│ Safe Area Inferior do Android (Gestos)       │
└──────────────────────────────────────────────┘
```

* **Classe CSS**: `.full-screen-page`
* **Transição**: Deslizamento lateral suave ou fade-in rápido (150ms).
* **Navegação**: O botão `[←]` sempre fecha a tela retornando à visualização anterior, mantendo a consistência mental do botão "Voltar" nativo do Android.

---

## 6. Padrão de Mascotes Oficiais e Overlay de Pitaco

Os mascotes oficiais residem em `assets/images/mascote_oficial_*.png`. Eles aparecem em dois contextos autorizados:

1. **Card Azul do Dashboard**: Mascote 3D interativo (`mascotImage`) com reações ao toque e balão com setinhas para alternar dicas de economia, mercado e chat.
2. **Overlay de Entrada de Seção (`modalMascotSectionPitaco`)**:
   * Fundo da seção fica com desfoque de vidro fosco (`backdrop-filter: blur(14px)`).
   * Balão com borda neon e badge indicativo (ex.: `🩺 Alerta do Piggy Médico`).
   * Imagem oficial caracterizada do mascote (`mascote_oficial_saude.png`).
   * Botão direto de entrada "Acessar Seção Agora →" e opção "Não exibir este alerta novamente este mês".
