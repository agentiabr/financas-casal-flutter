# Backup, Monitoramento e Logs

## 1. Backups
| Camada | Mecanismo | Frequência | Retenção | Como restaurar |
|---|---|---|---|---|
| **No aparelho** | Cópia automática local dos lançamentos, cartões e metas (`cp_autobackup_v1`) | a cada 20h de uso | 3 últimas | *Central de Privacidade > Cópias automáticas > Restaurar* |
| **Exportação do usuário** | JSON em *Downloads/ControlPig* (Central de Privacidade > Exportar) | sob demanda | do usuário | Reimportar via suporte |
| **Nuvem (Supabase)** | Backups diários do plano Supabase (PITR em planos pagos) | diário | conforme o plano | *Dashboard > Database > Backups* |
| **Dump externo** | Workflow `supabase_backup.yml` (`pg_dump` agendado) | semanal | artefato 30 dias | `psql` em projeto de teste |

> O workflow só roda se o segredo `SUPABASE_DB_URL` estiver configurado em *GitHub > Settings > Secrets*. Sem ele, ele apenas registra que foi ignorado.
> O dump é um **artefato do GitHub Actions** (visível a quem tem acesso ao repositório). Mantenha o repositório privado ou criptografe o dump antes de usar em produção.

**Teste de restauração:** 1x por trimestre restaurar o último dump em um projeto Supabase de teste e conferir contagem de linhas das tabelas principais.

## 2. Monitoramento de ameaças
- **Dependências:** Dependabot (pub, GitHub Actions, Gradle) semanal — alertas em *Security > Dependabot*.
- **Análise estática:** workflow `security_checks.yml` (segurança do código + `flutter analyze`) em todo push/PR e semanalmente.
- **App:** erros de JavaScript e eventos de segurança (falhas de login, bloqueios, ações sensíveis) vão para o log de auditoria local (sem dados pessoais).
- **Servidor:** habilitar em *Supabase > Reports/Logs* alertas de picos de erros de autenticação. **Recomendado:** adicionar Sentry/Crashlytics (exige criar projeto e DSN — fora do escopo do código atual).

## 3. Logs seguros
- Registro local `cp_audit_log_v1`: ≤ 300 eventos, 90 dias; **nunca** grava senha, CPF, tokens ou chaves; e-mail é mascarado (`ro***@gmail.com`).
- Eventos: `login_ok`, `login_fail`, `login_lockout`, `password_set/change/reset`, `register`, `logout`, `consent_*`, `data_export`, `account_delete`, `admin_open`, `stepup_ok`, `subscription_cancel`, `refund_request`, `retention_purge`, `auto_backup`, `js_error`.
- Servidor: tabela `audit_logs` append-only (migração `20261109120000_security_compliance.sql`).
