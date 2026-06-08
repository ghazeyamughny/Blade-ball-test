# Blade Ball - Roblox Game

Game arena PvP di mana pemain memantulkan bola energi. Pemain terakhir yang bertahan menang.

## Cara Install

1. Buka Roblox Studio
2. Buat project baru
3. Copy isi setiap file ke lokasi yang sesuai di Explorer:

### Struktur Roblox Explorer

```
ReplicatedStorage
├── Modules
│   ├── BallSystem       (ModuleScript)
│   ├── RoundSystem      (ModuleScript)
│   ├── AbilitySystem    (ModuleScript)
│   ├── ShopSystem       (ModuleScript)
│   └── EffectSystem     (ModuleScript)
├── RemoteEvents
│   ├── ParryBall        (RemoteEvent)
│   ├── PlayerDied       (RemoteEvent)
│   ├── RoundStatus      (RemoteEvent)
│   ├── UpdateUI         (RemoteEvent)
│   ├── UseAbility       (RemoteEvent)
│   ├── BuyItem          (RemoteEvent)
│   ├── BallTarget       (RemoteEvent)
│   └── SpawnEffect      (RemoteEvent)
└── Assets

ServerScriptService
├── GameManager          (Script)
├── BallManager          (Script)
├── DataManager          (Script)
└── RoundManager         (Script)

StarterPlayer
└── StarterPlayerScripts
    └── LocalManager     (LocalScript)

StarterGui
├── MainUI               (ScreenGui + LocalScript)
├── ShopUI               (ScreenGui + LocalScript)
├── AbilityUI            (ScreenGui + LocalScript)
└── RoundUI              (ScreenGui + LocalScript)

Workspace
├── Arena                (Model - lingkaran)
├── SpawnPoints          (Folder)
└── BallSpawn            (Part - center)
```

## Fitur
- Sistem bola dengan target acak & kecepatan meningkat
- Parry system dengan cooldown
- Arena lingkaran dengan boundary
- Round system (Waiting/Intermission/Starting/Playing/Winner)
- Leaderboard (Wins/Coins/Kills/Streak)
- Shop (Sword/Ball Skin, Emote, Effects)
- Ability System (Dash/Shield/Teleport/Freeze Ball)
- Visual Effects & Sounds
- Anti-Cheat validasi server
- DataStore persistent data
