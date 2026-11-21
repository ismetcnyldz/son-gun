# Vakitbil: Kaldığımız yer (21 Kasım 2026)

Bu dosya, çalışmaya ara verildiğinde nereden devam edileceğini anlatır.

## Nerede ne var
- **Kod:** github.com/ismetcnyldz/son-gun (main dalı)
- **Derleme:** GitHub Actions, "Derleme (Android + Web)". Her gönderimde Android APK + AAB, iPhone (imzasız kontrol) ve web sürümü derlenir; testler çalışır.
- **Deneme APK / AAB:** GitHub Releases, "deneme" (Vakitbil.apk, Vakitbil.aab)
- **Site:** vakitbil.com (GitHub Pages, gh-pages dalı). Tanıtım: site/tanitim, yasal sayfalar: site/yasal, web sürümü: /uygulama
- **Alan adları:** Cloudflare (kenzcn0@gmail.com). vakitbil.com (asıl), durt.app (kullanılmıyor, yenilenmeyebilir)
- **E-posta:** destek@vakitbil.com → kenzcn0@gmail.com (Cloudflare Email Routing)
- **Mağaza metinleri:** docs/MAGAZA_METINLERI.md. Görseller her derlemede site/store altında üretilir.
- **Yol haritası:** YOL_HARITASI.md

## Bitenler
Uygulama (belge, garanti, kart, abonelik, çek/senet takibi; fotoğraftan tarih okuma; hatırlatmalar; şifreli yedek; uygulama kilidi; koyu/açık tema; 30 gün deneme ekranı; ödeme altyapısı kodu), isim kontrolü (marka, alan adı, mağazalar), site, e-posta, mağaza görselleri ve metinleri.

## Sıradaki adımlar
1. **Vergi:** Muhasebeciye sor: "Mobil uygulama gelirim için GVK mükerrer 20/B istisnasından yararlanabilir miyim? KDV yükümlülüğüm olur mu?"
   Plan: Her şey İsmet'in adına; istisna belgesi + 20/B için tanımlı kişisel banka hesabı.
2. **Google Play hesabı (25$)** İsmet adına, kişisel hesap. Kimlik, telefon, Android cihaz doğrulaması.
3. **Yasal sayfalar:** site/yasal içindeki [ŞİRKET TİCARİ UNVANI], [ADRES], [İL] alanlarını hesap sahibinin bilgileriyle doldur.
4. **İmza anahtarı:** Yükleme anahtarı oluştur, GitHub Secrets'a ekle (ANDROID_KEYSTORE_BASE64, ANDROID_KEY_PASSWORD).
5. **Kapalı test:** 14-15 test kullanıcısı, 14 gün.
6. **Abonelikler:** Play Console'da vakitbil_aylik (₺49,99) ve vakitbil_yillik (₺399); RevenueCat anahtarı: GitHub Secrets RC_ANDROID_KEY, yetki adı "premium".
7. **Yayın başvurusu** ve sitedeki mağaza düğmelerine gerçek bağlantılar.
8. Sonra: Apple hesabı (99$/yıl) ve iPhone sürümü; kodu gizliye almak için siteyi Cloudflare Pages'e taşımak.
