"""Web deneme sürümü için başlık ve 'Ana Ekrana Ekle' ayarları."""
import json, pathlib, re

NAME = "Son Gün"
web = pathlib.Path("web")
idx = web / "index.html"
h = idx.read_text(encoding="utf-8")
h = re.sub(r"<title>.*?</title>", f"<title>{NAME}</title>", h, flags=re.S)
h = re.sub(r'(name="apple-mobile-web-app-title" content=")[^"]*', r"\g<1>" + NAME, h)
h = re.sub(r'(name="description" content=")[^"]*', r"\g<1>Belge, garanti ve ödeme son tarih hatırlatıcı", h)
idx.write_text(h, encoding="utf-8")

mf = web / "manifest.json"
m = json.loads(mf.read_text(encoding="utf-8"))
m.update({"name": NAME, "short_name": NAME, "lang": "tr",
          "background_color": "#F3F1EC", "theme_color": "#2F5D62",
          "description": "Belge, garanti ve ödeme son tarih hatırlatıcı"})
mf.write_text(json.dumps(m, ensure_ascii=False, indent=2), encoding="utf-8")
print("Web ayarları uygulandı.")
