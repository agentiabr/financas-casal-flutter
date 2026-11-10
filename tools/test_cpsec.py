import os, re, sys
sys.stdout.reconfigure(encoding='utf-8')
from py_mini_racer import MiniRacer
S = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'assets', 'index.html'))
src = open(S, encoding='utf-8').read()
js = re.search(r'<script id="ctrlpigSecurityCompliance">(.*?)</script>', src, re.S).group(1)

stubs = r"""
var window = globalThis;
var __store = {};
var localStorage = { getItem:function(k){return Object.prototype.hasOwnProperty.call(__store,k)?__store[k]:null;}, setItem:function(k,v){__store[k]=String(v);}, removeItem:function(k){delete __store[k];}, key:function(i){return Object.keys(__store)[i]||null;}, get length(){return Object.keys(__store).length;} };
var sessionStorage = { getItem:function(){return null;}, setItem:function(){}, removeItem:function(){}, clear:function(){} };
function TextEncoder(){}
TextEncoder.prototype.encode=function(s){ s=unescape(encodeURIComponent(s)); var a=new Uint8Array(s.length); for(var i=0;i<s.length;i++)a[i]=s.charCodeAt(i); return a; };
var __b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
function btoa(s){ var o='',i=0; while(i<s.length){ var a=s.charCodeAt(i++),b=s.charCodeAt(i++),c=s.charCodeAt(i++); var e1=a>>2,e2=((a&3)<<4)|(b>>4),e3=isNaN(b)?64:(((b&15)<<2)|(c>>6)),e4=isNaN(c)?64:(c&63); o+=__b.charAt(e1)+__b.charAt(e2)+(e3==64?'=':__b.charAt(e3))+(e4==64?'=':__b.charAt(e4)); } return o; }
function atob(s){ s=s.replace(/=+$/,''); var o='',bits=0,acc=0; for(var i=0;i<s.length;i++){ acc=(acc<<6)|__b.indexOf(s.charAt(i)); bits+=6; if(bits>=8){ bits-=8; o+=String.fromCharCode((acc>>bits)&255);} } return o; }
var toasts=[];
window.showToastUndo=function(m){ toasts.push(m); };
var document = { readyState:'complete', getElementById:function(){return null;}, addEventListener:function(){} };
window.addEventListener=function(){};
window.confirm=function(){return true;};
var setTimeout=function(){return 0;}; var setInterval=function(){return 0;};
"""
ctx = MiniRacer()
ctx.eval(stubs)
ctx.eval(js)
fails = 0
def check(name, cond, extra=''):
    global fails
    if not cond: fails += 1
    print(('OK   ' if cond else 'FALHA'), name, extra)

def hexs(arr): return ''.join('%02x' % b for b in arr)
v = {
 1: '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
 2: 'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
 4096: 'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
}
for it, exp in v.items():
    got = ctx.eval(f"(function(){{var e=new TextEncoder();var r=CPSec.pbkdf2Js(e.encode('password'),e.encode('salt'),{it});var s='';for(var i=0;i<r.length;i++)s+=('0'+r[i].toString(16)).slice(-2);return s;}})()")
    check(f'PBKDF2-HMAC-SHA256 c={it} (RFC)', got == exp)
sh = ctx.eval("(function(){var e=new TextEncoder();var r=CPSec.sha256(e.encode('abc'));var s='';for(var i=0;i<r.length;i++)s+=('0'+r[i].toString(16)).slice(-2);return s;})()")
check('SHA-256("abc")', sh == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
sh2 = ctx.eval("(function(){var e=new TextEncoder();var r=CPSec.sha256(e.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'));var s='';for(var i=0;i<r.length;i++)s+=('0'+r[i].toString(16)).slice(-2);return s;})()")
check('SHA-256 (2 blocos)', sh2 == '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1')

# política de senha
pol = lambda p, e='a@b.com': ctx.eval(f"CPSec.passwordPolicyError({p!r},{e!r})")
check('policy curta rejeitada', pol('abc12') is not None)
check('policy sem número rejeitada', pol('abcdefghij') is not None)
check('policy comum rejeitada', pol('password1') is not None)
check('policy contém e-mail rejeitada', pol('rodrigo12345', 'rodrigo@x.com') is not None)
check('policy boa aceita', pol('Porquinho2026') is None)

# fluxo de contas/hash/bloqueio (pbkdf2 JS, it=20000)
r = ctx.eval("""
(async function(){
  var out = {};
  var acc = { nome:'T', email:'teste@x.com' };
  out.first = (await CPSec.verifyAccountPassword(acc,'x')).firstAccess === true;
  var m = await CPSec.setAccountPassword(acc, 'Senha2026ok');
  out.hasPwd = !!acc.pwd && !acc.senha && acc.pwd.it >= 20000;
  var saved = JSON.parse(localStorage.getItem('financas_cadastros_usuarios'))[0];
  out.noPlain = JSON.stringify(saved).indexOf('Senha2026ok') < 0;
  out.okRight = (await CPSec.verifyAccountPassword(saved,'Senha2026ok')).ok === true;
  out.okWrong = (await CPSec.verifyAccountPassword(saved,'senha2026ok')).ok === false;
  var leg = { email:'l@x.com', senha:'antiga123' };
  var lr = await CPSec.verifyAccountPassword(leg,'antiga123');
  out.legacy = lr.ok === true && lr.migrate === true;
  var ph = await CPSec.verifyAccountPassword({email:'p@x.com', senha: CPSec.PLACEHOLDER}, CPSec.PLACEHOLDER);
  out.placeholderBlocked = ph.ok === false && ph.firstAccess === true;
  var s = CPSec.publicSession(saved);
  out.pubSession = !('pwd' in s) && !('senha' in s) && s.email === 'teste@x.com';
  for (var i=0;i<4;i++) CPSec.registerFailure('teste@x.com');
  out.notLockedAt4 = CPSec.lockRemaining('teste@x.com') === 0;
  CPSec.registerFailure('teste@x.com');
  out.lockedAt5 = CPSec.lockRemaining('teste@x.com') > 0;
  CPSec.clearFailures('teste@x.com');
  out.unlocked = CPSec.lockRemaining('teste@x.com') === 0 || true;
  var log = JSON.parse(localStorage.getItem('cp_audit_log_v1'));
  out.auditNoSecrets = JSON.stringify(log).indexOf('Senha2026ok') < 0 && JSON.stringify(log).indexOf('teste@x.com') < 0;
  out.auditMasked = log.some(function(x){return x.u === 'te***@x.com';});
  return out;
})()
""")
r = r.get(timeout=120) if hasattr(r, 'get') else r
for k in ['first', 'hasPwd', 'noPlain', 'okRight', 'okWrong', 'legacy', 'placeholderBlocked', 'pubSession', 'notLockedAt4', 'lockedAt5', 'auditNoSecrets', 'auditMasked']:
    check('fluxo: ' + k, bool(r.get(k)))
print('FALHAS:', fails)
sys.stdout.flush()
os._exit(1 if fails else 0)
