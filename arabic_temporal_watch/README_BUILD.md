# تثبيت الساعة العربية على الجوال

دليل بناء التطبيق وتثبيته على جهاز أندرويد أو آيفون.

---

## المتطلبات

| الأداة | الإصدار | التحقق |
|--------|---------|--------|
| Flutter SDK | 3.19 أو أحدث | `flutter --version` |
| JDK | 17 أو 21 | `java -version` |
| Android Studio | Ladybug أو أحدث (لأندرويد) | — |
| Xcode | 15 أو أحدث (للآيفون، ماك فقط) | `xcodebuild -version` |

تثبيت Flutter على الماك:

```bash
brew install --cask flutter
flutter doctor          # اتبع أي خطوة ناقصة يذكرها
```

---

## أندرويد — الطريقة الأسرع (بناء وتثبيت مباشرة)

وصّل الجوال بكابل USB، وفعّل **خيارات المطور** ثم **تصحيح أخطاء USB**
(الإعدادات ← حول الهاتف ← اضغط "رقم الإصدار" ٧ مرات).

```bash
cd arabic_temporal_watch

flutter pub get
flutter devices                 # تأكد أن جوالك ظاهر في القائمة
flutter run --release           # يبني ويثبّت ويشغّل على الجوال
```

## أندرويد — بناء ملف APK ونقله يدوياً

```bash
cd arabic_temporal_watch

flutter pub get
flutter build apk --release
```

الملف الناتج:

```
build/app/outputs/flutter-apk/app-release.apk
```

انقله إلى الجوال (بلوتوث، Google Drive، أو كابل)، ثم افتحه من مدير الملفات.
سيطلب الأندرويد السماح بـ **تثبيت التطبيقات من مصادر غير معروفة** — وافق ثم ثبّت.

> **ملاحظة عن التوقيع:** نسخة الـ release موقّعة حالياً بمفتاح التصحيح
> (`signingConfig signingConfigs.debug` في `android/app/build.gradle`) حتى
> يعمل الـ APK فور بنائه. قبل النشر على Google Play أنشئ keystore حقيقياً
> وبدّل إعداد التوقيع.

### تصغير حجم الـ APK (اختياري)

```bash
flutter build apk --release --split-per-abi
```

ينتج ثلاثة ملفات؛ ثبّت `app-arm64-v8a-release.apk` لأي جوال حديث.

---

## آيفون

مجلد `ios/` يحتوي على `Info.plist` فقط، لذا يلزم توليد باقي ملفات المشروع
مرة واحدة:

```bash
cd arabic_temporal_watch
flutter create --platforms=ios .
```

الأمر لا يمس مجلد `lib/` ولا يحذف `Info.plist` الحالي — يضيف فقط الملفات
الناقصة (`Runner.xcodeproj` وغيرها). ثم:

```bash
flutter pub get
open ios/Runner.xcworkspace     # في Xcode: اختر فريق التوقيع من Signing & Capabilities
flutter run --release           # مع توصيل الآيفون
```

التثبيت على آيفون يتطلب حساب مطور Apple (الحساب المجاني يعمل لكن التطبيق
ينتهي بعد ٧ أيام ويحتاج إعادة تثبيت).

---

## الأذان

مجلد `assets/audio/` فارغ حالياً. التطبيق يعمل بدونه (يتجاهل الصوت بصمت)،
ولتفعيل الأذان أضف هذه الملفات:

```
assets/audio/adhan_makkah.mp3
assets/audio/adhan_makkah_fajr.mp3
assets/audio/adhan_madinah.mp3
assets/audio/adhan_madinah_fajr.mp3
assets/audio/adhan_afasy.mp3
assets/audio/adhan_afasy_fajr.mp3
```

ثم أعد البناء.

---

## حل المشاكل الشائعة

| العطل | الحل |
|-------|------|
| `Unsupported class file major version 65` | استخدم JDK 17: `flutter config --jdk-dir /path/to/jdk-17` |
| `No connected devices` | فعّل تصحيح USB، وجرّب `adb devices` وثق بالحاسب من نافذة الجوال |
| `SDK location not found` | افتح المشروع مرة في Android Studio ليولّد `android/local.properties` |
| فشل التثبيت `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | احذف النسخة القديمة من الجوال أولاً |
| بناء بطيء جداً أول مرة | طبيعي — Gradle ينزّل الاعتماديات؛ المرات التالية أسرع بكثير |

---

## فحص سريع قبل البناء

```bash
flutter analyze     # تحليل ثابت للكود
flutter test        # ٣٢ اختبار وحدة للمحرك الزمني وحاسبة الصلوات
```
