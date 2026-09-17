# PuzzlePic — Native Godot Android Jigsaw

Bu proje WebView değildir. Oyun alanı, parçalar, kamera, sürükleme, pinch zoom, grup birleştirme ve jigsaw geometrisi Godot/GDScript ile çalışır.

## Özellikler

- Godot 4.7.2
- Android native Godot export
- 4×4, 6×6, 8×8, 10×10, 12×12, 15×15, 20×20 (400 parça)
- Gerçek jigsaw çıkıntı/girinti geometrisi
- Büyük sanal masa
- Parçalar hedef çerçevenin çevresine dağılır
- Serbest yerleştirme; doğru/yanlış kare yok
- Sadece gerçek komşular doğru açı/mesafede snap olur
- Birleşen parçalar grup halinde taşınır
- İsteğe bağlı 90° döndürme
- Mouse/touch sürükleme, pan ve pinch zoom
- İpucu
- Geçici tamamlanmış fotoğraf önizlemesi
- Otomatik durum kaydı
- Android için yatay/dikey ekran uyumu

## GitHub Actions ile gerçek APK üretme

1. GitHub'da boş bir repo oluştur.
2. Bu ZIP'in içindekileri repo köküne yükle.
3. `Actions` sekmesine gir.
4. `Build Godot Android APK` workflow'unu aç.
5. `Run workflow` seçeneğine bas.
6. Build tamamlandığında `Artifacts` bölümünden `PuzzlePic-Godot-APK` dosyasını indir.

Workflow `barichello/godot-ci:4.7.2` konteynerinde doğrudan şu komutu çalıştırır:

```bash
godot --headless --verbose --export-debug "Android" build/PuzzlePic-Godot.apk
```

Bu nedenle çıkan APK gerçek Godot Android export'udur.

## Yerelde export

Godot 4.7.2 ve Android SDK kuruluysa:

```bash
godot --headless --export-debug "Android" build/PuzzlePic-Godot.apk
```

## Not

Android'de galeri seçimi `FileDialog` native dialog üzerinden yapılır. Bazı üretici ROM'larında belge seçici davranışı farklı olabilir; gerekirse sonraki revizyonda Android Photo Picker eklentisi eklenebilir.
