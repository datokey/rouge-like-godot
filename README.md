# Proyek Baru Permainan

Dokumentasi ini menjelaskan fondasi game action roguelike top-down yang sedang dibangun di Godot.

## Status gameplay saat ini

- Player bergerak 8 arah memakai WASD.
- Camera mengikuti player di arena test.
- Enemy spawn otomatis di sekitar pinggir area kamera.
- Enemy punya variasi normal, Runner, dan Tank; Runner paling cepat, Tank paling tebal/lambat, dan reward drop tiap tipe bisa berbeda.
- Enemy mengejar player, memakai detour waypoint sederhana saat garis ke player tertutup obstacle, dan memberi damage saat bersentuhan.
- Player menembak otomatis ke enemy terdekat seperti Vampire Survivors.
- Projectile mengurangi HP enemy.
- Enemy memberi hit feedback saat terkena projectile: knockback kecil, hit flash, impact VFX, dan wadah sound hit.
- Enemy men-drop pickup XP dan punya peluang drop pickup HP saat mati.
- Pickup HP menyembuhkan player, pickup XP menambah XP player, dan pickup Magnet menarik pickup HP/XP ke player.
- HUD kiri atas menampilkan HP player, XP bar, dan progress survival run.
- Player menang jika berhasil bertahan hidup sampai survival timer selesai.
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
- `resources/difficulty/`
  Data progression difficulty berbasis progress waktu run.
- `resources/run/`
  Data target durasi survival dan placeholder scene berikutnya.
- `ui/screens/`
  Scene UI.

## Scene utama

Main scene ada di:

- `scenes/Main.tscn`

Isi utamanya:

- `World`
  Menampung arena, player, spawner, enemy, projectile, dan pickup.
- `UI`
  Menampung `PlayerHud`, `AbilitySelectionScreen`, `WinScreen`, dan `GameOverScreen`.

## Resource config

Angka gameplay disimpan di resource agar mudah diubah tanpa edit kode:

- `resources/actors/player_default.tres`
  HP player, movement speed, dan pickup radius.
- `resources/actors/enemy_dummy.tres`
  HP enemy normal, movement speed, contact damage, contact cooldown, detour pathfinding sederhana, jumlah roll XP, weighted XP drop, weighted HP drop, dan peluang drop HP.
- `resources/actors/enemy_runner.tres`
  Config Runner: HP menengah, movement speed paling tinggi, contact damage configurable, jumlah roll XP 1-2, weighted XP/HP drop khusus, dan peluang drop HP di atas enemy normal.
- `resources/actors/enemy_tank.tres`
  Config Tank: HP, movement speed lambat, contact damage besar, jumlah roll XP 2-3, weighted XP/HP drop khusus, dan peluang drop HP lebih tinggi.
- `resources/weapons/basic_weapon.tres`
  Damage senjata, interval serangan, dan range auto-shoot.
- `resources/abilities/default_ability_modifiers.tres`
  Default nilai modifier ability dan multiplier rarity.
- `resources/abilities/default_ability_pool.tres`
  Pool data upgrade level up. Prototype saat ini berisi minimal 10 `AbilityDefinition`.
- `resources/projectiles/player_projectile.tres`
  Kecepatan dan lifetime projectile.
- `resources/feedback/default_hit_feedback.tres`
  Tuning hit feedback enemy seperti knockback, flash, impact VFX, dan hit stop lokal.
- `resources/spawners/enemy_spawner_default.tres`
  Batas area spawn dan jarak spawn dari kamera.
- `resources/difficulty/default_difficulty.tres`
  Difficulty Manager: min/max spawn interval, min/max spawn count, dan daftar phase.
- `resources/difficulty/phase_early.tres`, `phase_mid.tres`, `phase_late.tres`
  Phase difficulty berbasis `start_progress`; tiap phase mengatur HP/damage/speed multiplier, spawn interval/count, max alive enemy, serta daftar enemy yang bisa muncul.
