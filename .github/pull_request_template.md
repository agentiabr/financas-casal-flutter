## O que muda
<!-- Descreva a alteração e o motivo -->

## Checklist de revisão (segurança e privacidade)
- [ ] `python tools/security_check.py` passa (sem senhas fixas, segredos ou CSP removida)
- [ ] Textos vindos do usuário inseridos em HTML usam `escapeHtml(...)`
- [ ] Nenhum dado pessoal novo é coletado — ou a Política de Privacidade foi atualizada
- [ ] Nenhuma senha, token ou chave aparece em código, logs ou mensagens
- [ ] Mudou preço/cobrança/cancelamento? Termos e paywall foram atualizados
- [ ] Mudou banco? Migração SQL inclui RLS e foi testada em projeto de teste
- [ ] Versão do `pubspec.yaml` incrementada, se for release

## Como testar
<!-- Passos manuais -->
