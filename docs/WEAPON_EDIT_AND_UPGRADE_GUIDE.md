# Weapon Edit and Upgrade Guide

Dokumen ini menjelaskan struktur weapon berdasarkan kondisi kode project saat ini. Fokusnya adalah menentukan file mana yang perlu diedit saat mengubah data, logic, upgrade, dan modifier weapon tanpa memutus resource atau alur gameplay.

## 1. Gambaran Arsitektur Weapon

Sistem weapon saat ini berbasis empat bagian utama:

- `WeaponDefinition`
  Resource data dasar weapon. File `.tres` weapon di `res://resources/weapons/` memakai script definition ini atau subclass-nya.
- `WeaponInstance`
  Object runtime yang menyimpan `definition`, `level`, `owner_node`, dan `ability_manager`. Semua hitungan stat runtime utama dilakukan di sini.
- `WeaponManager`
  Manager milik player yang menambah weapon, upgrade weapon jika ID sudah dimiliki, mengecek slot maksimal, dan spawn scene weapon.
- Scene/script weapon
  Node weapon aktual di `WeaponHolder`. Script weapon menjalankan logic serangan masing-masing, misalnya projectile, beam, aura, atau summon.

Alur penting:

1. `Main.gd` memilih resource weapon awal dari starting weapon menu.
2. `PlayerController.equip_starting_weapon()` mengirim resource weapon ke `WeaponManager.add_weapon()`.
3. `WeaponManager` membuat `WeaponInstance`.
4. `WeaponManager` instantiate `WeaponDefinition.weapon_scene`.
5. Scene weapon ditambahkan ke `Player/WeaponHolder`.
6. `WeaponManager` memanggil `weapon_node.setup(weapon_instance)`.
7. `WeaponBase.setup()` menyimpan instance dan memanggil `_on_weapon_setup()`.
8. Script weapon membaca owner/stat lewat helper base atau `WeaponInstance`, lalu menjalankan logic serangan sendiri.

Weapon aktif saat ini:

| Weapon | Resource | Scene | Runtime script | Definition script |
| --- | --- | --- | --- | --- |
| Basic Gun | `res://resources/weapons/BasicGun.tres` | `res://scenes/weapons/BasicGun.tscn` | `res://scripts/gameplay/BasicGun.gd` | `ProjectileWeaponDefinition.gd` |
| Beam Gun | `res://resources/weapons/BeamGun.tres` | `res://scenes/weapons/BeamGun.tscn` | `res://scripts/gameplay/BeamGun.gd` | `BeamWeaponDefinition.gd` |
| Frost Aura | `res://resources/weapons/AuraWeapon.tres` | `res://scenes/weapons/AuraWeapon.tscn` | `res://scripts/gameplay/AuraWeapon.gd` | `AuraWeaponDefinition.gd` |
| Koalisi Dadakan | `res://resources/weapons/KoalisiDadakan.tres` | `res://scenes/weapons/KoalisiDadakan.tscn` | `res://scripts/gameplay/KoalisiDadakan.gd` | `SummonWeaponDefinition.gd` |

## 2. Alur Data Weapon

`WeaponDefinition` adalah sumber data dasar:

- `id`
- `display_name`
- `description`
- `weapon_type`
- `weapon_scene`
- `base_damage`
- `base_cooldown`
- `base_range`
- `max_level`
- `damage_per_level`
- `cooldown_reduction_per_level`

Field ini didefinisikan di:

- `res://scripts/gameplay/WeaponDefinition.gd`

Resource `.tres` mengisi nilai konkret per weapon:

- `res://resources/weapons/BasicGun.tres`
- `res://resources/weapons/BeamGun.tres`
- `res://resources/weapons/AuraWeapon.tres`
- `res://resources/weapons/KoalisiDadakan.tres`

`WeaponInstance` di:

- `res://scripts/gameplay/WeaponInstance.gd`

bertugas menghitung stat runtime:

- `get_damage()`
- `get_cooldown()`
- `get_attack_range()`
- `get_projectile_count()`
- `get_projectile_speed()`
- `get_beam_duration()`
- `get_beam_tick_interval()`
- `get_beam_width()`

`WeaponBase` di:

- `res://scripts/gameplay/weapons/WeaponBase.gd`

