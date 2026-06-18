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
- `scripts/gameplay/weapons/`
  Base script weapon modular, seperti `WeaponBase.gd`.
- `scripts/gameplay/pickups/`
  Resource effect pickup, seperti `HealPickupEffect`, `AddXpPickupEffect`, dan utility pickup effect.
- `scripts/ui/`
  Logic UI seperti HUD dan game over screen.
- `autoload/`
  Singleton global untuk state, event, RNG, dan run manager.
- `resources/`
  Data balancing berbentuk `.tres`, supaya angka gameplay tidak hardcoded di script.
- `upgrades/`
  Pool reward, stat upgrade weapon, talisman, utility, compatibility tag, dan runtime build manager.
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
  Menampung HUD, selection screen level-up, win screen, dan game over screen.

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
- `resources/weapons/BasicGun.tres`
  Contoh weapon `PROJECTILE` yang memakai `ProjectileWeaponDefinition`, scene `BasicGun.tscn`, dan runtime script `BasicGun.gd` berbasis `WeaponBase`.
- `resources/weapons/BeamGun.tres`
  Contoh weapon `BEAM` yang memakai `BeamWeaponDefinition`, `RayCast2D` untuk hit detection, dan `Line2D` untuk visual laser.
- `resources/weapons/AuraWeapon.tres`
  Contoh weapon `AURA` yang memakai `AuraWeaponDefinition`.
- `resources/weapons/KoalisiDadakan.tres`
  Contoh weapon `SUMMON` yang memakai `SummonWeaponDefinition`.
- `upgrades/default_reward_pool.tres`
  Pool configurable untuk weapon baru, upgrade stat weapon, talisman, utility, rarity, dan weight.
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
  Pickup HP berbasis `PickupConfig.effects`; jumlah heal drop enemy diisi dari weighted HP drop `EnemyConfig`.
- `resources/items/runner_health_pickup.tres`
  Pickup HP dummy khusus Runner; jumlah heal final tetap diisi dari weighted HP drop `EnemyConfig`.
- `resources/items/tank_health_pickup.tres`
  Pickup HP dummy khusus Tank; jumlah heal final tetap diisi dari weighted HP drop `EnemyConfig`.
- `resources/items/xp_pickup.tres`
  Pickup XP berbasis `AddXpPickupEffect` dan jumlah XP default.
- `resources/items/magnet_pickup.tres`
  Pickup Magnet berbasis `ActivateUtilityPickupEffect`.
- `resources/items/magnet_default.tres`
  Durasi, radius, pull speed, dan batch size efek Magnet.
- `resources/xp/default_xp.tres`
  XP yang dibutuhkan per level dan multiplier pertumbuhan level.

## Alur gameplay

