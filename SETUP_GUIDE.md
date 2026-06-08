# Panduan Setup Blade Ball di Roblox Studio

## Langkah 1: Buat Project Baru
1. Buka Roblox Studio
2. Pilih "Baseplate" template
3. Hapus baseplate default (opsional, arena akan dibuat otomatis)

## Langkah 2: Buat Struktur Folder di Explorer

### Di ReplicatedStorage:
1. Buat Folder bernama `Modules`
2. Buat Folder bernama `RemoteEvents`
3. Buat Folder bernama `Assets`

### Di ServerScriptService:
Klik kanan **ServerScriptService** → Insert Object → **Script** (bukan LocalScript).
Buat 4 Script: `RoundManager`, `GameManager`, `BallManager`, `DataManager`.
Paste isi masing-masing file `.lua` ke dalam script yang sesuai.

### Di StarterPlayer > StarterPlayerScripts:
Expand **StarterPlayer** di Explorer, klik kanan **StarterPlayerScripts** → Insert Object → **LocalScript**.
Rename jadi `LocalManager`, lalu paste isi dari file `LocalManager.lua`.

### Di StarterGui:
- Buat 4 ScreenGui: `MainUI`, `ShopUI`, `AbilityUI`, `RoundUI`

## Langkah 3: Masukkan Script

---

### A. ServerScriptService — 4 Script

Untuk setiap file di bawah ini, lakukan hal yang sama:
1. Klik kanan **ServerScriptService** di Explorer
2. Insert Object → pilih **Script**
3. Rename script sesuai nama file
4. Double-click script → Ctrl+A → Ctrl+V isi dari file .lua yang sesuai

Yang perlu dibuat:
- Script bernama `RoundManager` → paste isi `RoundManager.lua`
- Script bernama `GameManager` → paste isi `GameManager.lua`
- Script bernama `BallManager` → paste isi `BallManager.lua`
- Script bernama `DataManager` → paste isi `DataManager.lua`

---

### B. ReplicatedStorage/Modules — 5 ModuleScript

Untuk setiap file di bawah ini, lakukan hal yang sama:
1. Klik kanan folder **Modules** (yang ada di dalam ReplicatedStorage) di Explorer
2. Insert Object → pilih **ModuleScript**
3. Rename sesuai nama file
4. Double-click → Ctrl+A → Ctrl+V isi dari file .lua yang sesuai

Yang perlu dibuat:
- ModuleScript bernama `RoundSystem` → paste isi `RoundSystem.lua`
- ModuleScript bernama `BallSystem` → paste isi `BallSystem.lua`
- ModuleScript bernama `AbilitySystem` → paste isi `AbilitySystem.lua`
- ModuleScript bernama `ShopSystem` → paste isi `ShopSystem.lua`
- ModuleScript bernama `EffectSystem` → paste isi `EffectSystem.lua`

---

### C. StarterPlayer/StarterPlayerScripts — 1 LocalScript

1. Expand **StarterPlayer** di Explorer
2. Klik kanan **StarterPlayerScripts**
3. Insert Object → pilih **LocalScript**
4. Rename jadi `LocalManager`
5. Double-click → Ctrl+A → Ctrl+V isi dari `LocalManager.lua`

---

### D. StarterGui — 4 ScreenGui, masing-masing berisi 1 LocalScript

Untuk setiap ScreenGui, lakukan langkah berikut:

**RoundUI:**
1. Klik kanan **StarterGui** → Insert Object → **ScreenGui** → rename jadi `RoundUI`
2. Klik kanan **RoundUI** → Insert Object → **LocalScript**
3. Double-click LocalScript tersebut → Ctrl+A → Ctrl+V isi dari `RoundUI.lua`

**ShopUI:**
1. Klik kanan **StarterGui** → Insert Object → **ScreenGui** → rename jadi `ShopUI`
2. Klik kanan **ShopUI** → Insert Object → **LocalScript**
3. Double-click LocalScript tersebut → Ctrl+A → Ctrl+V isi dari `ShopUI.lua`