menyediakan helper untuk script weapon:

- `get_owner_node()`
- `get_damage()`
- `get_cooldown()`
- `get_range()`
- `get_nearest_enemy()`

Script weapon sebaiknya membaca stat umum lewat helper ini agar level dan ability modifier tetap ikut terhitung.

## 3. Lokasi File untuk Mengubah Stat

### Damage

Ubah nilai dasar di resource weapon:

- `resources/weapons/BasicGun.tres`: `base_damage`
- `resources/weapons/BeamGun.tres`: `base_damage`
- `resources/weapons/AuraWeapon.tres`: `base_damage`
- `resources/weapons/KoalisiDadakan.tres`: `base_damage` jika ingin eksplisit; saat ini tidak ditulis di file sehingga memakai default `10.0` dari `WeaponDefinition.gd`

Hitungan runtime:

- `WeaponInstance.get_damage()`

Rumus saat ini:

```text
final_damage = apply_modifiers(base_damage + damage_per_level * (level - 1), "weapon.damage")
```

### Cooldown

Ubah nilai dasar di resource weapon:

- `base_cooldown`
- `cooldown_reduction_per_level`

Hitungan runtime:

- `WeaponInstance.get_cooldown()`

Rumus saat ini:

```text
cooldown = max(0.05, base_cooldown - cooldown_reduction_per_level * (level - 1))
final_cooldown = max(0.05, apply_modifiers(cooldown, "weapon.cooldown"))
```

Catatan penting:

- Untuk Basic Gun, cooldown adalah interval tembak.
- Untuk Beam Gun, cooldown dipakai setelah beam selesai.
- Untuk AuraWeapon, runtime saat ini memakai `get_cooldown()` sebagai interval tick aura.
- Untuk KoalisiDadakan, runtime saat ini memakai `get_cooldown()` sebagai interval summon.

### Range

Ubah di resource weapon:

- `base_range`

Hitungan runtime:

- `WeaponInstance.get_attack_range()`
- `WeaponBase.get_range()`

Modifier ability memakai key:

- `weapon.range`

Catatan: belum ada ability `.tres` aktif yang memakai `weapon.range`, tetapi `WeaponInstance` sudah mendukungnya.

### Level Maksimal

Ubah di resource weapon:

- `max_level`

Dipakai oleh:

- `WeaponInstance.can_upgrade()`
- `WeaponManager.can_offer_weapon()`
- `WeaponManager.get_offer_context()`
- `AbilityPoolConfig._can_offer_weapon_reward()`

Jika `max_level` tercapai, reward weapon yang sama tidak akan ditawarkan lagi.

### Peningkatan Stat Per Level

Field umum:

- `damage_per_level`
- `cooldown_reduction_per_level`

Field projectile:

- `projectile_count_per_level`
- `projectile_speed_per_level`

Field beam:

- `beam_duration_per_level`
- `beam_tick_interval_reduction_per_level`

Field aura:

- `aura_radius_per_level`

Field summon:

- Saat ini belum ada `max_active_minions_per_level`, `minion_lifetime_per_level`, atau field sejenis. Koalisi Dadakan hanya memakai level untuk damage dan cooldown umum melalui `WeaponInstance`.

## 4. Konfigurasi Per Jenis Weapon

### Projectile

Definition script:

- `res://scripts/gameplay/ProjectileWeaponDefinition.gd`

Resource aktif:

- `res://resources/weapons/BasicGun.tres`

Field khusus:

- `base_projectile_count`
- `projectile_count_per_level`
- `base_projectile_speed`
- `projectile_speed_per_level`
- `spread_angle_degrees`

Runtime:

- `res://scripts/gameplay/BasicGun.gd`

Scene:

- `res://scenes/weapons/BasicGun.tscn`

Projectile scene:

- `res://scenes/entities/Projectile.tscn`

### Beam

Definition script:

- `res://scripts/gameplay/BeamWeaponDefinition.gd`

Resource aktif:

- `res://resources/weapons/BeamGun.tres`

Field khusus:

- `beam_duration`
- `beam_duration_per_level`
- `beam_tick_interval`
- `beam_tick_interval_reduction_per_level`
- `beam_width`
- `pierce_count`

