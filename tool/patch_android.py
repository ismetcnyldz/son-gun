"""flutter create ile üretilen Android dosyalarına gerekli ayarları ekler.
Bildirimler için: core library desugaring, izinler ve zamanlanmış bildirim alıcıları.
Tekrar çalıştırılsa da sorun çıkarmaz."""
import pathlib, re, sys

APP_LABEL = "Son Gün"
root = pathlib.Path("android/app")

# --- build.gradle(.kts) ---
kts = root / "build.gradle.kts"
groovy = root / "build.gradle"
if kts.exists():
    g = kts.read_text(encoding="utf-8")
    if "isCoreLibraryDesugaringEnabled" not in g:
        g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", g, count=1)
    g = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 23", g)
    if "desugar_jdk_libs" not in g:
        g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    kts.write_text(g, encoding="utf-8")
elif groovy.exists():
    g = groovy.read_text(encoding="utf-8")
    if "coreLibraryDesugaringEnabled" not in g:
        g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        coreLibraryDesugaringEnabled true", g, count=1)
    g = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdkVersion 23", g)
    if "desugar_jdk_libs" not in g:
        g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    groovy.write_text(g, encoding="utf-8")
else:
    sys.exit("android/app/build.gradle bulunamadı")

# --- R8 (küçültme) kuralları: ML Kit'in kullanmadığımız dil modülleri ---
(root / "proguard-rules.pro").write_text(
    "-dontwarn com.google.mlkit.vision.text.chinese.**\n"
    "-dontwarn com.google.mlkit.vision.text.devanagari.**\n"
    "-dontwarn com.google.mlkit.vision.text.japanese.**\n"
    "-dontwarn com.google.mlkit.vision.text.korean.**\n"
    "-keep class com.dexterous.** { *; }\n",
    encoding="utf-8",
)
if kts.exists():
    g = kts.read_text(encoding="utf-8")
    if "proguard-rules.pro" not in g:
        g = re.sub(r"(buildTypes\s*\{\s*release\s*\{)",
                   r'\1\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")',
                   g, count=1)
        kts.write_text(g, encoding="utf-8")
elif groovy.exists():
    g = groovy.read_text(encoding="utf-8")
    if "proguard-rules.pro" not in g:
        g = re.sub(r"(buildTypes\s*\{\s*release\s*\{)",
                   r"\1\n            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'",
                   g, count=1)
        groovy.write_text(g, encoding="utf-8")

# --- Yayın imzası (key.properties varsa) ---
if kts.exists():
    g = kts.read_text(encoding="utf-8")
    if "keystoreProperties" not in g:
        g = "import java.util.Properties\nimport java.io.FileInputStream\n\n" + g
        g = g.replace("android {", """val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) keystoreProperties.load(FileInputStream(keystorePropertiesFile))

android {
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }""", 1)
        g = g.replace('signingConfig = signingConfigs.getByName("debug")',
                      'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")')
        kts.write_text(g, encoding="utf-8")

# --- Bildirim simgesi (tek renk) ---
import shutil
drw = root / "src/main/res/drawable"
drw.mkdir(parents=True, exist_ok=True)
shutil.copy("assets/icon/notify.png", drw / "ic_stat_notify.png")
raw = root / "src/main/res/raw"
raw.mkdir(parents=True, exist_ok=True)
(raw / "keep.xml").write_text('<?xml version="1.0" encoding="utf-8"?>\n<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@drawable/ic_stat_notify" />\n', encoding="utf-8")

# --- AndroidManifest.xml ---
mf = root / "src/main/AndroidManifest.xml"
m = mf.read_text(encoding="utf-8")
perms = [
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.VIBRATE",
    "android.permission.USE_BIOMETRIC",
]
for p in perms:
    if p not in m:
        m = m.replace("<application", f'<uses-permission android:name="{p}"/>\n    <application', 1)
m = re.sub(r'android:label="[^"]*"', f'android:label="{APP_LABEL}"', m, count=1)
receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''
if "ScheduledNotificationReceiver" not in m:
    m = m.replace("</application>", receivers + "    </application>", 1)
queries = """
    <queries>
        <intent><action android:name="android.intent.action.INSERT"/><data android:mimeType="vnd.android.cursor.item/event"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>
    </queries>
"""
if "vnd.android.cursor.item/event" not in m:
    if "<queries>" in m:
        inner = queries.split("<queries>")[1].split("</queries>")[0]
        m = m.replace("<queries>", "<queries>" + inner, 1)
    else:
        m = m.replace("</manifest>", queries + "</manifest>", 1)
mf.write_text(m, encoding="utf-8")
print("Android ayarları uygulandı.")

# --- Parmak izi kilidi için FlutterFragmentActivity ---
for f in pathlib.Path("android/app/src/main").rglob("MainActivity.*"):
    c = f.read_text(encoding="utf-8")
    c = c.replace("io.flutter.embedding.android.FlutterActivity", "io.flutter.embedding.android.FlutterFragmentActivity")
    c = re.sub(r"\bFlutterActivity\(\)", "FlutterFragmentActivity()", c)
    c = re.sub(r"extends FlutterActivity\b", "extends FlutterFragmentActivity", c)
    f.write_text(c, encoding="utf-8")
    print("MainActivity güncellendi:", f)