**AbilityUI:**
1. Klik kanan **StarterGui** → Insert Object → **ScreenGui** → rename jadi `AbilityUI`
2. Klik kanan **AbilityUI** → Insert Object → **LocalScript**
3. Double-click LocalScript tersebut → Ctrl+A → Ctrl+V isi dari `AbilityUI.lua`

**MainUI:**
1. Klik kanan **StarterGui** → Insert Object → **ScreenGui** → rename jadi `MainUI`
2. Klik kanan **MainUI** → Insert Object → **LocalScript**
3. Double-click LocalScript tersebut → Ctrl+A → Ctrl+V isi dari `MainUI.lua`

## Langkah 4: Konfigurasi ScreenGui
Untuk setiap ScreenGui di StarterGui:
- `ResetOnSpawn`: **false**
- `IgnoreGuiInset`: **true** (untuk RoundUI dan MainUI)
- `DisplayOrder`: atur sesuai kebutuhan (RoundUI: 5, MainUI: 3, ShopUI: 10, AbilityUI: 4)

## Langkah 5: Test

### Cara cepat test:
1. Klik **Play** (bukan Play Here)
2. Gunakan **Test > Players** untuk menambah bot
3. Atau **Playtest** dengan 2 tab Studio

### Kontrol:
- **E** atau **Klik Kiri** = Parry
- **Q** = Dash ability
- **F** = Shield ability  
- **R** = Teleport ability
- **G** = Freeze Ball ability
- Klik tombol **🛒 Shop** = Buka toko
- Klik tombol **🏆 Leaderboard** = Buka leaderboard

## Langkah 6: Assets (Opsional)
Ganti `rbxassetid://0` di EffectSystem.lua dengan ID sound yang valid dari:
- Roblox Audio Library
- Sound assets kamu sendiri

## Struktur Explorer Final yang Benar:
```
Workspace
├── Arena (Model - dibuat otomatis)
├── BallSpawn (Part - dibuat otomatis)
└── SpawnPoints (Folder - dibuat otomatis)

ReplicatedStorage
├── Modules
│   ├── BallSystem (ModuleScript)
│   ├── RoundSystem (ModuleScript)
│   ├── AbilitySystem (ModuleScript)
│   ├── ShopSystem (ModuleScript)
│   └── EffectSystem (ModuleScript)
└── RemoteEvents (dibuat otomatis oleh RoundManager)
    ├── ParryBall
    ├── PlayerDied
    ├── RoundStatus
    ├── UpdateUI
    ├── UseAbility
    ├── BuyItem
    ├── BallTarget
    └── SpawnEffect

ServerScriptService
├── RoundManager (Script) ← jalankan PERTAMA
├── GameManager (Script)
├── BallManager (Script)
└── DataManager (Script)

StarterPlayer
└── StarterPlayerScripts
    └── LocalManager (LocalScript)

StarterGui
├── MainUI (ScreenGui)
│   └── Script (LocalScript) ← MainUI.lua
├── ShopUI (ScreenGui)
│   └── Script (LocalScript) ← ShopUI.lua
├── AbilityUI (ScreenGui)
│   └── Script (LocalScript) ← AbilityUI.lua
└── RoundUI (ScreenGui)
    └── Script (LocalScript) ← RoundUI.lua
```

## Tips Performa:
- `RoundManager` akan otomatis membuat arena jika belum ada
- `RemoteEvents` dibuat otomatis, tidak perlu buat manual
- DataStore butuh **Enable Studio Access to API Services** di Game Settings > Security

## Troubleshooting:
- **Error "Modules not found"**: Pastikan semua ModuleScript ada di `ReplicatedStorage/Modules`
- **Bola tidak muncul**: Cek apakah `BallSpawn` part ada di Workspace
- **UI tidak muncul**: Pastikan LocalScript ada di dalam ScreenGui, bukan di luar
- **DataStore error**: Enable API access di Game Settings
