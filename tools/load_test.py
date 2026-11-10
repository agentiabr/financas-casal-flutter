#!/usr/bin/env python3
"""Suíte de Teste de Carga e Estresse — ControlPig (Nuvem Supabase + Motor Local V8).

Executa:
1. Teste de Carga Concorrente na Nuvem (Supabase PostgREST + GoTrue Auth):
   - Escadas de 10, 25, 50 e 100 conexões simultâneas (somente leitura segura, sem sujar o banco).
   - Métricas: RPS (req/s), latência média, mínima, p50, p95, p99, máxima e taxa de sucesso HTTP.
2. Teste de Carga de Volume de Dados no App (V8 / assets/index.html):
   - Simula carteiras com 100, 1.000, 5.000 e 10.000 lançamentos financeiros + compras parceladas.
   - Mede tempo de agregação do Dashboard, gastos por membro (Ambos/Individual), filtro mensal,
     serialização JSON, tamanho em localStorage e impacto do auto-backup (cp_autobackup_v1).
3. Teste de Estresse de Segurança (Ataque de Força Bruta Simulado):
   - Dispara 200 tentativas seguidas contra o rate-limiter/lockout para validar contenção em < 5ms.
"""
import concurrent.futures
import json
import os
import re
import statistics
import sys
import time
import urllib.error
import urllib.request
from py_mini_racer import MiniRacer

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
HTML_PATH = os.path.join(ROOT, 'assets', 'index.html')

SUPABASE_URL = 'https://ipwgvwmuhcfrdjkzzzdv.supabase.co'
ANON_KEY = (
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlwd2d2d211aGNmcmRqa3p6emR2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE1MTYyMTcsImV4cCI6MjEwNzA5MjIxN30.'
    '_X2iTDoaiwMBz8MU9MrFfOxYAn-JWkSrsegwj8Lts2k'
)

ENDPOINTS = [
    '/rest/v1/user_roles?select=user_id&limit=1',
    '/rest/v1/audit_logs?select=id&limit=1',
    '/rest/v1/legal_consents?select=id&limit=1',
    '/auth/v1/health',
]


def hit_once(idx):
    ep = ENDPOINTS[idx % len(ENDPOINTS)]
    url = SUPABASE_URL + ep
    req = urllib.request.Request(
        url,
        headers={
            'apikey': ANON_KEY,
            'Authorization': 'Bearer ' + ANON_KEY,
            'User-Agent': 'ControlPig-LoadTest/1.0',
        },
    )
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            _ = r.read()
            dt = (time.perf_counter() - t0) * 1000.0
            return (r.status, dt, ep)
    except urllib.error.HTTPError as e:
        dt = (time.perf_counter() - t0) * 1000.0
        return (e.code, dt, ep)
    except Exception as e:
        dt = (time.perf_counter() - t0) * 1000.0
        return (0, dt, str(e))


print('=== 1) TESTE DE CARGA NA NUVEM (SUPABASE NANO - SA-EAST-1 SÃO PAULO) ===')
# Warmup
hit_once(0)

cloud_results = {}
for concurrency, total_reqs in [(10, 30), (25, 50), (50, 100), (100, 150)]:
    t_start = time.perf_counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as ex:
        res = list(ex.map(hit_once, range(total_reqs)))
    wall = time.perf_counter() - t_start
    lats = sorted([r[1] for r in res])
    codes = {}
    for r in res:
        codes[r[0]] = codes.get(r[0], 0) + 1
    p50 = lats[int(len(lats) * 0.50)]
    p95 = lats[int(len(lats) * 0.95)]
    p99 = lats[min(len(lats) - 1, int(len(lats) * 0.99))]
    rps = total_reqs / wall
    cloud_results[concurrency] = {
        'total_reqs': total_reqs,
        'wall_s': round(wall, 2),
        'rps': round(rps, 1),
        'avg_ms': round(statistics.mean(lats), 1),
        'min_ms': round(min(lats), 1),
        'p50_ms': round(p50, 1),
        'p95_ms': round(p95, 1),
        'p99_ms': round(p99, 1),
        'max_ms': round(max(lats), 1),
        'status_codes': codes,
    }
    print(
        f'  Concorrência {concurrency:3d} ({total_reqs:3d} reqs): '
        f'RPS={rps:5.1f} req/s | avg={statistics.mean(lats):6.1f}ms | '
        f'p50={p50:6.1f}ms | p95={p95:6.1f}ms | p99={p99:6.1f}ms | HTTP={codes}'
    )

