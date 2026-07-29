# DuitKu

Aplikasi manajemen keuangan harian untuk Android, dirancang khusus untuk yang tidak mau pusing mencatat pengeluaran setiap saat.

Cukup input gaji, atur pos kebutuhan, dan aplikasi akan menghitung sendiri berapa yang boleh kamu keluarkan per hari yang mana tinggal centang kalau sudah dipakai.

## Fitur

- **Mode Pengangguran / Bekerja** — menyesuaikan perhitungan jatah harian sesuai kondisi
- **Pos kebutuhan fleksibel** — atur frekuensi pengeluaran: tiap hari, per periode gaji, atau selang minggu
- **Checklist harian** — tandai pengeluaran yang sudah dilakukan, saldo otomatis berkurang
- **Peringatan otomatis** — notifikasi kalau anggaran tidak cukup, pos non-prioritas disembunyikan otomatis
- **Talangan dari tabungan** — kalau saldo operasional habis, bisa tarik dari tabungan dengan catatan
- **Input harga aktual** — saat mencentang pengeluaran, kamu bisa input harga yang benar-benar dibayar, bukan hanya angka estimasi — jadi kalau ada diskon atau harga berbeda, saldo tetap akurat
- **Riwayat transaksi** — rekap semua pengeluaran yang sudah dilakukan
- **Offline sepenuhnya** — data disimpan lokal di perangkat, tanpa server, tanpa internet

## Struktur

```
lib/
  models.dart     -> struktur data + baca/tulis data.json
  logic.dart      -> semua logika bisnis
  theme.dart      -> palet warna dark theme
  dialogs.dart    -> dialog input jumlah, form pos, input gaji, konfirmasi
  widgets/
    common.dart   -> stat card, task row, alloc row, history row
  screens/
    beranda_tab.dart     -> stat + checklist harian + tombol aksi
    alokasi_tab.tab      -> kelola pos (tambah/edit/hapus)
    riwayat_tab.dart     -> daftar transaksi
    pengaturan_tab.dart  -> switch mode, config gaji, tombol reset
  main.dart       -> shell aplikasi (app bar + bottom nav)
```

## Cara menjalankan

1. Install Flutter SDK: https://docs.flutter.dev/get-started/install
2. Buka folder project, lalu generate folder platform:

   ```bash
   flutter create .
   ```

3. Install dependency:

   ```bash
   flutter pub get
   ```

4. Colokkan HP Android (aktifkan USB debugging) atau jalankan emulator, lalu:

   ```bash
   flutter run
   ```

5. Untuk build APK:

   ```bash
   flutter build apk --release
   ```

   APK hasil build ada di `build/app/outputs/flutter-apk/app-release.apk`.

## Penyimpanan data

Data disimpan lokal di `data.json` pada folder dokumen aplikasi Android — tidak ada koneksi ke server atau internet sama sekali.