Runtime:

- `res://scripts/gameplay/BeamGun.gd`

Catatan aktual:

- `beam_duration`, `beam_tick_interval`, dan `beam_width` dipakai.
- `pierce_count` sudah ada di definition/resource, tetapi runtime `BeamGun.gd` saat ini hanya merusak collider pertama dari `RayCast2D`; pierce belum benar-benar diterapkan.

### Aura

Definition script:

- `res://scripts/gameplay/AuraWeaponDefinition.gd`

Resource aktif:

- `res://resources/weapons/AuraWeapon.tres`

Field khusus:

- `aura_radius`
- `aura_radius_per_level`
- `slow_percent`
- `slow_duration`
- `tick_interval`
- `tick_damage_multiplier`
- `enable_knockback`

Runtime:

- `res://scripts/gameplay/AuraWeapon.gd`

Catatan aktual:

- Radius runtime dihitung dari `get_range()` plus `aura_radius_per_level`, jadi nilai yang efektif untuk radius dasar adalah `base_range`.
- `aura_radius` masih ada di definition/resource dan menjadi fallback saat `weapon_instance` belum ada.
- Tick runtime memakai `get_cooldown()`, jadi nilai efektif interval tick adalah `base_cooldown`, bukan `tick_interval`.
- Damage tick memakai `get_damage() * tick_damage_multiplier`.
- Slow dan knockback masih dibaca langsung dari `AuraWeaponDefinition`.

### Summon

Definition script:

- `res://scripts/gameplay/SummonWeaponDefinition.gd`

Resource aktif:

- `res://resources/weapons/KoalisiDadakan.tres`

Field khusus:

- `minion_name`
- `minion_scene`
- `minion_projectile_scene`
- `minion_damage_multiplier`
- `max_active_minions`
- `summon_interval`
- `minion_lifetime`
- `minion_attack_cooldown`
- `minion_attack_range`
- `minion_projectile_speed`
- `minion_orbit_radius`

Runtime weapon:

- `res://scripts/gameplay/KoalisiDadakan.gd`

Runtime minion:

- `res://scripts/gameplay/Simpatisan.gd`

Scene minion:

- `res://scenes/entities/Simpatisan.tscn`

Catatan aktual:

- Jumlah summon aktif memakai `max_active_minions`.
- Interval summon runtime memakai `get_cooldown()`, jadi nilai efektifnya `base_cooldown`, bukan `summon_interval`.
- Range serangan minion yang dikirim dari weapon memakai `get_range()`, jadi nilai efektifnya `base_range`, bukan `minion_attack_range`.
- Damage minion memakai `get_damage() * minion_damage_multiplier`.
- Lifetime, attack cooldown, projectile speed, dan orbit radius minion masih dibaca dari `SummonWeaponDefinition`.

## 5. Cara Mengubah Logic Serangan

Logic serangan tidak berada di `PlayerController` atau `WeaponManager`. Ubah script runtime weapon sesuai jenis:

- Projectile: `res://scripts/gameplay/BasicGun.gd`
- Beam: `res://scripts/gameplay/BeamGun.gd`
- Aura: `res://scripts/gameplay/AuraWeapon.gd`
- Summon controller: `res://scripts/gameplay/KoalisiDadakan.gd`
- Summon minion behavior: `res://scripts/gameplay/Simpatisan.gd`

Aturan aman:

- Tetap extend `WeaponBase` untuk weapon runtime.
- Jangan override `setup()` kecuali benar-benar perlu; gunakan `_on_weapon_setup()`.
- Ambil owner lewat `get_owner_node()`.
- Ambil damage lewat `get_damage()`.
- Ambil cooldown lewat `get_cooldown()`.
- Ambil range lewat `get_range()`.
- Untuk stat khusus tipe weapon, baca dari `weapon_instance` atau definition dengan hati-hati.
- Jangan cache damage, cooldown, range, projectile count, atau stat lain secara permanen jika stat bisa berubah karena level/ability modifier.

## 6. Cara Upgrade Weapon Berjalan

Upgrade weapon terjadi lewat reward ability yang memiliki `weapon_definition`.

File terkait:

