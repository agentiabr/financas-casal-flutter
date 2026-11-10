# Operadores de Dados e Contratos (LGPD arts. 5º VII, 39 e 33)

O controlador (Rodrigo Cardoso — ControlPig) usa os operadores abaixo. **Ação do controlador:** aceitar/arquivar os termos de tratamento de dados (DPA) de cada um e registrar a data aqui.

| Operador | Papel | Dados tratados | Região/transferência | DPA / termos | Status |
|---|---|---|---|---|---|
| **Supabase** | Banco e autenticação em nuvem | Conta, lançamentos, chat, listas, snapshots | Região do projeto Supabase (verificar em *Project Settings > General*); transferência internacional possível | https://supabase.com/legal/dpa | ☐ Aceitar/arquivar o DPA no painel e anotar a data |
| **Google (Gemini API)** | IA opcional | Texto/imagem enviados **somente com consentimento** | EUA/global | https://ai.google.dev/gemini-api/terms | ☐ Revisar termos; chave é do próprio usuário |
| **Google (reconhecimento de voz do Android)** | Voz | Áudio processado pelo serviço do SO | Dispositivo/Google | Termos do Android/Google | ☐ Informado na Política de Privacidade |
| **GitHub** | Código e distribuição do APK | Nenhum dado de usuário | EUA | https://github.com/customer-terms/github-data-protection-agreement | ☑ Sem dados pessoais de usuários |
| **WhatsApp (Meta)** | Compartilhamento iniciado pelo usuário | O que o usuário decidir enviar | — | Termos do WhatsApp | ☑ Ação iniciada pelo usuário |

## Cláusulas mínimas exigidas dos operadores
- Tratar dados apenas conforme instruções do controlador.
- Medidas de segurança compatíveis (criptografia em trânsito/repouso, controle de acesso).
- Notificar incidentes ao controlador sem demora.
- Suboperadores informados; apagar/devolver dados ao fim do contrato.
- Garantias para transferência internacional (cláusulas-padrão/adequação).

## Revisão
Revisar esta lista a cada nova integração e, no mínimo, a cada 12 meses.
