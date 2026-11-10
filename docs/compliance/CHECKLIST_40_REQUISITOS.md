# Checklist dos 40 Requisitos — Evidências e Pendências (v2.1.125)

Legenda: ✅ atendido no código/documentação • 🟡 atendido em parte (há ação manual ou limitação) • ➖ não pertinente

> **Limitação estrutural:** o login e a assinatura do app ainda são validados **no aparelho** (não há servidor de autorização próprio). Isso foi endurecido (hash, bloqueio, step-up), mas só uma migração completa para **Supabase Auth + papéis no servidor** elimina o risco de um usuário alterar o próprio aparelho. A base SQL já está em `supabase/migrations/20261109120000_security_compliance.sql`.

| # | Requisito | Status | Evidência / o que falta |
|---|---|:-:|---|
| 1 | Autenticação segura | 🟡 | Senhas com PBKDF2, política 8+ com letras e números, sem senha padrão, sem "acesso garantido", recuperação com código de uso único (10 min, 5 tentativas, não exibido na tela). **Falta:** autoridade no servidor (Supabase Auth como fonte única). |
| 2 | Controle de acesso | 🟡 | RLS por família (SQL); painel admin exige reautenticação; `is_master()` no servidor (SQL). **Falta:** aplicar a migração e migrar o admin para chamadas RPC protegidas. |
| 3 | Criptografia de dados | 🟡 | TLS em trânsito; Supabase cifra em repouso; hash de senhas; `allowBackup=false`. **Falta:** cifrar `localStorage` (requer armazenamento seguro nativo). |
| 4 | HTTPS/TLS | ✅ | `usesCleartextTraffic="false"` + `network_security_config` (verificado por `tools/security_check.py`). |
| 5 | Hash de senhas | ✅ | PBKDF2-HMAC-SHA256 (150 mil iterações, sal de 16 bytes); migração automática de senhas antigas; testado com vetores RFC (`tools/test_cpsec.py`). |
| 6 | SQL injection | ✅ | Acesso via cliente Supabase (consultas parametrizadas); sem SQL concatenado. |
| 7 | XSS / CSRF | 🟡 | CSP (`object-src 'none'`, scripts só de origens conhecidas); `escapeHtml` em +180 pontos (33 corrigidos nesta versão). **Falta:** revisar os demais `innerHTML` restantes e remover `unsafe-inline`. CSRF não se aplica (sem cookies). |
| 8 | Rate limiting | ✅ (cliente) | 5 falhas → bloqueio crescente (30 s … 15 min) + limite global; aplica a login, recuperação, troca de senha, step-up. **Servidor:** configurar *Auth > Rate Limits* no Supabase. |
| 9 | Proteção de APIs | 🟡 | RLS; chave Gemini deixou de ir para o snapshot na nuvem; chamadas à IA exigem consentimento. **Falta:** chave Gemini fora do `localStorage`. |
| 10 | Auditoria de dependências | ✅ | `.github/dependabot.yml` + workflow `security_checks.yml`. **Ação:** ativar alertas no GitHub (ver GESTAO_VULNERABILIDADES.md). |
| 11 | Política de privacidade | ✅ | Em Login/Cadastro/Central de Privacidade. **Revisão jurídica recomendada.** |
| 12 | Bases legais | ✅ | Tabela na Política de Privacidade. |
| 13 | Minimização | ✅ | CPF/WhatsApp opcionais; sem localização contínua. |
| 14 | Finalidades documentadas | ✅ | Tabela finalidade × base legal. |
| 15 | Consentimento | ✅ | Aceite obrigatório no cadastro e para usuários existentes; consentimentos específicos (crianças, saúde, IA) com revogação. |
| 16 | Política de cookies | ➖ | App sem cookies de rastreamento (declarado na Política). |
| 17 | Direitos dos titulares | ✅ | Central de Privacidade: exportar, revogar, excluir; contato do encarregado. (Correção: edição do perfil.) |
| 18 | Exclusão de dados | ✅ | "Excluir minha conta e dados" (local + RPC `delete_my_account`). **Ação:** executar a migração SQL. |
| 19 | Retenção | ✅ | Tabela de retenção; lixeira com expurgo automático em 30 dias (itens com data); logs 90 dias. |
| 20 | Contratos com operadores | 🟡 | `OPERADORES_E_CONTRATOS.md`. **Ação:** aceitar/arquivar DPAs (Supabase, Google). |
| 21 | Termos de uso | ✅ | No app. **Revisão jurídica recomendada.** |
| 22 | Transparência de preços | ✅ | Preços nos Termos, cadastro e paywall. |
| 23 | Cobranças transparentes | ✅ | Resumo da contratação no paywall; sem renovação automática em cartão. |
| 24 | Cancelamento | ✅ | Botão com protocolo (Central de Privacidade). |
| 25 | Reembolso | ✅ | Política de 7 dias (CDC art. 49) + solicitação com protocolo. |
| 26 | Identificação do fornecedor | 🟡 | Nome e e-mail exibidos. **Falta:** CPF/CNPJ e endereço — preencher `LEGAL_CONFIG.doc` e `.endereco` em `assets/index.html`. |
| 27 | Publicidade transparente | ➖ | Sem anúncios. |
| 28 | Depoimentos autênticos | ➖ | Sem depoimentos. |
| 29 | Licenças de uso | ✅ | Licença de uso nos Termos + tela "Licenças de código aberto". |
| 30 | Transparência sobre IA | ✅ | Tela "Uso de IA", consentimento antes da primeira chamada, rótulo na política. |
| 31 | Backups automatizados | ✅ | Cópia local a cada 20h (3 últimas) + workflow `supabase_backup.yml` (requer segredo) + backups do Supabase. |
| 32 | Logs seguros | ✅ | Auditoria sem dados sensíveis, e-mail mascarado, retenção 90 dias; tabela `audit_logs` append-only. |
| 33 | Monitoramento de ameaças | 🟡 | Dependabot, CI semanal, erros no log. **Falta:** Sentry/Crashlytics (precisa de DSN). |
| 34 | Resposta a incidentes | ✅ | `PLANO_RESPOSTA_INCIDENTES.md`. |
| 35 | Notificação de incidentes | ✅ | Modelos ANPD/titulares no plano. |
| 36 | Testes de segurança | ✅ | `tools/test_cpsec.py` (27 testes), `tools/security_check.py`, `tools/check_js_syntax.py` no CI. |
| 37 | Revisão de código | 🟡 | PR template + CODEOWNERS + CI. **Ação:** proteger a branch `main` no GitHub. |
| 38 | Privilégios administrativos | 🟡 | Step-up (senha a cada 10 min) + auditoria; papéis no servidor (SQL). Mesma limitação do item 2. |
| 39 | Gestão de vulnerabilidades | ✅ | `SECURITY.md` + `GESTAO_VULNERABILIDADES.md` + Dependabot. |
| 40 | Auditoria de conformidade | 🟡 | Este documento + `security_check.py`. **Falta:** auditoria independente/jurídica. |

## Ações manuais pendentes (não dependem de código)
1. Preencher CPF/CNPJ e endereço em `LEGAL_CONFIG`.
2. Executar `supabase/migrations/20261109120000_security_compliance.sql` e definir o administrador em `user_roles`.
3. Aceitar os DPAs (Supabase/Google) e anotar em `OPERADORES_E_CONTRATOS.md`.
4. GitHub: Dependabot alerts, secret scanning, proteção de branch, 2FA.
5. Supabase: *Auth > Rate Limits*, confirmação de e-mail, política de senha.
6. Revisão dos textos legais por advogado.
7. Cupons: hoje só são aceitos os cadastrados no aparelho do administrador ou chaves `CPIG-...`; para cupons que funcionem em qualquer aparelho, é preciso uma tabela de cupons no servidor.