1. `Main` memanggil `RunManager.start_run()` saat scene dibuka/reload.
2. `RunManager` reset run, mengisi seed, dan mulai menghitung survival timer.
3. `PlayerController` membaca `PlayerConfig` dan `XPConfig`, lalu menyiapkan `WeaponManager` serta `BuildManager`.
4. `EnemySpawner` membaca `SpawnerConfig` untuk area spawn dan `DifficultyManager` untuk scaling difficulty.
5. `DifficultyManager` menghitung progress dari `GameState.run_elapsed_time / GameState.run_target_time`.
6. `EnemySpawner` memilih enemy dari phase aktif, lalu memberi multiplier HP, damage, dan move speed ke enemy yang baru di-spawn.
7. `EnemyController` membaca `EnemyConfig` sebagai base stat, lalu memakai multiplier runtime dari Difficulty Manager.
8. `WeaponManager` membuat `WeaponInstance`, men-spawn `WeaponDefinition.weapon_scene`, lalu memanggil `setup(weapon_instance)` pada node weapon.
9. Weapon aktif mencari target dan memberi damage sesuai logic scene masing-masing.
10. `Projectile` atau weapon lain memanggil `take_damage()` pada enemy yang terkena.
11. Saat enemy mati, enemy men-drop `PickupItem` XP sesuai jumlah roll dan weighted value di `EnemyConfig`, lalu dapat men-drop `PickupItem` HP secara random.
12. `PickupItem` menjalankan semua `PickupEffect` di `PickupConfig.effects`, misalnya `HealPickupEffect`, `AddXpPickupEffect`, atau `ActivateUtilityPickupEffect`.
13. Jika XP player mencapai target level, `PlayerController` memanggil event `player_level_up`.
14. Selection screen meminta kandidat dari `RewardPoolConfig`, memfilter slot dan compatibility tag, menghitung rarity/weight, lalu menampilkan pilihan.
15. Player menerapkan `RewardOffer` melalui `BuildManager`, lalu game berjalan kembali.
16. Sisa XP berlebih dibawa ke level berikutnya, lalu target XP berikutnya dihitung dari `XPConfig`.
17. `PlayerHud` mendengar event HP, XP, dan survival timer dari `EventBus`.
18. Jika HP player habis sebelum survival timer selesai, `RunManager` memicu lose state dan `GameOverScreen` muncul.
19. Jika survival timer mencapai target, `RunManager` memicu win state dan `WinScreen` muncul.

## Catatan maintenance

- Untuk balancing, utamakan edit file `.tres` di `resources/`, bukan script.
- Weighted XP gem diatur di `EnemyConfig` lewat `xp_drop_values` dan `xp_drop_weights`.
- Jumlah XP gem yang keluar diatur lewat `EnemyConfig.xp_drop_rolls_min` dan `EnemyConfig.xp_drop_rolls_max`; Runner default memakai 1-2 roll dan Tank default memakai 2-3 roll.
- Weighted HP pickup diatur di `EnemyConfig` lewat `hp_drop_values` dan `hp_drop_weights`; peluang drop HP memakai `health_drop_chance`.
- Rarity/chance drop Magnet diatur lewat `EnemyConfig.magnet_drop_chance`.
- Efek Magnet hanya menarik pickup dengan `PickupConfig.magnetizable = true`; durasi, radius, pull speed, timer, dan batch activation diatur lewat `MagnetComponent` dengan data `MagnetConfig`.
- Detour pathfinding enemy diatur lewat `EnemyConfig`: `detour_path_enabled`, `detour_obstacle_collision_mask`, `detour_refresh_interval`, `detour_waypoint_margin`, dan `detour_waypoint_reached_distance`.
- Simple obstacle avoidance enemy tetap menjadi fallback dan diatur lewat `EnemyConfig`: `obstacle_avoidance_enabled`, `obstacle_avoidance_duration`, `obstacle_avoidance_weight`, `obstacle_stuck_time`, dan `obstacle_stuck_min_distance`.
- Base damage senjata player ada di `WeaponDefinition.base_damage`; upgrade stat per-weapon disimpan pada `WeaponInstance`.
- Setiap `WeaponDefinition` memiliki `compatibility_tags` dan daftar configurable `upgrade_options`.
- `BuildManager` menyimpan talisman, utility, dan modifier global yang tetap difilter berdasarkan tag weapon.
- `RewardPoolConfig` mengumpulkan kandidat valid dan melakukan roll rarity/weight; selection screen hanya merender `RewardOffer`.
- Modifier percent memakai pecahan desimal: `0.20` berarti `+20%`, dan `-0.15` berarti pengurangan `15%`.
- Key modifier yang sudah dipakai antara lain `weapon.damage`, `weapon.cooldown`, `weapon.range`, `weapon.projectile_count`, `weapon.projectile_speed`, `weapon.beam_duration`, `player.max_hp`, dan `player.move_speed`.
- Rarity weight dan multiplier diatur di `upgrades/default_reward_pool.tres`.
- Cooldown weapon memakai `WeaponDefinition.base_cooldown`; modifier cooldown memakai key `weapon.cooldown` dan nilai percent negatif untuk mempercepat serangan.
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

