"""flutter create ile üretilen iOS dosyalarına izin açıklamalarını ve ayarları ekler."""
import pathlib, re

APP_LABEL = "Vakitbil"
plist = pathlib.Path("ios/Runner/Info.plist")
p = plist.read_text(encoding="utf-8")

keys = {
    "NSCameraUsageDescription": "Belgenin fotoğrafını çekip son tarihi okumak için kamerayı kullanır.",
    "NSPhotoLibraryUsageDescription": "Galerindeki belge fotoğrafından son tarihi okumak için kullanılır.",
    "NSFaceIDUsageDescription": "Uygulamayı Face ID ile kilitlemek için kullanılır.",
    "NSCalendarsUsageDescription": "Son tarihleri takvimine eklemek için kullanılır.",
    "NSCalendarsFullAccessUsageDescription": "Son tarihleri takvimine eklemek için kullanılır.",
    "NSCalendarsWriteOnlyAccessUsageDescription": "Son tarihleri takvimine eklemek için kullanılır.",
    "NSContactsUsageDescription": "Takvim etkinliği eklerken iOS bu izni isteyebilir; kişilerin okunmaz.",
}
add = ""
for k, v in keys.items():
    if k not in p:
        add += f"\t<key>{k}</key>\n\t<string>{v}</string>\n"
# Yedek dosyalarını Dosyalar uygulamasında açabilmek için
if "UISupportsDocumentBrowser" not in p:
    add += "\t<key>LSSupportsOpeningDocumentsInPlace</key>\n\t<true/>\n\t<key>UIFileSharingEnabled</key>\n\t<true/>\n"
p = p.replace("</dict>\n</plist>", add + "</dict>\n</plist>")
p = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", rf"\g<1>{APP_LABEL}\g<2>", p)
plist.write_text(p, encoding="utf-8")

# En düşük iOS sürümü (ML Kit 15.5 ister)
pod = pathlib.Path("ios/Podfile")
if pod.exists():
    t = pod.read_text(encoding="utf-8")
    t = re.sub(r"#\s*platform :ios, '[\d.]+'", "platform :ios, '15.5'", t)
    pod.write_text(t, encoding="utf-8")
proj = pathlib.Path("ios/Runner.xcodeproj/project.pbxproj")
if proj.exists():
    t = proj.read_text(encoding="utf-8")
    t = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 15.5;", t)
    t = re.sub(r"PRODUCT_BUNDLE_IDENTIFIER = com\.yildiz\.sonGun(\.RunnerTests)?;", lambda m: f"PRODUCT_BUNDLE_IDENTIFIER = com.yildiz.vakitbil{m.group(1) or ''};", t)
    proj.write_text(t, encoding="utf-8")
print("iOS ayarları uygulandı.")
