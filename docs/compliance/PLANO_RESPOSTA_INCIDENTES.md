# Plano de Resposta a Incidentes de Segurança

**Versão:** 2026-11-09 • **Responsável (encarregado/DPO):** Rodrigo Cardoso — rodrigocardosocn@gmail.com

## 1. O que é um incidente
Qualquer evento que comprometa confidencialidade, integridade ou disponibilidade de dados pessoais: vazamento de banco, chave exposta, conta invadida, APK adulterado, perda de dispositivo com dados sem proteção, falha que exponha dados entre famílias (RLS).

## 2. Classificação
| Nível | Exemplo | Meta de contenção |
|---|---|---|
| Crítico | Vazamento de dados de usuários; chave `service_role` exposta; APK malicioso publicado | 2 horas |
| Alto | Falha de isolamento entre contas; conta master comprometida | 8 horas |
| Médio | Vulnerabilidade explorável sem evidência de exploração | 3 dias |
| Baixo | Falha sem impacto em dados | 14 dias |

## 3. Fluxo de resposta
1. **Detectar e registrar** — origem do alerta (e-mail de segurança, Dependabot, relato de usuário, logs). Abrir registro com data/hora.
2. **Conter** — revogar/rotacionar chaves (Supabase: *Settings > API*; GitHub: *Secrets*), desabilitar a função/política afetada, retirar a release (`gh release delete`/marcar como pré-lançamento), forçar logout (invalidar sessões no Supabase).
3. **Avaliar** — quais dados, quantos titulares, período, se há dados sensíveis (saúde) ou de crianças.
4. **Erradicar e recuperar** — corrigir a causa, publicar nova versão, restaurar a partir de backup se necessário (ver `BACKUP_E_MONITORAMENTO.md`).
5. **Comunicar** — ver seção 4.
6. **Aprender** — revisão pós-incidente em até 10 dias com ações preventivas.

## 4. Comunicação (LGPD art. 48)
Se o incidente puder acarretar **risco ou dano relevante** aos titulares:
- **ANPD:** comunicar em prazo razoável — referência da ANPD: **3 dias úteis** do conhecimento (formulário em gov.br/anpd).
- **Titulares afetados:** mesmo prazo, por e-mail e aviso dentro do app.

### Modelo — comunicação à ANPD
> Controlador: Rodrigo Cardoso (ControlPig) — Encarregado: rodrigocardosocn@gmail.com
> Data/hora do incidente e da ciência: ___
> Natureza e descrição do incidente: ___
> Categorias e nº aproximado de titulares afetados: ___ (há crianças? ___ )
> Dados envolvidos (categorias): ___ (há dados sensíveis? ___ )
> Medidas técnicas e de segurança adotadas (antes e depois): ___
> Riscos aos titulares: ___
> Medidas para mitigar os efeitos: ___

### Modelo — comunicação ao titular
> Assunto: Aviso de segurança sobre sua conta ControlPig
> Identificamos em **[data]** um incidente que envolveu **[dados]**. O que aconteceu: ___. O que já fizemos: ___. O que recomendamos que você faça (ex.: trocar a senha): ___. Contato do encarregado: rodrigocardosocn@gmail.com. Pedimos desculpas pelo ocorrido.

## 5. Contatos e ferramentas
- Supabase Dashboard (logs, chaves, backups) • GitHub (Releases, Secrets, Security) • E-mail do encarregado.
- Registros locais do app: *Central de Privacidade > Registros de segurança* (por aparelho).

## 6. Testes do plano
Simulação anual: (a) rotacionar a `anon key` e publicar versão; (b) restaurar um backup em projeto de teste. Registrar resultado.