### Menambahkan Senjata Baru

Sistem weapon sekarang berbasis `WeaponDefinition`, `WeaponInstance`, scene weapon, dan `WeaponBase`. `PlayerController` tidak menjalankan detail serangan weapon; player hanya memiliki `WeaponHolder`, lalu `WeaponManager` men-spawn scene dari `WeaponDefinition.weapon_scene` dan memanggil `setup(weapon_instance)`.

Contoh utama saat ini adalah Basic Gun:

- Script runtime: `res://scripts/gameplay/BasicGun.gd`
- Base runtime: `res://scripts/gameplay/weapons/WeaponBase.gd`
- Scene weapon: `res://scenes/weapons/BasicGun.tscn`
- Resource weapon: `res://resources/weapons/BasicGun.tres`
- Pool reward: `res://upgrades/default_reward_pool.tres`

#### Struktur file minimal

Untuk weapon baru, buat file berikut:

- Script runtime weapon:
  `res://scripts/gameplay/weapons/MyNewWeapon.gd`
- Scene weapon:
  `res://scenes/weapons/MyNewWeapon.tscn`
- Resource weapon:
  `res://resources/weapons/MyNewWeapon.tres`

Jika weapon dapat diperoleh dari level up, masukkan resource weapon ke `weapon_definitions` pada `res://upgrades/default_reward_pool.tres`.

Catatan transisi: `BasicGun.gd`, `BeamGun.gd`, `AuraWeapon.gd`, dan `KoalisiDadakan.gd` saat ini masih berada langsung di `res://scripts/gameplay/`. Untuk weapon baru, gunakan folder `res://scripts/gameplay/weapons/` agar struktur berikutnya lebih rapi.

#### Kontrak WeaponBase

Weapon runtime baru sebaiknya extend `WeaponBase`:

```gdscript
extends "res://scripts/gameplay/weapons/WeaponBase.gd"
class_name MyNewWeapon
```

`WeaponBase` menyediakan kontrak:

- `setup(weapon_instance)`
- `_on_weapon_setup()`
- `get_owner_node()`
- `get_damage()`
- `get_cooldown()`
- `get_range()`
- `get_nearest_enemy()`

`setup(weapon_instance)` dipanggil oleh `WeaponManager`, bukan manual dari player. Jika weapon butuh inisialisasi khusus, override `_on_weapon_setup()` seperti BasicGun:

```gdscript
func _on_weapon_setup() -> void:
	attack_timer = 0.0
```

Untuk logic serangan, baca stat lewat helper base atau `weapon_instance`. Contoh pola BasicGun:

```gdscript
func _physics_process(delta: float) -> void:
	if get_owner_node() == null:
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	if attack_timer > 0.0:
		return

	var target := get_nearest_enemy()
	if target == null:
		return

	_shoot_projectiles(target)
	attack_timer = get_cooldown()
```

#### Memilih WeaponDefinition

Gunakan base `WeaponDefinition` hanya untuk data umum:

- `id`
- `display_name`
- `description`
- `icon`
- `weapon_type`
- `weapon_scene`
- `base_damage`
- `base_cooldown`
- `base_range`
- `max_level`
- `damage_per_level`
- `cooldown_reduction_per_level`

Field khusus disimpan di subclass definition sesuai tipe weapon:

- `ProjectileWeaponDefinition`
  Untuk projectile count, projectile speed, dan spread. Contoh: `resources/weapons/BasicGun.tres`.
- `BeamWeaponDefinition`
  Untuk beam duration, tick interval, width, dan pierce. Contoh: `resources/weapons/BeamGun.tres`.
- `AuraWeaponDefinition`
  Untuk aura radius, tick interval, slow, dan knockback. Contoh: `resources/weapons/AuraWeapon.tres`.
