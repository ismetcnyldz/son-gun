# Mağaza ekran görüntüleri: web sürümünü telefon boyutunda açıp örnek verilerle çeker.
import json, sys, datetime as dt
from playwright.sync_api import sync_playwright

BASE = sys.argv[1] if len(sys.argv) > 1 else 'http://localhost:8080/son-gun/'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'shots'
today = dt.date.today()
def d(n): return (today + dt.timedelta(days=n)).isoformat() + 'T00:00:00.000'
def day(n): return (today + dt.timedelta(days=n)).day

items = [
  dict(id='1', kind='kart', title='Kredi kartı', note='Garanti BBVA · 4821', day=day(3), amount=12480.0),
  dict(id='2', kind='belge', title='Trafik sigortası', note='34 ABC 123', date=d(4)),
  dict(id='3', kind='belge', title='Araç muayenesi', note='34 ABC 123', date=d(18)),
  dict(id='4', kind='abonelik', title='Netflix', note='', day=day(9), amount=229.99),
  dict(id='5', kind='abonelik', title='Ev interneti', note='', day=day(12), amount=449.0),
  dict(id='6', kind='abonelik', title='Spotify', note='', day=day(21), amount=99.0),
  dict(id='7', kind='garanti', title='Telefon garantisi', note='iPhone 15', date=d(46)),
  dict(id='8', kind='belge', title='DASK (zorunlu deprem sigortası)', note='Ev', date=d(63)),
  dict(id='9', kind='belge', title='Pasaport', note='Ayşe', date=d(72)),
  dict(id='10', kind='garanti', title='Beyaz eşya garantisi', note='Bulaşık makinesi', date=d(240)),
]
for it in items:
  it.setdefault('date', None); it.setdefault('day', None); it.setdefault('amount', None); it['photo'] = None

def prefs(theme, onboarded=True):
  v = {
    'flutter.items_v1': json.dumps(json.dumps(items, ensure_ascii=False), ensure_ascii=False),
    'flutter.onboarded': 'true' if onboarded else 'false',
    'flutter.trial_start': json.dumps((dt.datetime.now() - dt.timedelta(days=3)).isoformat()),
    'flutter.theme_mode': json.dumps(theme),
  }
  if not onboarded:
    v = {'flutter.theme_mode': json.dumps(theme)}
  return v

def open_app(browser, theme, onboarded=True):
  ctx = browser.new_context(viewport={'width': 430, 'height': 932}, device_scale_factor=3, locale='tr-TR')
  ctx.add_init_script('const v=%s; if(!sessionStorage.getItem("seeded")){localStorage.clear(); for (const k in v) localStorage.setItem(k, v[k]); sessionStorage.setItem("seeded","1");}' % json.dumps(prefs(theme, onboarded)))
  page = ctx.new_page()
  page.goto(BASE)
  page.wait_for_selector('flt-glass-pane', timeout=60000)
  page.wait_for_timeout(5000)
  # erişilebilirlik ağacını aç: öğelere yazıyla tıklayabilmek için
  page.evaluate("() => { const p = document.querySelector('flt-semantics-placeholder'); if (p) p.click(); }")
  page.wait_for_timeout(800)
  return ctx, page

def tap(page, text):
  try:
    page.get_by_text(text, exact=False).first.click(timeout=4000)
  except Exception:
    page.get_by_role('button', name=text).first.click(timeout=4000)
  page.wait_for_timeout(1200)

def shot(page, name):
  page.wait_for_timeout(700)
  page.screenshot(path=f'{OUT}/{name}.png')
  print('ok', name)

import os; os.makedirs(OUT, exist_ok=True)
with sync_playwright() as pw:
  b = pw.chromium.launch(args=['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'])
  for theme in ['light', 'dark']:
    ctx, page = open_app(b, theme, onboarded=False)
    shot(page, f'{theme}-onb1')
    for i in (2, 3):
      try: tap(page, 'Devam'); shot(page, f'{theme}-onb{i}')
      except Exception as e: print('fail onb', e)
    ctx.close()

    ctx, page = open_app(b, theme)
    shot(page, f'{theme}-home')
    page.mouse.wheel(0, 700); page.wait_for_timeout(800); shot(page, f'{theme}-home2')
    page.mouse.wheel(0, -2000); page.wait_for_timeout(500)
    steps = [('Ödemeler', 'payments'), ('SMS', 'sms'), ('Ana sayfa', None), ('Ekle', 'editor')]
    for t, n in steps:
      try:
        tap(page, t)
        if n: shot(page, f'{theme}-{n}')
      except Exception as e: print('fail', t, e)
    try:
      page.go_back(); page.wait_for_timeout(800)
    except Exception: pass
    ctx.close()

    ctx, page = open_app(b, theme)
    for t, n in [('Ücretsiz deneme', 'paywall')]:
      try: tap(page, t); shot(page, f'{theme}-{n}')
      except Exception as e: print('fail', t, e)
    ctx.close()
    ctx, page = open_app(b, theme)
    try:
      tap(page, 'Ayarlar'); shot(page, f'{theme}-settings')
      tap(page, 'Türkiye takvimi'); shot(page, f'{theme}-turkey')
    except Exception as e: print('fail settings', e)
    ctx.close()
  b.close()
