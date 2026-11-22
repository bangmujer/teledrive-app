# TeleDrive — Flutter (iOS + Android, satu codebase)

Client Flutter untuk backend FastAPI TeleDrive di
`https://teledrive.mjr-dev.my.id`.
Satu codebase, build APK via GitHub Actions (Ubuntu) dan IPA unsigned
via GitHub Actions (macOS + Xcode 16+).

## Fitur v1
- Login web (cookie `session_token`, tersimpan 30 hari) — akun yang sama
  seperti di browser. Alamat server bisa diubah di layar login.
- Login Telegram di dalam app: kirim kode OTP (+62, 10 menit),
  verifikasi kode + password 2FA. Kalau Telegram putus, dashboard
  menampilkan banner dan mengarahkan ke layar ini (backend menjawab 503).
- Dashboard: total file/ukuran + per kategori.
- Folder: list, masuk folder, buat, rename, hapus.
- File: cari (`/api/search`), filter kategori, upload (multipart),
  download + share, buat link share (`/shared/<token>`), hapus,
  extract ZIP.
- Sync: sync sekarang + pengaturan sync manual/auto/off + interval
  1/5/15/30/60 menit (`/api/sync-settings`).

## Struktur
- `lib/api/teledrive_api.dart` — semua endpoint backend, manajemen cookie.
- `lib/models.dart` — model folder/file/dashboard/sync/telegram.
- `lib/screens/` — login, telegram-login, home (berkas), sync-settings.
- `.github/workflows/build-apk.yml` — `flutter build apk --release`.
- `.github/workflows/build-ipa.yml` — `flutter build ipa --no-codesign`.

## Cara build (tanpa Mac / tanpa Android SDK lokal)
1. Push repo ini ke GitHub.
2. Tab Actions > pilih workflow > Run workflow.
3. Download artifact: APK di `build-apk`, IPA di `build-ipa`.
   IPA-nya unsigned — install via TrollStore / Feather / ESign / AltStore.

## Cara build lokal (kalau Flutter sudah terpasang)
```sh
flutter pub get
flutter analyze
flutter build apk --release
flutter build ipa --release --no-codesign   # butuh macOS + Xcode
```

## Catatan keamanan
- Cookie sesi TIDAK pernah di-log atau ditampilkan. Jangan commit
  kredensial apa pun ke repo.
- Halaman login Telegram di backend tetap wajib login web dulu —
  app ini mengikuti aturan yang sama: tidak ada jalan pintas OTP
  tanpa login web.
- Kalau Telegram mencabut sesi (pernah terjadi, 401 AUTH_KEY),
  app akan menampilkan status putus dan minta login Telegram ulang
  lewat app. Itu normal dan di luar kontrol app.