- `resources/run/default_run_config.tres`
  Target survival timer dan `next_scene_path` untuk persiapan pindah scene setelah menang.
- `resources/items/health_pickup.tres`
  Pickup HP default/fallback dengan jenis `hp`; jumlah heal drop enemy diisi dari weighted HP drop `EnemyConfig`.
- `resources/items/runner_health_pickup.tres`
  Pickup HP dummy khusus Runner; jumlah heal final tetap diisi dari weighted HP drop `EnemyConfig`.
- `resources/items/tank_health_pickup.tres`
  Pickup HP dummy khusus Tank; jumlah heal final tetap diisi dari weighted HP drop `EnemyConfig`.
- `resources/items/xp_pickup.tres`
  Pickup XP dengan jenis `xp` dan jumlah XP default.
- `resources/items/magnet_pickup.tres`
  Pickup Magnet dengan jenis `magnet`.
- `resources/items/magnet_default.tres`
  Durasi, radius, pull speed, dan batch size efek Magnet.
- `resources/xp/default_xp.tres`
  XP yang dibutuhkan per level dan multiplier pertumbuhan level.

## Alur gameplay

1. `Main` memanggil `RunManager.start_run()` saat scene dibuka/reload.
2. `RunManager` reset run, mengisi seed, dan mulai menghitung survival timer.
3. `PlayerController` membaca `PlayerConfig`, `WeaponConfig`, dan `XPConfig`, lalu mengisi HP awal ke `GameState`.
4. `EnemySpawner` membaca `SpawnerConfig` untuk area spawn dan `DifficultyManager` untuk scaling difficulty.
5. `DifficultyManager` menghitung progress dari `GameState.run_elapsed_time / GameState.run_target_time`.
6. `EnemySpawner` memilih enemy dari phase aktif, lalu memberi multiplier HP, damage, dan move speed ke enemy yang baru di-spawn.
7. `EnemyController` membaca `EnemyConfig` sebagai base stat, lalu memakai multiplier runtime dari Difficulty Manager.
8. Player auto-shoot ke enemy terdekat dalam range.
9. `Projectile` memanggil `take_damage()` pada enemy yang terkena.
10. Saat enemy mati, enemy men-drop `PickupItem` XP sesuai jumlah roll dan weighted value di `EnemyConfig`, lalu dapat men-drop `PickupItem` HP secara random.
11. `PickupItem` menerapkan efek ke player, misalnya `heal()` untuk HP atau `add_xp()` untuk XP.
12. Jika XP player mencapai target level, `PlayerController` memanggil event `player_level_up`.
13. `AbilitySelectionScreen` meminta upgrade dari `AbilityPoolConfig`, pause game, menampilkan 3 pilihan upgrade dari data, lalu mengirim pilihan lewat event `ability_selected`.
14. Player menerapkan ability terpilih, lalu game berjalan kembali.
15. Sisa XP berlebih dibawa ke level berikutnya, lalu target XP berikutnya dihitung dari `XPConfig`.
16. `PlayerHud` mendengar event HP, XP, dan survival timer dari `EventBus`.
17. Jika HP player habis sebelum survival timer selesai, `RunManager` memicu lose state dan `GameOverScreen` muncul.
18. Jika survival timer mencapai target, `RunManager` memicu win state dan `WinScreen` muncul.

## Catatan maintenance