- `res://abilities/definitions/weapons/basic_gun_reward.tres`
- `res://abilities/definitions/weapons/beam_gun_reward.tres`
- `res://abilities/default_ability_pool.tres`
- `res://abilities/scripts/AbilityDefinition.gd`
- `res://abilities/scripts/AbilityPoolConfig.gd`
- `res://scripts/ui/AbilitySelectionScreen.gd`
- `res://scripts/gameplay/PlayerController.gd`
- `res://scripts/gameplay/WeaponManager.gd`
- `res://scripts/gameplay/WeaponInstance.gd`

Alur runtime:

1. Player naik level di `PlayerController._check_level_up()`.
2. `EventBus.player_level_up` dipancarkan.
3. `AbilitySelectionScreen` menerima event dan memanggil `AbilityPoolConfig.roll_offers()`.
4. `AbilitySelectionScreen` mengirim `weapon_context` dari `PlayerController.get_weapon_offer_context()`.
5. `WeaponManager.get_offer_context()` mengembalikan weapon yang dimiliki, level saat ini, max level, dan apakah slot masih ada.
6. `AbilityPoolConfig._can_offer_weapon_reward()` menyaring reward weapon:
   - Jika weapon sudah dimiliki, reward hanya valid jika level belum mencapai `max_level`.
   - Jika weapon belum dimiliki, reward hanya valid jika `can_add_weapon` masih true.
7. Saat player memilih reward, `EventBus.ability_selected` dikirim.
8. `PlayerController.add_ability_to_manager()` mendeteksi `ability.is_weapon_reward()`.
9. Reward weapon tidak ditambahkan ke `AbilityManager`; langsung memanggil `WeaponManager.add_weapon(weapon_definition)`.
10. `WeaponManager.add_weapon()`:
    - Jika ID belum dimiliki: spawn weapon baru.
    - Jika ID sudah dimiliki: memanggil `upgrade_weapon()`.
11. `WeaponInstance.upgrade()` menaikkan `level` sebanyak 1 selama belum mencapai `max_level`.

## 7. Ability Modifier dan Pengaruhnya ke Weapon

Ability stat biasa masuk ke:

- `res://abilities/scripts/AbilityManager.gd`

Data ability ada di:

- `res://abilities/definitions/`

Setiap ability dapat memiliki satu atau lebih `AbilityEffect`:

- `res://abilities/scripts/AbilityEffect.gd`

Field penting:

- `modifier_key`
- `value`
- `value_type`
- `stack_mode`

Modifier yang benar-benar dipakai oleh `WeaponInstance` saat ini:

| Modifier key | Dipakai oleh | Tipe umum |
| --- | --- | --- |
| `weapon.damage` | `get_damage()` | Percent atau flat, tergantung effect |
| `weapon.cooldown` | `get_cooldown()` | Biasanya percent negatif untuk cooldown lebih cepat |
| `weapon.projectile_count` | `get_projectile_count()` | Flat |
| `weapon.projectile_speed` | `get_projectile_speed()` | Percent atau flat |
| `weapon.range` | `get_attack_range()` | Percent atau flat |
| `weapon.beam_duration` | `get_beam_duration()` | Percent atau flat |

Ability aktif yang memakai modifier weapon saat ini:

- `abilities/definitions/offense/bullet_damage.tres`: `weapon.damage`
- `abilities/definitions/utility/sharp_bullet.tres`: `weapon.damage`
- `abilities/definitions/offense/attack_speed.tres`: `weapon.cooldown`
- `abilities/definitions/offense/rapid_chamber.tres`: `weapon.cooldown`
- `abilities/definitions/offense/projectile_count.tres`: `weapon.projectile_count`
- `abilities/definitions/offense/double_tap.tres`: `weapon.projectile_count`

Catatan:

- `AbilityEffect.gd` mengenal label untuk `weapon.aura_radius` dan `weapon.summon_count`, tetapi `WeaponInstance` dan runtime weapon saat ini belum memakai key tersebut.
- Jika ingin ability baru memengaruhi aura radius atau jumlah summon, perlu menambah pembacaan modifier di runtime/instance yang sesuai.
- `AbilityManager.apply_modifiers(base_value, key)` menambahkan flat modifier dulu, lalu mengalikan percent modifier.

## 8. Starting Weapon dan Slot Weapon

