# Dürt

Belgelerin, garantilerin, kart son ödeme günlerinin ve aboneliklerin son tarihlerini saklayıp zamanında hatırlatan Android uygulaması.

## İlk sürümde olanlar
- Belge, garanti, kart son ödeme, abonelik ve diğer kayıtlar
- Fotoğraftan otomatik okuma (telefonda, internetsiz): tür, son tarih, ekstre tutarı
- Hatırlatma: belgelerde 30, 7, 1 gün kala ve son gün; aylık ödemelerde 3, 1 gün kala ve son gün (saat 10:00)
- Türkiye'ye özel hazır başlıklar (trafik sigortası, kasko, muayene, DASK, MTV...)
- Aylık ve yıllık abonelik toplamı
- Dolandırıcılık SMS kontrolü
- Kart numarası, CVV, şifre asla istenmez; veriler sadece telefonda tutulur

## Derleme
Her `main` gönderiminde GitHub Actions APK derler. **Actions → son çalışma → Artifacts → son-gun-apk** indirilip telefona kurulur.
