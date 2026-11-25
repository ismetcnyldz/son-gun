# Ekran görüntülerinden mağaza vitrin görselleri: başlık + telefon çerçevesi.
import sys, os, base64
from playwright.sync_api import sync_playwright

SHOTS = sys.argv[1]; OUT = sys.argv[2]
FRAMES = [
  ('light-home',     'light', 'VAKİTBİL',           'Son günü sen unut,<br>Vakitbil hatırlatır.'),
  ('dark-editor',    'teal',  'FOTOĞRAFTAN OKUMA',  'Fotoğrafını çek,<br>tarihi biz okuyalım.'),
  ('light-payments', 'light', 'KART VE ABONELİK',   'Bütün ödemelerin<br>tek bakışta.'),
  ('dark-sms',       'teal',  'SMS KONTROLÜ',       'Sahte mesajı<br>tıklamadan yakala.'),
  ('light-turkey',   'light', 'TÜRKİYE TAKVİMİ',    'Muayene ve vergi<br>tarihleri hazır.'),
  ('dark-home',      'teal',  'KOYU TEMA',          'Gece de gündüz de<br>göz yormaz.'),
]
FONTS = '<link href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,800&family=Manrope:wght@600;800&display=block" rel="stylesheet">'
ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'art')

def data(path, mime):
  with open(path, 'rb') as f: return f'data:{mime};base64,' + base64.b64encode(f.read()).decode()

def img(name): return data(f'{SHOTS}/{name}.png', 'image/png')

def phone_css(phone_w):
  bez = round(phone_w * 0.03); rad = round(phone_w * 0.13)
  return f'''.ph{{position:relative;width:{phone_w}px;border-radius:{rad}px;padding:{bez}px;
    background:linear-gradient(140deg,#5a6b71 0%,#1c2a2e 14%,#0b1215 60%,#2a383c 100%);
    box-shadow:inset 0 0 0 2px rgba(255,255,255,.2),inset 0 0 0 {round(bez*.35)}px #04080a,0 {bez*3}px {bez*8}px rgba(8,30,36,.45),0 {bez}px {bez*2}px rgba(8,30,36,.25)}}
  .ph img{{display:block;width:100%;border-radius:{rad-bez}px}}
  .ph::after{{content:"";position:absolute;inset:{bez}px;border-radius:{rad-bez}px;background:linear-gradient(115deg,rgba(255,255,255,.22),rgba(255,255,255,0) 30%)}}'''

def page_html(shot, bg, eyebrow, title, W, H, phone_w, title_px):
  return f'''<!doctype html><html><head><meta charset="utf-8">{FONTS}<style>
  *{{margin:0;padding:0;box-sizing:border-box}}
  body{{width:{W}px;height:{H}px;overflow:hidden;background:url({data(ART+'/store_bg.jpg','image/jpeg')}) center/cover;font-family:Manrope,sans-serif;display:flex;flex-direction:column;align-items:center}}
  body::before{{content:"";position:absolute;inset:0 0 auto;height:{round(H*0.30)}px;background:linear-gradient(#FBF6EA 0%,rgba(251,246,234,.92) 62%,rgba(251,246,234,0) 100%)}}
  .cap,.ph{{z-index:1}}
  .cap{{position:relative;text-align:center;padding:{round(H*0.055)}px {round(W*0.07)}px {round(H*0.035)}px}}
  .eb{{color:#E2553A;font-weight:800;letter-spacing:.08em;font-size:{round(title_px*0.34)}px;margin-bottom:{round(title_px*0.3)}px}}
  h1{{font-family:'Bricolage Grotesque',sans-serif;font-weight:800;color:#0F2430;font-size:{title_px}px;line-height:1.04;letter-spacing:-.025em}}
  {phone_css(phone_w)}
  </style></head><body><div class="cap"><div class="eb">{eyebrow}</div><h1>{title}</h1></div>
  <div class="ph"><img src="{img(shot)}"></div></body></html>'''

def feature_html():
  return f'''<!doctype html><html><head><meta charset="utf-8">{FONTS}<style>
  *{{margin:0;padding:0;box-sizing:border-box}}
  body{{width:1024px;height:500px;overflow:hidden;background:url({data(ART+'/feature_bg@2x.jpg','image/jpeg')}) center/cover;font-family:Manrope,sans-serif;position:relative}}
  .t{{position:absolute;left:64px;top:96px;width:520px;color:#fff}}
  .ic{{width:96px;height:96px;border-radius:24px;box-shadow:0 14px 30px rgba(0,0,0,.35);margin-bottom:22px;display:block}}
  h1{{font-family:'Bricolage Grotesque',sans-serif;font-weight:800;font-size:72px;line-height:1;letter-spacing:-.03em}}
  h1 span{{color:#FF8A70}}
  p{{margin-top:14px;font-size:26px;font-weight:600;opacity:.9;line-height:1.3}}
  </style></head><body><div class="t"><img class="ic" src="{data(os.path.join(ART,'..','..','assets','icon','icon.png'),'image/png')}">
  <h1>Vakit<span>bil</span></h1><p>Son günü sen unut,<br>Vakitbil hatırlatır.</p></div></body></html>'''

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