Starting weapon diatur lewat:

- `res://scripts/gameplay/Main.gd`
- `res://scenes/entities/Player.tscn`

`Main.gd` mengambil opsi starting weapon dari:

1. `starting_weapon_options` pada `Main.gd` jika diisi dari Inspector.
2. Semua resource valid di `res://resources/weapons/`.
3. `DEFAULT_STARTING_WEAPONS` jika folder resource gagal/kosong.

`Main.gd` memfilter resource valid dengan syarat:

- Resource bukan null.
- Resource adalah `WeaponDefinition`.
- `id` tidak kosong.
- `weapon_scene` tidak null.

Slot maksimal weapon ada di:

- `Player.tscn`: property `max_weapon_slots = 4`
- `PlayerController.gd`: export `max_weapon_slots`
- `WeaponManager.max_weapon_slots`

## 9. Cara Menambah atau Mengubah Upgrade Weapon

Untuk membuat weapon muncul sebagai reward level up:

1. Pastikan resource weapon ada di `res://resources/weapons/`.
2. Buat ability reward di `res://abilities/definitions/weapons/`.
3. Isi `weapon_definition` dengan resource weapon.
4. Isi `id`, `display_name`, `description`, `rarity`, `stackable`, dan `max_stack`.
5. Daftarkan ability reward ke `res://abilities/default_ability_pool.tres`.

Untuk mengubah upgrade level weapon:

- Edit resource weapon:
  - `max_level`
  - `damage_per_level`
  - `cooldown_reduction_per_level`
  - field per-level khusus seperti `projectile_count_per_level`, `projectile_speed_per_level`, `beam_duration_per_level`, `beam_tick_interval_reduction_per_level`, atau `aura_radius_per_level`

Untuk mengubah apakah reward weapon masih bisa muncul:

- `max_level` di resource weapon.
- `max_stack` di ability reward sebaiknya selaras dengan `max_level`.
- `AbilityPoolConfig._can_offer_weapon_reward()` yang menentukan filtering berdasarkan level dan slot.

## 10. Contoh Perubahan Sederhana

### Menaikkan Damage Basic Gun

Edit:

- `res://resources/weapons/BasicGun.tres`

Field:

- `base_damage`
- `damage_per_level`

Tidak perlu mengubah script jika behavior tembakan tetap sama.

### Membuat Basic Gun Menembak Lebih Banyak Projectile

Edit:

- `res://resources/weapons/BasicGun.tres`

Field:

- `base_projectile_count`
- `projectile_count_per_level`
- `spread_angle_degrees`

Runtime yang memakai field ini:

- `res://scripts/gameplay/BasicGun.gd`
- `WeaponInstance.get_projectile_count()`

### Memperpanjang Durasi Beam

Edit:

- `res://resources/weapons/BeamGun.tres`

Field:

- `beam_duration`
- `beam_duration_per_level`

Runtime yang memakai field ini:

- `WeaponInstance.get_beam_duration()`
- `res://scripts/gameplay/BeamGun.gd`

### Memperbesar Aura

Edit nilai efektif radius di:

- `res://resources/weapons/AuraWeapon.tres`

Field:

- `base_range`
- `aura_radius_per_level`

Catatan: `aura_radius` masih ada, tetapi runtime saat ini memakai `base_range` sebagai radius dasar.

### Mengubah Interval Tick Aura

Edit:

- `res://resources/weapons/AuraWeapon.tres`

Field efektif:

- `base_cooldown`

Catatan: `tick_interval` masih ada di definition, tetapi runtime saat ini memakai `get_cooldown()`.

### Menambah Jumlah Minion Koalisi Dadakan

Edit:

- `res://resources/weapons/KoalisiDadakan.tres`

Field:

- `max_active_minions`

Runtime yang memakai field ini:

- `res://scripts/gameplay/KoalisiDadakan.gd`

### Mengubah Damage Minion

Edit:

- `res://resources/weapons/KoalisiDadakan.tres`

Field:

- `base_damage`
- `damage_per_level`
- `minion_damage_multiplier`

Rumus runtime:

```text
minion_damage = get_damage() * minion_damage_multiplier
```

### Menambahkan Ability Damage Weapon Baru

Buat atau edit ability di:

