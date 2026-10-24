# Bayzo Anime Adventures Macro

Macro AutoHotkey v2 untuk game Roblox Anime Adventures — auto-farm dungeons, challenges, raids, story modes.

## Status: CLEAN REBUILD

Macro ini di-rebuild dari source asli (Capy's AA Macro v1.1) dengan **dihapusnya semua komponen yang bisa akses credential/PC/auto-update**:

| Dihapus | Alasan |
|---|---|
| CrusadersUpdater class | Auto-download dari GitHub repo dev + exec PS1 |
| LaunchInstaller | powershell -EncodedCommand + replace exe |
| UpdateInstaller.ps1 | PowerShell installer (download + replace exe) |
| CrusadersConfigCodes cloud worker | Upload/download config ke server dev (capybaraalt113.workers.dev) |

| Tetap (game function) | Fungsi |
|---|---|
| Macro logic | Auto-farm, dungeons, challenges, raids |
| WebView2 UI | Interface macro (data dir sendiri) |
| Webhook Discord | Kirim screenshot match ke webhook lo |
| Discord Bot | Notifikasi macro via Discord bot (DPAPI encrypted) |
| OCR (RapidOcr) | Baca text di screen untuk deteksi |
| Config import/export | LOCAL file sharing (bukan cloud) |

**Zero network calls ke server dev.** Semua network cuma: Discord webhook (lo isi sendiri) + Discord bot API (lo enable sendiri).

---

## STEP 1: Install AutoHotkey v2

1. Buka browser, download dari https://www.autohotkey.com/
2. Pilih **v2** (bukan v1)
3. Install — next-next aja, default settings
4. Selesai

## STEP 2: Download & Extract

1. Download repo ini (Code → Download ZIP) atau clone:
   ```
   git clone https://github.com/bayzoishere/bayzo-anime-adventures.git
   ```
2. Extract ke folder, contoh: `Desktop\Bayzo-Anime-Adventures\`
3. Struktur folder:
   ```
   Bayzo-Anime-Adventures/
   ├── BayzoAnimeAdventuresMacro.ahk    ← script utama
   ├── Images/                           ← gambar deteksi macro
   ├── Other/                            ← OCR engine + WebView2
   ├── Settings/                         ← config macro
   └── README-BAYZO.md
   ```

## STEP 3: Jalanin Macro

1. Buka folder `Bayzo-Anime-Adventures\`
2. Double-click `BayzoAnimeAdventuresMacro.ahk`
3. Window UI muncul: "Bayzo's AA Macro v1.1"
4. Kalau Windows nanya permission → Allow

## STEP 4: Setup Settings

### Private Server (recommended)
1. Tab **Settings** → **General**
2. Masukin **Private Server Link** (dari Roblox server lo)
3. Centang **Use Private Server Link**
4. Save

### Discord Webhook (opsional, buat notifikasi match)
1. Buka Discord channel lo → Settings → Integrations → Webhooks → New Webhook
2. Copy webhook URL
3. Tab **Settings** → **Webhooks**
4. Paste URL di **Webhook URL**
5. Centang **Enable Webhook**
6. Pilih apa yang mau dikirim: Map Name, Mode, Completion Time, Screenshot
7. Save

### Discord Bot (opsional, buat control macro dari Discord)
1. Buka https://discord.com/developers/applications → New Application
2. Tab Bot → Reset Token → Copy token
3. Tab OAuth2 → URL Generator → scopes: `bot` + `applications.commands`
4. Permissions: View Channels, Send Messages, Attach Files
5. Invite bot ke server lo
6. Enable Developer Mode di Discord (User Settings → Advanced)
7. Copy User ID (right-click profile lo)
8. Copy Channel ID (right-click channel text)
9. Tab **Settings** → **Discord Integration**
10. Masukin: User ID, Channel ID, Bot Token
11. Centang **Enable Discord Integration**
12. Save → tunggu "Discord commands registered: /macro"
13. Test: ketik `/macro screenshot` di channel

## STEP 5: Setup Game Roblox

1. Buka Roblox → Anime Adventures
2. Windowed mode (bukan fullscreen)
3. Resolusi sesuai panduan (cek tab **Guide** di macro UI):
   - Buka tab Guide
   - Ikuti step: Roblox Settings, Windows Display, NVIDIA 3D settings
4. Pastikan window Roblox keliatan jelas (gak ketutup window lain)

## STEP 6: Mulai Farm

1. Di UI macro, pilih **Mode**:
   - **Story**: farm story stages
   - **Dungeons**: farm dungeons
   - **Challenges**: farm daily challenges
   - **Raids**: farm raids
2. Pilih **Map** yang mau di-farm
3. Klik **Start**
4. Macro auto-kerja:
   - Deteksi map di screen (OCR)
   - Klik tombol auto-play
   - Place unit otomatis
   - Detect victory/defeat
   - Rejoin otomatis kalau selesai
   - Kirim webhook screenshot kalau menang
5. Macro jalan terus sampai di-Stop

## STEP 7: Stop & Pause

- **Stop**: Klik tombol Stop di UI
- **Pause**: Tekan hotkey pause (cek tab **Keybinds**)
- **Close**: Tutup window macro

## STEP 8: Custom Map Images (opsional)

Kalau macro gak detect map lo:
1. Tab **Game Tools**
2. **Replace Map Image**: Capture screenshot map lo
3. Macro bakal pakai screenshot lo buat deteksi

---

## Troubleshooting

| Masalah | Solusi |
|---|---|
| .ahk gak jalan waktu di-click | Install AutoHotkey v2 ulang, pastikan pilih v2 |
| OCR gak detect map | Upload screenshot map sendiri (tab Game Tools) |
| Webhook gak kirim | Cek URL webhook Discord benar + enable |
| Window UI gak muncul | Install Microsoft Edge WebView2 Runtime |
| Macro klik salah posisi | Setting resolusi Roblox sesuai Guide |
| "Macro connection" error | Pastikan Roblox window keliatan, gak minimize |
| Discord bot gak respon | Cek token benar, bot udah di-invite ke server |

---

## Update di Masa Depan

Macro ini **gak auto-update** (sengaja dihapus). Kalau mau update:

1. Cek repo asli: https://github.com/capybarnia4life/AnimeAdventuresMacro/releases
2. Download release baru
3. Scan ulang (audit security)
4. Kalau aman, copy file `Images/` dan `Settings/` baru ke folder ini
5. Jangan replace `.ahk` langsung — strip ulang dulu (hapus auto-update + cloud worker)

---

## Security Notes

- **Gak ada auto-update** — macro gak akan download apapun sendiri
- **Gak ada cloud worker** — gak ada request ke server pihak ketiga
- **Gak ada PowerShell exec** — gak ada command tersembunyi
- **Discord token** disimpan pakai DPAPI (Windows encryption per-account)
- **Webhook URL** lo sendiri yang diisi, macro cuma kirim ke situ
- **Semua network traffic**: cuma Discord (kalo lo enable)

Kalau ragu, cek network traffic pakai Wireshark atau Windows Firewall log.
