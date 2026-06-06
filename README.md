# Proyek Baru Permainan

Dokumentasi ini menjelaskan fondasi game action roguelike top-down yang sedang dibangun di Godot.

## Status gameplay saat ini

- Player bergerak 8 arah memakai WASD.
- Camera mengikuti player di arena test.
- Enemy spawn otomatis di sekitar pinggir area kamera.
- Enemy mengejar player dan memberi damage saat bersentuhan.
- Player menembak otomatis ke enemy terdekat seperti Vampire Survivors.
- Projectile mengurangi HP enemy.
- Enemy men-drop pickup XP dan punya peluang drop pickup HP saat mati.
- Pickup HP menyembuhkan player, pickup XP menambah XP player.
- HUD kiri atas menampilkan HP player dan XP bar.
- Saat player mati, muncul layar game over dengan tombol Restart dan Keluar.

## Struktur folder penting

- `scenes/`
  Scene Godot yang tampil di game.
- `scenes/entities/`
  Entity gameplay seperti `Player`, `Enemy`, `Projectile`, dan `PickupItem`.
- `scenes/world/`
  Scene dunia/arena seperti `TestArena` dan `EnemySpawner`.
- `scripts/gameplay/`
  Logic gameplay utama.
- `scripts/ui/`
  Logic UI seperti HUD dan game over screen.
- `autoload/`
  Singleton global untuk state, event, RNG, dan run manager.
- `resources/`
  Data balancing berbentuk `.tres`, supaya angka gameplay tidak hardcoded di script.
- `resources/abilities/`
  Data default modifier ability dan multiplier rarity.
- `ui/screens/`
  Scene UI.

## Scene utama

Main scene ada di:

- `scenes/Main.tscn`

Isi utamanya:

- `World`
  Menampung arena, player, spawner, enemy, projectile, dan pickup.
- `UI`
  Menampung `PlayerHud` dan `GameOverScreen`.

## Resource config

Angka gameplay disimpan di resource agar mudah diubah tanpa edit kode:

- `resources/actors/player_default.tres`
  HP player, movement speed, dan pickup radius.
- `resources/actors/enemy_dummy.tres`
  HP enemy, movement speed, contact damage, contact cooldown, weighted XP drop, weighted HP drop, dan peluang drop HP.
- `resources/weapons/basic_weapon.tres`
  Damage senjata, interval serangan, dan range auto-shoot.
- `resources/abilities/default_ability_modifiers.tres`
  Default nilai modifier ability dan multiplier rarity.
- `resources/projectiles/player_projectile.tres`
  Kecepatan dan lifetime projectile.
- `resources/spawners/enemy_spawner_default.tres`
  Interval spawn, jumlah enemy per wave, scaling spawn, scaling damage enemy, dan batas area spawn.
- `resources/items/health_pickup.tres`
  Pickup HP default/fallback dengan jenis `hp`; jumlah heal drop enemy diisi dari weighted HP drop `EnemyConfig`.
- `resources/items/xp_pickup.tres`
  Pickup XP dengan jenis `xp` dan jumlah XP default.
- `resources/xp/default_xp.tres`
  XP yang dibutuhkan per level dan multiplier pertumbuhan level.

## Alur gameplay

1. `PlayerController` membaca `PlayerConfig`, `WeaponConfig`, dan `XPConfig`, lalu mengisi HP awal ke `GameState`.
2. `EnemySpawner` membaca `SpawnerConfig`, lalu spawn enemy secara berkala.
3. `EnemyController` membaca `EnemyConfig`, lalu mengejar player.
4. Player auto-shoot ke enemy terdekat dalam range.
5. `Projectile` memanggil `take_damage()` pada enemy yang terkena.
6. Saat enemy mati, enemy men-drop `PickupItem` XP sesuai `EnemyConfig`, lalu dapat men-drop `PickupItem` HP secara random.
7. `PickupItem` menerapkan efek ke player, misalnya `heal()` untuk HP atau `add_xp()` untuk XP.
8. Jika XP player mencapai target level, `PlayerController` memanggil event `player_level_up`.
9. Sisa XP berlebih dibawa ke level berikutnya, lalu target XP berikutnya dihitung dari `XPConfig`.
10. `PlayerHud` mendengar event `player_health_changed` dan `player_xp_changed` dari `EventBus`.
11. Jika HP player habis, `PlayerController` memanggil `player_died`.
12. `GameOverScreen` muncul dan menyediakan tombol Restart/Keluar.

## Catatan maintenance

- Untuk balancing, utamakan edit file `.tres` di `resources/`, bukan script.
- Weighted XP gem diatur di `EnemyConfig` lewat `xp_drop_values` dan `xp_drop_weights`.
- Weighted HP pickup diatur di `EnemyConfig` lewat `hp_drop_values` dan `hp_drop_weights`; peluang drop HP memakai `health_drop_chance`.
- Base damage senjata player ada di `WeaponConfig.damage`; upgrade damage persen bisa memakai `add_damage_percent_modifier()` atau `apply_ability_modifier()`.
- Ability modifier player bisa memakai `apply_ability_modifier(modifier_type, base_value, rarity)`.
- Default ability modifier: damage `+5%`, attack speed `+15%`, dan max HP `+5`.
- Rarity multiplier diatur di `AbilityModifierConfig`; contoh damage `20%` rarity Epic menghasilkan `20% * 1.5 = 30%`.
- Attack speed player memakai `WeaponConfig.attack_interval`; upgrade attack speed bisa memanggil `add_attack_speed_modifier()` untuk menambah attack speed berbasis persen.
- Base damage enemy ada di `EnemyConfig`; kenaikan damage seiring waktu disimpan sebagai bonus runtime dari `SpawnerConfig`.
- Untuk komunikasi antar sistem, pakai signal di `autoload/EventBus.gd`.
- Event `player_level_up` dipakai sebagai trigger level up; UI/upgrade system nanti bisa mendengarkan event ini.
- Untuk state global seperti HP player dan mode game, pakai `autoload/GameState.gd`.
- Hindari spawn/free node physics langsung dari callback collision. Gunakan `call_deferred()` jika mengubah scene tree dari signal physics seperti `body_entered`.
- Entity yang perlu dicari sistem lain sebaiknya memakai group, misalnya `player` dan `enemy`.