- `res://abilities/definitions/offense/`

Isi `AbilityEffect`:

- `modifier_key = &"weapon.damage"`
- `value_type = PERCENT`
- `value = 0.2` untuk +20%

Daftarkan ability ke:

- `res://abilities/default_ability_pool.tres`

## 11. Bagian Aman Diedit

Aman diedit untuk balancing:

- `res://resources/weapons/*.tres`
- `res://abilities/definitions/**/*.tres`
- `res://abilities/default_ability_pool.tres`
- `res://scenes/entities/Player.tscn` hanya untuk `starting_weapon` dan `max_weapon_slots`
- `res://scripts/gameplay/Main.gd` hanya jika mengubah fallback/default starting weapon list

Aman diedit untuk behavior weapon:

- `res://scripts/gameplay/BasicGun.gd`
- `res://scripts/gameplay/BeamGun.gd`
- `res://scripts/gameplay/AuraWeapon.gd`
- `res://scripts/gameplay/KoalisiDadakan.gd`
- `res://scripts/gameplay/Simpatisan.gd`
- Scene weapon di `res://scenes/weapons/` jika perlu node khusus seperti `RayCast2D`, `Area2D`, `Line2D`, atau visual.

Sebaiknya tidak diubah langsung kecuali memang mengubah arsitektur:

- `res://scripts/gameplay/WeaponManager.gd`
- `res://scripts/gameplay/WeaponInstance.gd`
- `res://scripts/gameplay/weapons/WeaponBase.gd`
- `res://scripts/gameplay/PlayerController.gd`
- `res://abilities/scripts/AbilityManager.gd`
- `res://abilities/scripts/AbilityPoolConfig.gd`

Alasannya: file ini adalah kontrak antar sistem. Perubahan kecil bisa memengaruhi semua weapon, level-up, slot weapon, dan modifier ability.

## 12. Checklist Pengujian Setelah Weapon Diubah

Jalankan minimal:

```powershell
godot --headless --path . --quit
godot --headless --path . scenes/Main.tscn --quit
```

Checklist manual:

- Starting weapon menu tetap muncul.
- Weapon yang diubah muncul di pilihan starting weapon jika resource valid.
- Memilih starting weapon menambahkan node ke `Player/WeaponHolder`.
- Weapon menyerang tanpa error.
- Damage berubah sesuai `base_damage` dan `damage_per_level`.
- Cooldown berubah sesuai `base_cooldown`, `cooldown_reduction_per_level`, dan ability `weapon.cooldown`.
- Range berubah sesuai `base_range` dan ability `weapon.range` jika ada.
- Reward weapon yang sama menaikkan level, bukan spawn duplikat.
- Reward weapon tidak muncul lagi saat mencapai `max_level`.
- Saat slot weapon penuh, reward weapon baru tidak ditawarkan.
- Ability modifier damage/cooldown/projectile count tetap berdampak saat run sedang berjalan.
- Tidak ada error missing dependency di output Godot.

## 13. Risiko Umum

### Stat Tidak Ter-update

Penyebab umum:

- Script weapon menyimpan damage/cooldown/range sebagai cache permanen.
- Logic membaca langsung dari resource `.tres`, bukan dari `get_damage()`, `get_cooldown()`, atau `get_range()`.
- Ability memakai `modifier_key` yang belum dibaca oleh `WeaponInstance` atau runtime weapon.

### Resource Rusak atau Missing Dependency

Penyebab umum:

- `weapon_scene` mengarah ke scene yang dihapus/rename.
- Scene weapon memakai script yang dipindah tanpa update path.
- Ability reward mengarah ke resource weapon yang sudah dihapus.
- `default_ability_pool.tres` masih memuat reward yang sudah dihapus.

### Reference Scene Terputus

Penyebab umum:

- Mengubah nama node child yang dipakai `@onready`, seperti `RayCast2D`, `Line2D`, `Hitbox`, atau `CollisionShape2D`.
- Menghapus node scene yang dibutuhkan script runtime.

### Upgrade Tidak Muncul

Penyebab umum:

- Ability reward belum dimasukkan ke `default_ability_pool.tres`.
- `weapon_definition` di ability reward null.
- `max_level` sudah tercapai.
- `max_weapon_slots` penuh.
- `id` weapon kosong atau sama dengan weapon lain secara tidak sengaja.

