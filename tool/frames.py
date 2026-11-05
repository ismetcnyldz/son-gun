# Ekran görüntülerinden mağaza vitrin görselleri: başlık + telefon çerçevesi.
import sys, os, base64
from playwright.sync_api import sync_playwright

SHOTS = sys.argv[1]; OUT = sys.argv[2]
FRAMES = [
  ('light-home',     'light', 'SON GÜN',            'Son günü sen unut,<br>telefonun unutmasın.'),
  ('dark-editor',    'teal',  'FOTOĞRAFTAN OKUMA',  'Fotoğrafını çek,<br>tarihi biz okuyalım.'),
  ('light-payments', 'light', 'KART VE ABONELİK',   'Bütün ödemelerin<br>tek bakışta.'),
  ('dark-sms',       'teal',  'SMS KONTROLÜ',       'Sahte mesajı<br>tıklamadan yakala.'),
  ('light-turkey',   'light', 'TÜRKİYE TAKVİMİ',    'Muayene ve vergi<br>tarihleri hazır.'),
  ('dark-home',      'teal',  'KOYU TEMA',          'Gece de gündüz de<br>göz yormaz.'),
]
FONTS = '<link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,700&family=Manrope:wght@600;800&display=block" rel="stylesheet">'

def img(name):
  with open(f'{SHOTS}/{name}.png', 'rb') as f: return 'data:image/png;base64,' + base64.b64encode(f.read()).decode()

def page_html(shot, bg, eyebrow, title, W, H, phone_w, title_px):
  bgcss = '#F3F1EC' if bg == 'light' else 'linear-gradient(160deg,#2F5D62 0%,#1C3B3F 100%)'
  ink = '#22262B' if bg == 'light' else '#FFFFFF'
  acc = '#2F5D62' if bg == 'light' else '#9FD3CF'
  bez = round(phone_w * 0.028); rad = round(phone_w * 0.12)
  return f'''<!doctype html><html><head><meta charset="utf-8">{FONTS}<style>
  *{{margin:0;padding:0;box-sizing:border-box}}
  body{{width:{W}px;height:{H}px;overflow:hidden;background:{bgcss};font-family:Manrope,sans-serif;display:flex;flex-direction:column;align-items:center}}
  .cap{{text-align:center;padding:{round(H*0.055)}px {round(W*0.07)}px {round(H*0.035)}px}}
  .eb{{color:{acc};font-weight:800;letter-spacing:.14em;font-size:{round(title_px*0.36)}px;margin-bottom:{round(title_px*0.35)}px}}
  h1{{font-family:Fraunces,serif;font-weight:700;color:{ink};font-size:{title_px}px;line-height:1.08;letter-spacing:-.01em}}
  .ph{{width:{phone_w}px;border-radius:{rad}px;background:#0E1012;padding:{bez}px;box-shadow:0 {bez*2}px {bez*6}px rgba(0,0,0,.28)}}
  .ph img{{display:block;width:100%;border-radius:{rad-bez}px}}
  </style></head><body><div class="cap"><div class="eb">{eyebrow}</div><h1>{title}</h1></div>
  <div class="ph"><img src="{img(shot)}"></div></body></html>'''

def feature_html():
  return f'''<!doctype html><html><head><meta charset="utf-8">{FONTS}<style>
  *{{margin:0;padding:0;box-sizing:border-box}}
  body{{width:1024px;height:500px;overflow:hidden;background:linear-gradient(135deg,#2F5D62,#1C3B3F);font-family:Manrope,sans-serif;position:relative}}
  .t{{position:absolute;left:64px;top:118px;width:560px;color:#fff}}
  .eb{{color:#9FD3CF;font-weight:800;letter-spacing:.14em;font-size:20px;margin-bottom:14px}}
  h1{{font-family:Fraunces,serif;font-size:76px;line-height:1}}
  p{{margin-top:18px;font-size:26px;font-weight:600;opacity:.85;line-height:1.3}}
  .ph{{position:absolute;right:70px;top:60px;width:300px;border-radius:40px;background:#0E1012;padding:9px;transform:rotate(4deg);box-shadow:0 20px 60px rgba(0,0,0,.4)}}
  .ph img{{display:block;width:100%;border-radius:32px}}
  </style></head><body><div class="t"><div class="eb">BELGE · GARANTİ · ÖDEME</div><h1>Son Gün</h1>
  <p>Son günü sen unut,<br>telefonun unutmasın.</p></div><div class="ph"><img src="{img('light-home')}"></div></body></html>'''

os.makedirs(f'{OUT}/ios', exist_ok=True); os.makedirs(f'{OUT}/play', exist_ok=True)
with sync_playwright() as pw:
  b = pw.chromium.launch()
  def render(html, W, H, path):
    pg = b.new_page(viewport={'width': W, 'height': H})
    pg.set_content(html, wait_until='networkidle'); pg.wait_for_timeout(800)
    pg.screenshot(path=path); pg.close(); print('frame', path)
  for i, (shot, bg, eb, t) in enumerate(FRAMES, 1):
    if not os.path.exists(f'{SHOTS}/{shot}.png'): print('missing', shot); continue
    render(page_html(shot, bg, eb, t, 1290, 2796, 1000, 108), 1290, 2796, f'{OUT}/ios/{i:02d}-{shot}.png')
    render(page_html(shot, bg, eb, t, 1080, 1920, 640, 76), 1080, 1920, f'{OUT}/play/{i:02d}-{shot}.png')
  render(feature_html(), 1024, 500, f'{OUT}/play/feature-graphic.png')
  b.close()
