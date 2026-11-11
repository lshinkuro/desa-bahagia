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
- 4 musim (Semi, Panas, Gugur, Dingin — masing-masing 3 hari) dengan warna pohon, tanah, cuaca (kelopak bunga, daun gugur, salju) & efek berbeda
- Masuk rumah (kamera berubah jadi tampak atas): tidur di kasur, mandi, masak di kompor, makan di meja
- Bengkel: rakit pekakas (Kapak, Cangkul, Ember Siram) & pilih pekakas di rak
- Status energi & kebersihan — badan kotor bikin energi cepat habis
- Rawat sapi & ayam: beri makan, elus, perah susu, ambil telur
- 16 misi utama + 3 misi harian acak setiap hari (hadiah koin)
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
| F | Aksi (masuk/keluar bangunan, panen, masak, mandi, tidur, tebang pohon, …) |
| B | Menu bangun (1 = petak kebun, 2 = rumah kayu) |
| Enter | Chat |
| Tab | Ganti pekakas |
| Mouse / Q E | Putar kamera |
| T (tahan) | Percepat waktu (hanya host) |
| H | Tampilkan/sembunyikan bantuan |
| Esc | Menu jeda (simpan, keluar ke menu, tutup game) |

## Main bareng (multiplayer)

1. Satu orang memilih **Buat Server (Host)** — IP-nya muncul di layar.
2. Teman di WiFi yang sama mengetik IP tersebut lalu **Gabung**.
3. Main lewat internet butuh port forwarding UDP **7777** di router host.

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
- Furnitur rumah: [Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit) — CC0
- Font Cinzel & Alegreya Sans: [Google Fonts](https://fonts.google.com) — SIL OFL 1.1

Lisensi lengkap tiap paket ada di `assets/LICENSE-*.txt`.