### Gameplay Berubah Tanpa Sengaja

Penyebab umum:

- Mengubah field umum seperti `base_cooldown` pada Aura/Summon tanpa sadar bahwa field itu dipakai sebagai tick/summon interval.
- Mengubah `base_range` pada Aura tanpa sadar bahwa field itu sekarang menjadi radius aura efektif.
- Mengubah `base_range` pada Summon tanpa sadar bahwa field itu menjadi range serangan minion yang dikirim dari `KoalisiDadakan.gd`.

## 14. Technical Debt dan Inkonsistensi Saat Ini

Beberapa hal yang perlu dicatat sebelum refactor berikutnya:

- `BasicGun.gd`, `BeamGun.gd`, `AuraWeapon.gd`, dan `KoalisiDadakan.gd` masih berada di `res://scripts/gameplay/`, bukan `res://scripts/gameplay/weapons/`.
- `AuraWeaponDefinition` memiliki `aura_radius` dan `tick_interval`, tetapi runtime efektif memakai `base_range` dan `base_cooldown`.
- `SummonWeaponDefinition` memiliki `summon_interval` dan `minion_attack_range`, tetapi runtime efektif memakai `base_cooldown` dan `base_range`.
- `SummonWeaponDefinition` belum memiliki field per-level untuk jumlah minion, lifetime, attack cooldown, projectile speed, atau orbit radius.
- `BeamWeaponDefinition.pierce_count` belum dipakai oleh `BeamGun.gd`.
- `AbilityEffect.gd` mengenal label `weapon.aura_radius` dan `weapon.summon_count`, tetapi belum ada logic runtime yang memakai modifier key tersebut.
- `AbilityManager.gd` hanya punya const helper untuk sebagian key weapon: damage, cooldown, projectile count. Key seperti range, projectile speed, dan beam duration tetap bisa dipakai lewat `apply_modifiers()`, tetapi belum punya helper khusus.
- `PlayerController.gd` masih menyimpan beberapa modifier legacy seperti `flat_damage_modifier`, `attack_interval_modifier`, dan helper lama. Weapon modern sekarang memakai `AbilityManager` lewat `WeaponInstance`.
- Koalisi Dadakan saat ini tidak memiliki reward ability di `default_ability_pool.tres`, sehingga bisa muncul sebagai starting weapon dari folder resource, tetapi tidak muncul sebagai reward level-up kecuali dibuatkan ability reward.
- Aura Weapon juga tidak memiliki reward ability di `default_ability_pool.tres`.

## 15. Ringkasan Lokasi Edit Cepat

| Kebutuhan | File utama |
| --- | --- |
| Damage/cooldown/range/max level | `res://resources/weapons/<Weapon>.tres` |
| Scaling damage/cooldown per level | `res://resources/weapons/<Weapon>.tres` |
| Projectile count/speed/spread | `res://resources/weapons/BasicGun.tres` |
| Beam duration/tick/width | `res://resources/weapons/BeamGun.tres` |
| Aura radius/tick/slow/damage tick | `res://resources/weapons/AuraWeapon.tres` |
| Summon count/lifetime/minion damage | `res://resources/weapons/KoalisiDadakan.tres` |
| Projectile attack behavior | `res://scripts/gameplay/BasicGun.gd` |
| Beam attack behavior | `res://scripts/gameplay/BeamGun.gd` |
| Aura attack behavior | `res://scripts/gameplay/AuraWeapon.gd` |
| Summon spawning behavior | `res://scripts/gameplay/KoalisiDadakan.gd` |
| Minion movement/attack behavior | `res://scripts/gameplay/Simpatisan.gd` |
| Reward weapon | `res://abilities/definitions/weapons/*.tres` |
| Ability pool | `res://abilities/default_ability_pool.tres` |
| Stat modifier ability | `res://abilities/definitions/**/*.tres` |
| Modifier calculation | `res://abilities/scripts/AbilityManager.gd` |
| Runtime weapon stat calculation | `res://scripts/gameplay/WeaponInstance.gd` |
| Add/upgrade/spawn weapon | `res://scripts/gameplay/WeaponManager.gd` |
