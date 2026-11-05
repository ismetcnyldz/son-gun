"""Web deneme sürümü için başlık ve 'Ana Ekrana Ekle' ayarları."""
import json, pathlib, re

NAME = "Dürt"
web = pathlib.Path("web")
idx = web / "index.html"
h = idx.read_text(encoding="utf-8")
h = re.sub(r"<title>.*?</title>", f"<title>{NAME}</title>", h, flags=re.S)
h = re.sub(r'(name="apple-mobile-web-app-title" content=")[^"]*', r"\g<1>" + NAME, h)
h = re.sub(r'(name="description" content=")[^"]*', r"\g<1>Belge, garanti ve ödeme son tarih hatırlatıcı", h)
DIAG = """
<div id="sg-diag" style="position:fixed;inset:0;z-index:99999;background:#F3F1EC;color:#22262B;font:15px -apple-system,Segoe UI,sans-serif;padding:24px;overflow:auto">Dürt yükleniyor…</div>
<script>
window.__sgErr=[];
window.addEventListener('error',function(e){__sgErr.push((e.message||'hata')+' @'+String(e.filename||'').split('/').pop()+':'+e.lineno)});
window.addEventListener('unhandledrejection',function(e){var r=e.reason;__sgErr.push('promise: '+(r&&(r.message||r)))});
(function(){var t0=Date.now();var iv=setInterval(function(){var d=document.getElementById('sg-diag');if(!d){clearInterval(iv);return}
var gp=document.querySelector('flt-glass-pane');var sr=gp&&gp.shadowRoot;
if(sr&&sr.querySelector('canvas, flt-canvas, img, flt-picture')){d.remove();clearInterval(iv);return}
if(Date.now()-t0>15000){clearInterval(iv);var gl=false;try{var c=document.createElement('canvas');gl=!!(c.getContext('webgl2')||c.getContext('webgl'))}catch(x){}
d.innerHTML='<b style="font-size:18px">Uygulama açılamadı</b><br><br>Bu ekranın görüntüsünü gönder.<br><br>WebGL: '+gl+'<br>WebAssembly: '+(typeof WebAssembly)+'<br>Tarayıcı: '+navigator.userAgent+'<br><br>Hatalar:<br>'+(__sgErr.length?__sgErr.slice(0,6).join('<br>'):'yok')}},500)})();
</script>
"""
if "sg-diag" not in h:
    h = h.replace("<body>", "<body>" + DIAG, 1)
idx.write_text(h, encoding="utf-8")

mf = web / "manifest.json"
m = json.loads(mf.read_text(encoding="utf-8"))
m.update({"name": NAME, "short_name": NAME, "lang": "tr",
          "background_color": "#F3F1EC", "theme_color": "#2F5D62",
          "description": "Belge, garanti ve ödeme son tarih hatırlatıcı"})
mf.write_text(json.dumps(m, ensure_ascii=False, indent=2), encoding="utf-8")
print("Web ayarları uygulandı.")