- `SummonWeaponDefinition`
  Untuk minion scene, lifetime, damage multiplier, dan max active minions. Contoh: `resources/weapons/KoalisiDadakan.tres`.
- `AreaWeaponDefinition`
  Disiapkan untuk weapon area damage.
- `MeleeWeaponDefinition`
  Disiapkan untuk weapon melee.

Untuk weapon projectile seperti BasicGun, buat resource dengan script:

- `res://scripts/gameplay/ProjectileWeaponDefinition.gd`

Isi field penting:

- `id = "my_new_weapon"`
- `display_name = "My New Weapon"`
- `weapon_type = PROJECTILE`
- `weapon_scene = res://scenes/weapons/MyNewWeapon.tscn`
- `base_damage`
- `base_cooldown`
- `base_range`
- `max_level`
- `damage_per_level`
- `cooldown_reduction_per_level`
- `base_projectile_count`
- `projectile_count_per_level`
- `base_projectile_speed`
- `projectile_speed_per_level`
- `spread_angle_degrees`

#### Menghubungkan resource ke scene

`WeaponManager` hanya tahu resource dan scene. Hubungannya ada di field:

```text
WeaponDefinition.weapon_scene = res://scenes/weapons/MyNewWeapon.tscn
```

Saat weapon ditambahkan, `WeaponManager.add_weapon()` akan:

1. Mengecek `weapon_definition.id`.
2. Jika weapon sudah dimiliki, memanggil `upgrade_weapon()`.
3. Jika belum dimiliki, mengecek `max_weapon_slots`.
4. Membuat `WeaponInstance`.
5. Instantiate `weapon_definition.weapon_scene`.
6. Menambahkan scene weapon ke `Player/WeaponHolder`.
7. Memanggil `weapon_node.setup(weapon_instance)`.

Karena itu scene weapon harus punya script dengan method `setup()` dari `WeaponBase`.

#### Starting weapon vs weapon reward

Starting weapon adalah pilihan senjata sebelum run dimulai. `Main.gd` mengambil pilihan dari:

- `starting_weapon_options` jika diisi dari Inspector.
- Semua resource valid di `res://resources/weapons/` jika `starting_weapon_options` kosong.
- `DEFAULT_STARTING_WEAPONS` sebagai fallback terakhir.

Artinya, untuk muncul sebagai starting weapon, weapon baru cukup punya resource valid di `res://resources/weapons/` dengan `id` tidak kosong dan `weapon_scene` terisi.

Weapon baru harus didaftarkan pada `weapon_definitions` di `res://upgrades/default_reward_pool.tres`. Upgrade weapon berasal dari `upgrade_options` milik resource weapon tersebut, sehingga RNG tidak dapat memilih stat dari jenis weapon lain. Jika empat slot penuh, kandidat weapon baru otomatis dibuang.

#### Checklist pengujian weapon baru

Setelah menambahkan weapon baru, cek:

- Project bisa load:
  `godot --headless --path . --quit`
- Resource weapon muncul di pilihan starting weapon.
- Memilih weapon saat start menambahkan scene weapon ke `Player/WeaponHolder`.
- Script weapon menerima `setup(weapon_instance)`.
- Weapon dapat mencari target tanpa logic serangan di `PlayerController`.
- Damage berubah sesuai `base_damage` dan `damage_per_level`.
- Cooldown berubah sesuai `base_cooldown`, `cooldown_reduction_per_level`, dan modifier `weapon.cooldown`.
- Range memakai `base_range` dan modifier `weapon.range` jika ada.
- Jika weapon projectile, projectile count, speed, dan spread dibaca dari `ProjectileWeaponDefinition`.
- Weapon terdaftar muncul dari `default_reward_pool.tres` saat masih ada slot.
- Upgrade stat yang muncul hanya berasal dari `upgrade_options` weapon yang dimiliki.
- Saat `max_weapon_slots` penuh, weapon baru tidak ditambahkan.
