# Gestão de Vulnerabilidades

## Processo
1. **Identificar** — Dependabot (semanal), `security_checks.yml`, relatos por e-mail (`SECURITY.md`), revisão de código.
2. **Classificar** (CVSS simplificado) e **priorizar**.
3. **Corrigir** em branch com Pull Request (modelo em `.github/pull_request_template.md`), executando `python tools/security_check.py`.
4. **Publicar** nova versão (tag `vX.Y.Z`) e comunicar se houve impacto a usuários.
5. **Verificar** que o alerta foi fechado e registrar no histórico.

## Prazos (SLA de correção)
| Severidade | Prazo |
|---|---|
| Crítica | 48 horas |
| Alta | 7 dias |
| Média | 30 dias |
| Baixa | próxima versão |

## Rotinas
- Semanal: revisar PRs do Dependabot e alertas de segurança.
- Mensal: `flutter pub outdated` e atualização de dependências diretas.
- Trimestral: teste de restauração de backup e revisão do `CHECKLIST_40_REQUISITOS.md`.
- Anual: simulação do plano de incidentes.

## Configurações do GitHub recomendadas (ação manual do proprietário)
- *Settings > Code security*: ativar **Dependabot alerts**, **Dependabot security updates**, **Secret scanning** e **Push protection**.
- *Settings > Branches*: proteger `main` (exigir Pull Request e checks `security_checks`).
- Ativar **verificação em duas etapas** na conta GitHub.
