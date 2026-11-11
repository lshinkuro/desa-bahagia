# Desa Bahagia 🐄🌾

Game simulasi pedesaan 3D buatan Godot 4.7: rawat sapi & ayam ala Tamagotchi,
bertani, menebang kayu, membangun kebun & rumah, kerjakan misi harian, dan
main bareng teman lewat jaringan lokal (LAN).

## Download & main (macOS)

1. Buka halaman **[Releases](../../releases)** dan unduh `DesaBahagia-x.y.z.dmg` versi terbaru.
2. Buka DMG, seret **Desa Bahagia.app** ke folder **Applications**.
3. Pertama kali dibuka, macOS akan memblokir karena aplikasi belum ditandatangani Apple.
   Klik kanan aplikasi → **Open** → **Open**. Atau jalankan di Terminal:
   `xattr -dr com.apple.quarantine "/Applications/Desa Bahagia.app"`

Berjalan di Mac Intel maupun Apple Silicon (universal).

## Fitur

- Siklus siang-malam, lentera menyala di malam hari
- Rawat sapi & ayam: beri makan, elus, perah susu, ambil telur
- 12 misi utama + 3 misi harian acak setiap hari (hadiah koin)
- Kios desa: jual hasil panen, beli bibit, roti, ayam & sapi baru
- Tebang pohon untuk kayu, bangun petak kebun & rumah kayu sendiri
- Multiplayer LAN (sampai 8 pemain) dengan chat
- Simpan otomatis (tiap 30 detik, saat tidur, dan saat keluar)
- Musik latar & efek suara

## Kontrol

| Tombol | Fungsi |
|---|---|
| WASD / panah | Jalan |
| Spasi | Lompat |
| F | Aksi (panen, beri makan, buka kios, tebang pohon, …) |
| B | Menu bangun (1 = petak kebun, 2 = rumah kayu) |
| Enter | Chat |
| Mouse / Q E | Putar kamera |
| T (tahan) | Percepat waktu (hanya host) |
| H | Tampilkan/sembunyikan bantuan |
| Esc | Lepas kursor mouse |

## Main bareng (multiplayer)

1. Satu orang memilih **Buat Server (Host)** — IP-nya muncul di layar.
2. Teman di WiFi yang sama mengetik IP tersebut lalu **Gabung**.
3. Main lewat internet butuh port forwarding UDP **7777** di router host.

### Main bareng beda WiFi (Tailscale)
1. Host & teman install [Tailscale](https://tailscale.com) (gratis), login, lalu host mengundang teman ke jaringannya.
2. Host klik **Buat Server** — game menampilkan IP `Tailscale: 100.x.x.x` (juga muncul di chat & menu Esc).
3. Teman memasukkan IP `100.x.x.x` itu di kolom **Gabung**.
4. Pastikan semua memakai versi game yang sama. Jika macOS menanyakan izin koneksi masuk, pilih **Allow**.

## Membuat versi baru (DMG otomatis)

Setiap tag versi yang di-push akan dibangun otomatis oleh GitHub Actions
dan DMG-nya diunggah ke Releases:

```bash
git tag v1.1.0
git push origin v1.1.0
```

Build lokal (butuh Godot 4.7.2 + export templates):

```bash
GODOT=/path/ke/Godot.app/Contents/MacOS/Godot scripts/build_dmg.sh 1.1.0
```

## Kredit aset (semuanya gratis)

- 3D, UI, efek suara: [Kenney.nl](https://kenney.nl) — CC0
- Musik "Hot Spring Town": [OpenGameArt](https://opengameart.org/node/155383) — CC0
- Suara sapi: [qubodup, OpenGameArt](https://opengameart.org/content/sci-fi-aliens-and-cows-pack) — CC0
- Font Fredoka: [Google Fonts](https://github.com/google/fonts/tree/main/ofl/fredoka) — SIL OFL 1.1

Lisensi lengkap tiap paket ada di `assets/LICENSE-*.txt`.