print('\n=== 2) TESTE DE CARGA E VOLUME DE DADOS NO MOTOR DO APP (V8) ===')
html = open(HTML_PATH, encoding='utf-8').read()
cpsec_js = re.search(r'<script id="ctrlpigSecurityCompliance">(.*?)</script>', html, re.S).group(1)

ctx = MiniRacer()
ctx.eval(r"""
var window = globalThis;
var __store = {};
var localStorage = {
  getItem: function(k){ return Object.prototype.hasOwnProperty.call(__store,k) ? __store[k] : null; },
  setItem: function(k,v){ __store[k] = String(v); },
  removeItem: function(k){ delete __store[k]; },
  key: function(i){ return Object.keys(__store)[i] || null; },
  get length(){ return Object.keys(__store).length; },
  totalBytes: function(){
    var total = 0;
    for (var k in __store) {
      if (Object.prototype.hasOwnProperty.call(__store, k)) {
        total += (k.length + __store[k].length) * 2; // UTF-16 no WebView
      }
    }
    return total;
  }
};
var sessionStorage = { getItem:function(){return null;}, setItem:function(){}, removeItem:function(){}, clear:function(){} };
function TextEncoder(){}
TextEncoder.prototype.encode=function(s){ s=unescape(encodeURIComponent(s)); var a=new Uint8Array(s.length); for(var i=0;i<s.length;i++)a[i]=s.charCodeAt(i); return a; };
var __b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
function btoa(s){ var o='',i=0; while(i<s.length){ var a=s.charCodeAt(i++),b=s.charCodeAt(i++),c=s.charCodeAt(i++); var e1=a>>2,e2=((a&3)<<4)|(b>>4),e3=isNaN(b)?64:(((b&15)<<2)|(c>>6)),e4=isNaN(c)?64:(c&63); o+=__b.charAt(e1)+__b.charAt(e2)+(e3==64?'=':__b.charAt(e3))+(e4==64?'=':__b.charAt(e4)); } return o; }
function atob(s){ s=s.replace(/=+$/,''); var o='',bits=0,acc=0; for(var i=0;i<s.length;i++){ acc=(acc<<6)|__b.indexOf(s.charAt(i)); bits+=6; if(bits>=8){ bits-=8; o+=String.fromCharCode((acc>>bits)&255);} } return o; }
window.showToastUndo=function(){};
var document = { readyState:'complete', getElementById:function(){return null;}, addEventListener:function(){} };
window.addEventListener=function(){};
window.confirm=function(){return true;};
var setTimeout=function(){return 0;}; var setInterval=function(){return 0;};
function escapeHtml(str) {
  return String(str == null ? '' : str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
""")
ctx.eval(cpsec_js)

