# Vakitbil – Yol Haritası

Her ay bir güncelleme hedefi. Sıra ihtiyaca göre değişebilir; yeni fikirler en alttaki "Fikir kutusu"na eklenir.

## Yayında
- Belge, garanti, kart son ödeme, abonelik kayıtları
- Fotoğraftan otomatik okuma (telefonda, internetsiz)
- 30 / 7 / 1 gün kala ve son gün hatırlatmaları
- Ödemeler ekranı: aylık ve yıllık toplam
- Dolandırıcılık SMS kontrolü
- Yeni tasarım, açık / koyu tema

## Ay 1 – Akıllı ve güvenli
- **Türkiye takvimi:** araç model yılından muayene tarihleri; MTV (Ocak/Temmuz), emlak vergisi (Mayıs/Kasım), kış lastiği dönemi otomatik
- **Tek tıkla yenileme:** TÜVTÜRK randevu, MTV ödeme, pasaport randevu bağlantıları
- **Uygulama kilidi:** Face ID / parmak izi / PIN
- **Yedekleme:** kayıtları dosyaya al, yeni telefona geri yükle

## Ay 2 – Mağazaya çıkış
- Google Play yayını (küçültülmüş paket, imza anahtarı, gizlilik politikası, KVKK metni)
- Apple Developer hesabı + TestFlight + App Store yayını
- Ana ekran bileşeni (widget): "Trafik sigortası: 4 gün"
- Takvime ekle (Google / Apple takvimi)

## Ay 3 – Gelir
- Ücretlendirme: **1 ay ücretsiz deneme, sonra ücretli** (ücretsiz sürüm yok)
  - Aylık ₺49,99 · Yıllık ₺399 · Aile ₺599/yıl (örnek fiyatlar)
  - Deneme bitince: kayıtlar silinmez, görüntülenebilir ve dışa aktarılabilir; yeni kayıt ve hatırlatmalar abonelikle
  - Sahte SMS kontrolü herkese ücretsiz kalır (tanıtım ve yayılma için)
  - RevenueCat ile mağaza abonelikleri ve gelir paneli
- Sigorta yenileme için "Teklif al" ortaklığı (komisyon)
- Garanti başvuru paketi: belge + fatura tek PDF, marka servis numaraları

## Ay 4 – Aile
- Aile kasası (sunucu: Firebase) – eşler ve ebeveynler ortak kayıtlar
- İlaç hatırlatma ve "ilacını aldı mı" bildirimi
- Firebase güvenlik kuralları, App Check

## Ay 5 – Para takibi
- Market fişi tarama, aylık harcama özeti, kişisel fiyat geçmişi
- Aile alışveriş listesi
- Abonelik iptal rehberleri (Netflix, Exxen, BluTV, spor salonu...)

## Ay 6 – Esnaf paketi
- Çek / senet vadeleri, verilen ve alınacak ödemeler
- Aylık nakit akışı özeti

## Fikir kutusu
- Yapay zekâya sor: "Muayenem ne zaman?", "Bu ay ne kadar ödeyeceğim?" (Premium)
- Buzdolabı son kullanma tarihleri
- Deprem çantası son kullanma takibi
- Topluluk market fiyatları (fişlerden)
- Filo / şirket araçları sürümü (araç başına aylık ücret)


## 5 Kasım 2026: 1.0 hazırlığında tamamlananlar
- Hoş geldin ekranları, 30 gün kartsız deneme, abonelik ekranı (RevenueCat kodu hazır, anahtar bekleniyor)
- Çek / senet / kredi taksiti türü, bildirim saati ayarı, arama
- Abonelik iptal rehberi (Netflix, Spotify, YouTube, Disney+, Prime, iCloud, operatörler…)
- Yedek dosyası (iCloud Drive / Google Drive / WhatsApp) ve dosyadan geri yükleme
- Telefonun takvimine ekleme
- Uygulama simgesi, mağaza görselleri ve metinleri, gizlilik / KVKK / şartlar sayfaları
- Google Play paketi (AAB), iPhone derlemesi kontrolü

## Hesaplar açılınca (sırayla)
1. Google Play + Apple geliştirici hesapları (dükkân adına, D-U-N-S ile)
2. Yükleme imza anahtarı → GitHub Secrets (ANDROID_KEYSTORE_BASE64, ANDROID_KEY_PASSWORD)
3. RevenueCat: ürünler `vakitbil_aylik`, `vakitbil_yillik`, yetki `premium` → anahtarlar GitHub Secrets (RC_ANDROID_KEY, RC_IOS_KEY)
4. iPhone: Codemagic ya da GitHub Actions ile imzalı derleme → TestFlight
5. Kapalı test → yayın
6. Firebase: Apple/Google ile giriş + şifreli bulut yedeği, Crashlytics, aile kasası
