#!/usr/bin/env python3
"""Verificações estáticas de segurança/privacidade (executadas no CI e localmente).

Falha (exit 1) se encontrar regressões em requisitos que dá para checar no código:
senhas fixas, segredos expostos, CSP ausente, tráfego em texto puro, documentos legais ausentes etc.
"""
import base64
import glob
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
HTML = os.path.join(ROOT, 'assets', 'index.html')
MANIFEST = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'AndroidManifest.xml')

failures = []
passes = []


def read(path):
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        return f.read()


def check(name, ok, detail=''):
    (passes if ok else failures).append(f'{name}{(" — " + detail) if detail and not ok else ""}')


html = read(HTML)

# 1) Sem senhas fixas / comparação em texto puro
bad_cmp = re.findall(r"""\b(?:pass|senha|password)\s*===?\s*['"][^'"]{3,}['"]""", html)
bad_cmp = [
    m for m in bad_cmp
    if '__REMOVED_FOR_SECURITY__' not in m
    and not re.search(r"""['"](?:string|undefined|object|function|number|boolean)['"]""", m)
]
check('Sem senha fixa/comparação literal no código', not bad_cmp, str(bad_cmp[:3]))
check('Sem armazenar senha em texto puro (senha: pass)', not re.search(r'\bsenha\s*:\s*(pass|senha|novaSenha|newPass)\b', html))
check('Sem atribuição de senha em texto puro à sessão', not re.search(r'currentUserSession\.senha\s*=', html))

# 2) Segredos
check('Sem chave Google API (AIza...) no código', not re.search(r'AIza[0-9A-Za-z_\-]{35}', html + read(os.path.join(ROOT, 'pubspec.yaml'))))
check('Sem "service_role" no app', 'service_role' not in html and not any('service_role' in read(p) for p in glob.glob(os.path.join(ROOT, 'lib', '**', '*.dart'), recursive=True)))
jwt_bad = []
for p in glob.glob(os.path.join(ROOT, 'lib', '**', '*.dart'), recursive=True) + [HTML]:
    for tok in re.findall(r'eyJ[\w\-]{10,}\.([\w\-]{10,})\.[\w\-]{10,}', read(p)):
        try:
            payload = json.loads(base64.urlsafe_b64decode(tok + '=' * (-len(tok) % 4)))
            if payload.get('role') not in (None, 'anon'):
                jwt_bad.append(os.path.basename(p))
        except Exception:
            pass
check('JWTs embutidos são apenas "anon"', not jwt_bad, str(jwt_bad))

# 3) Navegador/WebView
check('CSP definida (meta Content-Security-Policy)', 'http-equiv="Content-Security-Policy"' in html)
check("CSP bloqueia object-src", "object-src 'none'" in html)
check('escapeHtml usado nos templates (>= 150 usos)', len(re.findall(r'escapeHtml\(', html)) >= 150)

# 4) Android
if os.path.exists(MANIFEST):
    mf = read(MANIFEST)
    check('HTTPS obrigatório (usesCleartextTraffic=false)', 'usesCleartextTraffic="false"' in mf)
    check('allowBackup=false', 'allowBackup="false"' in mf)

# 5) Rate limit / hash / auditoria presentes
check('Hash PBKDF2 implementado', 'pbkdf2-sha256' in html)
check('Bloqueio por tentativas implementado', 'registerFailure' in html and 'lockRemaining' in html)
check('Log de auditoria implementado', 'cp_audit_log_v1' in html)

# 6) Documentos legais e direitos do titular
for needle, label in [('Termos de Uso', 'Termos de Uso'), ('Política de Privacidade', 'Política de Privacidade'),
                      ('Central de Privacidade', 'Central de Privacidade'), ('deleteMyAccount', 'Excluir conta'),
                      ('exportMyData', 'Exportar dados'), ('cancelSubscription', 'Cancelar assinatura'),
                      ('requestRefund', 'Reembolso'), ('Uso de Inteligência Artificial', 'Aviso de IA'),
                      ('Licenças de código aberto', 'Licenças de terceiros')]:
    check(f'Presente no app: {label}', needle in html)

# 7) Documentação de conformidade
for doc in ['SECURITY.md', 'docs/compliance/CHECKLIST_40_REQUISITOS.md', 'docs/compliance/PLANO_RESPOSTA_INCIDENTES.md',
            'docs/compliance/OPERADORES_E_CONTRATOS.md', 'docs/compliance/BACKUP_E_MONITORAMENTO.md',
            'docs/compliance/GESTAO_VULNERABILIDADES.md']:
    check(f'Documento existe: {doc}', os.path.exists(os.path.join(ROOT, doc)))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')
print(f'✔ {len(passes)} verificações OK')
for f in failures:
    print(f'✘ FALHOU: {f}')
sys.exit(1 if failures else 0)
