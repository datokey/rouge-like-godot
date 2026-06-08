# Proyek Baru Permainan

Dokumentasi ini menjelaskan fondasi game action roguelike top-down yang sedang dibangun di Godot.

## Status gameplay saat ini

- Player bergerak 8 arah memakai WASD.
- Camera mengikuti player di arena test.
- Enemy spawn otomatis di sekitar pinggir area kamera.
- Enemy punya variasi normal dan Tank; Tank lebih besar, lebih lambat, damage lebih tinggi, dan reward drop lebih besar.
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
- `resources/actors/enemy_tank.tres`
  Config Tank: HP, movement speed lambat, contact damage besar, jumlah roll XP 2-3, weighted XP/HP drop khusus, dan peluang drop HP lebih tinggi.
- `resources/weapons/basic_weapon.tres`
  Damage senjata, interval serangan, dan range auto-shoot.
- `resources/abilities/default_ability_modifiers.tres`
  Default nilai modifier ability dan multiplier rarity.
- `resources/abilities/default_ability_pool.tres`
  Daftar ability yang dapat muncul saat player naik level, termasuk peluang rarity.
- `resources/projectiles/player_projectile.tres`
  Kecepatan dan lifetime projectile.
- `resources/feedback/default_hit_feedback.tres`
  Tuning hit feedback enemy seperti knockback, flash, impact VFX, dan hit stop lokal.
- `resources/spawners/enemy_spawner_default.tres`
  Dynamic spawn interval, scaling jumlah enemy per spawn, batas alive enemy, scaling damage enemy, dan batas area spawn.
- `resources/run/default_run_config.tres`
  Target survival timer dan `next_scene_path` untuk persiapan pindah scene setelah menang.
- `resources/items/health_pickup.tres`
  Pickup HP default/fallback dengan jenis `hp`; jumlah heal drop enemy diisi dari weighted HP drop `EnemyConfig`.
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
4. `EnemySpawner` membaca `SpawnerConfig`, lalu spawn enemy secara berkala.
5. `EnemySpawner` memilih scene enemy dari `enemy_scenes` dan `enemy_scene_weights`.
6. `EnemyController` membaca `EnemyConfig`, lalu mengejar player.
7. Player auto-shoot ke enemy terdekat dalam range.
8. `Projectile` memanggil `take_damage()` pada enemy yang terkena.
9. Saat enemy mati, enemy men-drop `PickupItem` XP sesuai jumlah roll dan weighted value di `EnemyConfig`, lalu dapat men-drop `PickupItem` HP secara random.
10. `PickupItem` menerapkan efek ke player, misalnya `heal()` untuk HP atau `add_xp()` untuk XP.
11. Jika XP player mencapai target level, `PlayerController` memanggil event `player_level_up`.
12. `AbilitySelectionScreen` pause game, menampilkan 3 pilihan ability, lalu mengirim pilihan lewat event `ability_selected`.
13. Player menerapkan ability terpilih, lalu game berjalan kembali.
14. Sisa XP berlebih dibawa ke level berikutnya, lalu target XP berikutnya dihitung dari `XPConfig`.
15. `PlayerHud` mendengar event HP, XP, dan survival timer dari `EventBus`.
16. Jika HP player habis sebelum survival timer selesai, `RunManager` memicu lose state dan `GameOverScreen` muncul.
17. Jika survival timer mencapai target, `RunManager` memicu win state dan `WinScreen` muncul.

## Catatan maintenance

- Untuk balancing, utamakan edit file `.tres` di `resources/`, bukan script.
- Weighted XP gem diatur di `EnemyConfig` lewat `xp_drop_values` dan `xp_drop_weights`.
- Jumlah XP gem yang keluar diatur lewat `EnemyConfig.xp_drop_rolls_min` dan `EnemyConfig.xp_drop_rolls_max`; Tank default memakai 2-3 roll.
- Weighted HP pickup diatur di `EnemyConfig` lewat `hp_drop_values` dan `hp_drop_weights`; peluang drop HP memakai `health_drop_chance`.
- Rarity/chance drop Magnet diatur lewat `EnemyConfig.magnet_drop_chance`.
- Efek Magnet hanya menarik pickup `hp` dan `xp`; durasi, radius, pull speed, dan batch activation diatur lewat `MagnetConfig`.
- Detour pathfinding enemy diatur lewat `EnemyConfig`: `detour_path_enabled`, `detour_obstacle_collision_mask`, `detour_refresh_interval`, `detour_waypoint_margin`, dan `detour_waypoint_reached_distance`.
- Simple obstacle avoidance enemy tetap menjadi fallback dan diatur lewat `EnemyConfig`: `obstacle_avoidance_enabled`, `obstacle_avoidance_duration`, `obstacle_avoidance_weight`, `obstacle_stuck_time`, dan `obstacle_stuck_min_distance`.
- Base damage senjata player ada di `WeaponConfig.damage`; upgrade damage persen bisa memakai `add_damage_percent_modifier()` atau `apply_ability_modifier()`.
- Ability modifier player bisa memakai `apply_ability_modifier(modifier_type, base_value, rarity)`.
- Default ability modifier: damage `+5%`, attack speed `+15%`, dan max HP `+5`.
- Modifier tambahan tersedia untuk projectile count `+1` flat dan movement speed `+10%`.
- Rarity multiplier diatur di `AbilityModifierConfig`; contoh damage `20%` rarity Epic menghasilkan `20% * 1.5 = 30%`.
- Ability baru bisa dibuat sebagai resource `AbilityDefinition`, lalu dimasukkan ke `default_ability_pool.tres`.
- Attack speed player memakai `WeaponConfig.attack_interval`; upgrade attack speed bisa memanggil `add_attack_speed_modifier()` untuk menambah attack speed berbasis persen.
- Base damage enemy ada di `EnemyConfig`; kenaikan damage seiring waktu disimpan sebagai bonus runtime dari `SpawnerConfig`.
- Hit feedback enemy diatur lewat `HitFeedbackConfig`; knockback memakai controlled displacement yang di-clamp, bukan physics force bebas.
- Dynamic spawn interval enemy diatur lewat `SpawnerConfig`: `initial_spawn_interval`, `spawn_interval_decrease_every`, `spawn_interval_decrease_amount`, dan `minimum_spawn_interval`.
- Scaling jumlah enemy per spawn diatur lewat `SpawnerConfig`: `initial_spawn_count`, `spawn_count_increase_every`, `spawn_count_increase_amount`, dan `maximum_spawn_count`.
- Batas enemy hidup bersamaan diatur lewat `SpawnerConfig.maximum_alive_enemies`; default prototype adalah `50`.
- Survival win condition diatur lewat `RunConfig.survival_duration`; default prototype adalah `300` detik.
- `RunConfig.next_scene_path` disiapkan untuk pindah scene setelah menang, tetapi prototype saat ini masih boleh kosong.
- Untuk komunikasi antar sistem, pakai signal di `autoload/EventBus.gd`.
- Event `player_level_up` dipakai sebagai trigger level up; UI/upgrade system nanti bisa mendengarkan event ini.
- Untuk state global seperti HP player dan mode game, pakai `autoload/GameState.gd`.
- Hindari spawn/free node physics langsung dari callback collision. Gunakan `call_deferred()` jika mengubah scene tree dari signal physics seperti `body_entered`.
- Entity yang perlu dicari sistem lain sebaiknya memakai group, misalnya `player` dan `enemy`.
