enum Muezzin {
  makkah,
  madinah,
  afasy;

  String get arabicName {
    switch (this) {
      case Muezzin.makkah:  return 'مكة المكرمة';
      case Muezzin.madinah: return 'المدينة المنورة';
      case Muezzin.afasy:   return 'مشاري العفاسي';
    }
  }

  String assetPath({bool isFajr = false}) {
    final fajrSuffix = isFajr ? '_fajr' : '';
    switch (this) {
      case Muezzin.makkah:  return 'assets/audio/adhan_makkah$fajrSuffix.mp3';
      case Muezzin.madinah: return 'assets/audio/adhan_madinah$fajrSuffix.mp3';
      case Muezzin.afasy:   return 'assets/audio/adhan_afasy$fajrSuffix.mp3';
    }
  }
}