ctx.eval(r"""
function runVolumeBenchmark(txCount) {
  __store = {};
  var cats = ['Alimentação', 'Moradia', 'Transporte', 'Lazer', 'Saúde', 'Educação', 'Mercado', 'Pets'];
  var resps = ['Rodrigo', 'Esposa', 'Ambos', 'Comum'];
  var methods = ['Pix', 'Cartão de Crédito', 'Débito', 'Dinheiro'];
  var txs = [];
  var t0 = Date.now();
  for (var i = 0; i < txCount; i++) {
    var m = (i % 12) + 1;
    var d = (i % 28) + 1;
    var isCredit = (i % 4 === 1);
    txs.push({
      id: 'tx_' + i,
      desc: 'Compra teste de carga #' + i + ' Supermercado & Família',
      val: ((i * 37) % 1500) + 19.90,
      type: (i % 7 === 0) ? 'in' : 'out',
      cat: cats[i % cats.length],
      resp: resps[i % resps.length],
      method: methods[i % methods.length],
      date: '2026-' + (m < 10 ? '0' + m : m) + '-' + (d < 10 ? '0' + d : d),
      installments: isCredit ? ((i % 10) + 2) : 1,
      currentInstallment: isCredit ? ((i % 5) + 1) : 1,
      card: isCredit ? 'Nubank Ultravioleta' : ''
    });
  }
  localStorage.setItem('ctrlpig_transactions', JSON.stringify(txs));

  // 1) Parse + Filtro mensal + Cálculo de Totais + Gastos por Membro (Ambos/Individual) + Parceladas
  var tCalcStart = Date.now();
  var parsed = JSON.parse(localStorage.getItem('ctrlpig_transactions'));
  var monthFilter = '2026-11';
  var totalIn = 0, totalOut = 0;
  var byCat = {};
  var byMember = { Rodrigo: 0, Esposa: 0, Ambos: 0 };
  var installmentsList = [];
  for (var j = 0; j < parsed.length; j++) {
    var t = parsed[j];
    if (t.date && t.date.indexOf(monthFilter) === 0) {
      if (t.type === 'in') totalIn += t.val;
      else {
        totalOut += t.val;
        byCat[t.cat] = (byCat[t.cat] || 0) + t.val;
        var r = (t.resp === 'Ambos' || t.resp === 'Comum') ? 'Ambos' : (t.resp || 'Rodrigo');
        byMember[r] = (byMember[r] || 0) + t.val;
      }
    }
    if (t.installments && t.installments > 1) {
      installmentsList.push(t);
    }
  }
  // Renderização de cards HTML de parceladas (escapeHtml + template)
  var htmlOut = '';
  for (var k = 0; k < Math.min(installmentsList.length, 200); k++) {
    var it = installmentsList[k];
    var pct = Math.round((it.currentInstallment / it.installments) * 100);
    htmlOut += '<div class="cp-inst-card"><h4>' + escapeHtml(it.desc) + '</h4><span>' + pct + '%</span></div>';
  }
  var calcMs = Date.now() - tCalcStart;

  // 2) Tempo de Auto-Backup e Exportação LGPD (collectUserData) e uso de memória localStorage
  window.currentUserSession = { email: 'casal@controlpig.com.br', nome: 'Rodrigo' };
  window.getUserTransactionsStorageKey = function(){ return 'ctrlpig_transactions'; };
  var tBkpStart = Date.now();
  CPSec.maybeAutoBackup();
  var exported = CPSec.collectUserData();
  var exportedJson = JSON.stringify(exported);
  var bkpMs = Date.now() - tBkpStart;
  var totalBytesUTF16 = localStorage.totalBytes();
  var rawJsonBytes = localStorage.getItem('ctrlpig_transactions').length;
  var bkpSnapshots = JSON.parse(localStorage.getItem('cp_autobackup_v1') || '[]').length;

  return {
    txCount: txCount,
    calcMs: calcMs,
    bkpAndExportMs: bkpMs,
    bkpSnapshots: bkpSnapshots,
    rawJsonKB: Math.round(rawJsonBytes / 1024),
    totalLocalStorageMB: +(totalBytesUTF16 / (1024 * 1024)).toFixed(2),
    installmentsCount: installmentsList.length
  };
}
""")

vol_results = []
for n in [100, 1000, 5000, 10000]:
    r = ctx.call('runVolumeBenchmark', n)
    vol_results.append(r)
    print(
        f"  {r['txCount']:5d} transações ({r['installmentsCount']:4d} parceladas): "
        f"Dashboard+Filtros={r['calcMs']:3d}ms | AutoBackup+ExportLGPD={r['bkpAndExportMs']:3d}ms (snaps={r['bkpSnapshots']}) | "
        f"JSON={r['rawJsonKB']:5d} KB | localStorage UTF-16={r['totalLocalStorageMB']:5.2f} MB"
    )

print('\n=== 3) TESTE DE ESTRESSE DE SEGURANÇA (ATAQUE DE FORÇA BRUTA - 200 TENTATIVAS) ===')
bf = ctx.eval(r"""
(function(){
  __store = {};
  var blockedCount = 0;
  var allowedChecks = 0;
  var t0 = Date.now();
  for (var i = 0; i < 200; i++) {
    var rem = CPSec.lockRemaining('alvo@controlpig.com.br');
    if (rem > 0) {
      blockedCount++;
    } else {
      allowedChecks++;
      CPSec.registerFailure('alvo@controlpig.com.br');
    }
  }
  var elapsedMs = Date.now() - t0;
  return {
    totalAttempts: 200,
    allowedBeforeLock: allowedChecks,
    blockedImmediately: blockedCount,
    elapsedMs: elapsedMs,
    finalLockRemainingSec: CPSec.lockRemaining('alvo@controlpig.com.br')
  };
})()
""")
print(
    f"  200 tentativas de ataque: {bf['allowedBeforeLock']} processadas antes do bloqueio, "
    f"{bf['blockedImmediately']} bloqueadas instantaneamente em {bf['elapsedMs']}ms "
    f"(bloqueio ativo: {bf['finalLockRemainingSec']}s)"
)

sys.stdout.flush()
os._exit(0)