- Untuk balancing, utamakan edit file `.tres` di `resources/`, bukan script.
- Weighted XP gem diatur di `EnemyConfig` lewat `xp_drop_values` dan `xp_drop_weights`.
- Jumlah XP gem yang keluar diatur lewat `EnemyConfig.xp_drop_rolls_min` dan `EnemyConfig.xp_drop_rolls_max`; Runner default memakai 1-2 roll dan Tank default memakai 2-3 roll.
- Weighted HP pickup diatur di `EnemyConfig` lewat `hp_drop_values` dan `hp_drop_weights`; peluang drop HP memakai `health_drop_chance`.
- Rarity/chance drop Magnet diatur lewat `EnemyConfig.magnet_drop_chance`.
- Efek Magnet hanya menarik pickup `hp` dan `xp`; durasi, radius, pull speed, dan batch activation diatur lewat `MagnetConfig`.
- Detour pathfinding enemy diatur lewat `EnemyConfig`: `detour_path_enabled`, `detour_obstacle_collision_mask`, `detour_refresh_interval`, `detour_waypoint_margin`, dan `detour_waypoint_reached_distance`.
- Simple obstacle avoidance enemy tetap menjadi fallback dan diatur lewat `EnemyConfig`: `obstacle_avoidance_enabled`, `obstacle_avoidance_duration`, `obstacle_avoidance_weight`, `obstacle_stuck_time`, dan `obstacle_stuck_min_distance`.
- Base damage senjata player ada di `WeaponConfig.damage`; upgrade damage persen bisa memakai `add_damage_percent_modifier()` atau `apply_ability_modifier()`.
- Upgrade level up berbasis data `AbilityDefinition`: `id`, `name`, `category`, `effect_type`, `value`, `rarity`, dan `stackable`.
- Menambah upgrade baru cukup membuat resource `AbilityDefinition` dan memasukkannya ke `default_ability_pool.tres`; UI level up dan logic level up tidak perlu diubah.
- `AbilityPoolConfig.roll_offers()` memilih upgrade dari pool, sedangkan `AbilitySelectionScreen` hanya merender data upgrade yang diterima.
- Ability modifier player bisa memakai `apply_ability_modifier(modifier_type, base_value, rarity)`.
- Default ability modifier: damage `+5%`, attack speed `+15%`, dan max HP `+5`.
- Modifier tambahan tersedia untuk projectile count `+1` flat dan movement speed `+10%`.
- Rarity multiplier diatur di `AbilityModifierConfig`; contoh damage `20%` rarity Epic menghasilkan `20% * 1.5 = 30%`.
- Ability baru bisa dibuat sebagai resource `AbilityDefinition`, lalu dimasukkan ke `default_ability_pool.tres`.
- Attack speed player memakai `WeaponConfig.attack_interval`; upgrade attack speed bisa memanggil `add_attack_speed_modifier()` untuk menambah attack speed berbasis persen.
- Base damage enemy ada di `EnemyConfig`; scaling damage runtime sekarang berasal dari `DifficultyManager`.
- Hit feedback enemy diatur lewat `HitFeedbackConfig`; knockback memakai controlled displacement yang di-clamp, bukan physics force bebas.
- Difficulty progression mengikuti progress waktu run, bukan wave count.
- `DifficultyManager` diatur lewat `resources/difficulty/default_difficulty.tres`.
- Jumlah phase diatur dari panjang array `phases` pada `DifficultyManager`.
- Batas perpindahan phase diatur lewat `DifficultyPhaseConfig.start_progress`.
- HP/damage/move speed multiplier, spawn interval/count, max alive enemy, dan daftar enemy per phase diatur lewat resource phase difficulty.
- Menambah tipe enemy baru ke progression cukup memasukkan scene enemy tersebut ke `enemy_scenes` dan weight-nya ke `enemy_scene_weights` pada phase yang diinginkan.
- Survival win condition diatur lewat `RunConfig.survival_duration`; default prototype adalah `300` detik.
- `RunConfig.next_scene_path` disiapkan untuk pindah scene setelah menang, tetapi prototype saat ini masih boleh kosong.
- Untuk komunikasi antar sistem, pakai signal di `autoload/EventBus.gd`.
- Event `player_level_up` dipakai sebagai trigger level up; UI/upgrade system nanti bisa mendengarkan event ini.
- Untuk state global seperti HP player dan mode game, pakai `autoload/GameState.gd`.
- Hindari spawn/free node physics langsung dari callback collision. Gunakan `call_deferred()` jika mengubah scene tree dari signal physics seperti `body_entered`.
- Entity yang perlu dicari sistem lain sebaiknya memakai group, misalnya `player` dan `enemy`.
