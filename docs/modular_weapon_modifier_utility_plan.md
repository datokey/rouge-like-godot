# Refactor Modular Weapon, Modifier, dan Utility

Dokumen ini adalah roadmap bertahap untuk merapikan sistem weapon, weapon modifier, dan utility agar lebih data-driven. Tujuannya: menambah weapon baru, modifier baru, atau utility baru cukup lewat resource/config/scene, dengan perubahan minimal ke kode utama.

## Target Arsitektur

### Weapon

Weapon runtime berjalan dari scene weapon, bukan dari `PlayerController`.

Struktur ideal:

```text
WeaponDefinition
- data umum weapon
- menunjuk ke weapon_scene

WeaponInstance
- data runtime weapon
- level
- reference ke WeaponDefinition

WeaponManager
- menyimpan weapon aktif
- add/upgrade weapon
- max slot
- spawn weapon_scene

WeaponBase
- base script semua scene weapon
- setup(weapon_instance)
- helper akses owner, stat, modifier
```

### Modifier

Modifier tidak lagi bergantung pada enum yang harus diedit setiap kali menambah efek baru.

Struktur ideal:

```text
AbilityEffect
- modifier_key: StringName
- value: float
- value_type: FLAT / PERCENT
- stack_mode: ADD / MULTIPLY / OVERRIDE

AbilityManager
- menyimpan semua modifier aktif
- query modifier secara generic:
  get_flat_modifier("weapon.damage")
  get_percent_modifier("weapon.cooldown")
```

### Utility

Utility seperti Magnet tidak ditanam di `PlayerController`.

Struktur ideal:

```text
Player
- PlayerController.gd
- MagnetComponent
- ShieldComponent
- DashComponent
- WeaponHolder

PickupItem
- membaca PickupConfig
- menjalankan satu atau lebih PickupEffect
```

## Peta Folder Dan Penempatan File

Gunakan peta ini saat membuat file baru. Jika folder belum ada, buat foldernya dulu.

```text
res://scripts/gameplay/
- Script gameplay umum yang sudah ada.
- Contoh: PlayerController.gd, WeaponManager.gd, WeaponInstance.gd.

res://scripts/gameplay/weapons/
- Script base dan script logic khusus weapon.
- Buat folder ini jika belum ada.
- Contoh:
  - WeaponBase.gd
  - BasicGun.gd
  - BeamGun.gd
  - AuraWeapon.gd
  - MyNewWeapon.gd

res://scripts/gameplay/weapon_definitions/
- Script Resource definition khusus tipe weapon.
- Buat folder ini jika ingin memisahkan definition dari script runtime weapon.
- Contoh:
  - WeaponDefinition.gd
  - ProjectileWeaponDefinition.gd
  - BeamWeaponDefinition.gd
  - AuraWeaponDefinition.gd
  - SummonWeaponDefinition.gd
  - AreaWeaponDefinition.gd
  - MeleeWeaponDefinition.gd

res://scenes/weapons/
- Scene weapon yang di-spawn oleh WeaponManager.
- Semua WeaponDefinition.weapon_scene harus menunjuk ke scene di sini.
- Contoh:
  - BasicGun.tscn
  - BeamGun.tscn
  - AuraWeapon.tscn
  - KoalisiDadakan.tscn
  - MyNewWeapon.tscn

res://resources/weapons/
- Resource .tres untuk data weapon.
- Starting weapon otomatis discan dari folder ini.
- Contoh:
  - BasicGun.tres
  - BeamGun.tres
  - AuraWeapon.tres
  - KoalisiDadakan.tres
  - MyNewWeapon.tres

res://abilities/scripts/
- Script Resource dan manager untuk ability/modifier.
- Contoh:
  - AbilityDefinition.gd
  - AbilityEffect.gd
  - AbilityManager.gd
  - AbilityPoolConfig.gd
  - AbilityModifierConfig.gd

res://abilities/definitions/
- Resource .tres ability yang muncul saat level up.
- Pisahkan berdasarkan kategori.
- Contoh:
  - offense/
  - defense/
  - utility/
  - survival/
  - weapons/

res://abilities/definitions/weapons/
- Ability reward untuk membuka atau upgrade weapon.
- Contoh:
  - basic_gun_reward.tres
  - beam_gun_reward.tres
  - my_new_weapon_reward.tres

res://resources/items/
- Resource pickup/item.
- Contoh:
  - health_pickup.tres
  - xp_pickup.tres
  - magnet_pickup.tres
  - shield_pickup.tres

res://scripts/gameplay/pickups/
- Script Resource effect pickup.
- Buat folder ini jika PickupEffect sudah dipisah.
- Contoh:
  - PickupEffect.gd
  - HealPickupEffect.gd
  - AddXpPickupEffect.gd
  - ActivateUtilityPickupEffect.gd

res://scripts/gameplay/components/
- Component player/utility.
- Buat folder ini jika mulai memindahkan utility dari PlayerController.
- Contoh:
  - MagnetComponent.gd
  - ShieldComponent.gd
  - DashComponent.gd

res://scenes/entities/
- Entity gameplay seperti player, enemy, projectile, minion, pickup.
- Contoh:
  - Player.tscn
  - Projectile.tscn
  - PickupItem.tscn
  - Simpatisan.tscn
```

### Aturan Penamaan

- Script class memakai `PascalCase`: `BeamGun.gd`, `MagnetComponent.gd`.
- Resource weapon memakai nama weapon: `BeamGun.tres`, `KoalisiDadakan.tres`.
- Scene weapon memakai nama weapon: `BeamGun.tscn`, `KoalisiDadakan.tscn`.
- Ability reward weapon memakai snake case: `beam_gun_reward.tres`.
- `id` resource memakai snake case: `beam_gun`, `koalisi_dadakan`.
- Jangan memakai spasi pada nama file. Spasi boleh dipakai di `display_name`.

### Checklist Lokasi Saat Membuat Weapon Baru

Untuk weapon baru minimal buat:

```text
1. Script logic weapon:
   res://scripts/gameplay/weapons/MyNewWeapon.gd

2. Scene weapon:
   res://scenes/weapons/MyNewWeapon.tscn

3. Resource weapon:
   res://resources/weapons/MyNewWeapon.tres
```

Jika weapon punya tipe khusus dan field khusus, buat juga:

```text
4. Script definition khusus:
   res://scripts/gameplay/weapon_definitions/MyWeaponDefinition.gd
```

Jika weapon ingin muncul sebagai reward level up, buat juga:

```text
5. Ability reward:
   res://abilities/definitions/weapons/my_new_weapon_reward.tres

6. Daftarkan ke pool:
   res://abilities/default_ability_pool.tres
```

### Checklist Lokasi Saat Membuat Ability Baru

Untuk ability stat/modifier biasa:

```text
1. Buat resource ability:
   res://abilities/definitions/offense/my_ability.tres
   atau
   res://abilities/definitions/defense/my_ability.tres
   atau
   res://abilities/definitions/utility/my_ability.tres
   atau
   res://abilities/definitions/survival/my_ability.tres

2. Isi AbilityDefinition:
   id
   display_name
   description
   category
   rarity
   stackable
   max_stack
   effects

3. Isi satu atau lebih AbilityEffect.

4. Daftarkan ke:
   res://abilities/default_ability_pool.tres
```

Untuk ability yang membuka weapon:

```text
1. Buat weapon resource dulu:
   res://resources/weapons/MyNewWeapon.tres

2. Buat reward ability:
   res://abilities/definitions/weapons/my_new_weapon_reward.tres

3. Isi field weapon_definition ke:
   res://resources/weapons/MyNewWeapon.tres

4. Daftarkan ke:
   res://abilities/default_ability_pool.tres
```

### Checklist Lokasi Saat Membuat Utility Baru

Untuk utility baru seperti Shield, Dash, Bomb, atau Magnet varian baru:

```text
1. Component utility:
   res://scripts/gameplay/components/MyUtilityComponent.gd

2. Tambahkan node component ke:
   res://scenes/entities/Player.tscn

3. Jika utility didapat dari pickup, buat pickup effect:
   res://scripts/gameplay/pickups/MyUtilityPickupEffect.gd

4. Buat pickup config:
   res://resources/items/my_utility_pickup.tres

5. Jika perlu visual khusus, edit atau buat scene:
   res://scenes/entities/PickupItem.tscn
   atau scene pickup khusus di:
   res://scenes/entities/MyUtilityPickup.tscn
```

## Urutan Refactor Yang Disarankan

### Tahap 1: Buat WeaponBase

Tujuan:

- Semua weapon scene punya kontrak yang sama.
- Weapon baru cukup extend `WeaponBase`.
- Weapon tidak perlu tahu detail internal player terlalu banyak.

File baru:

- `res://scripts/gameplay/weapons/WeaponBase.gd`

Jika folder `scripts/gameplay/weapons/` belum ada, buat folder tersebut dulu. Setelah file ini dibuat, weapon script seperti `BasicGun.gd`, `BeamGun.gd`, dan `AuraWeapon.gd` sebaiknya dipindahkan ke folder ini secara bertahap.

Template:

```gdscript
extends Node2D
class_name WeaponBase

var weapon_instance: RefCounted


func setup(new_weapon_instance: RefCounted) -> void:
	weapon_instance = new_weapon_instance
	_on_weapon_setup()


func _on_weapon_setup() -> void:
	pass


func get_owner_node() -> Node2D:
	if weapon_instance == null:
		return null

	return weapon_instance.owner_node


func get_damage() -> int:
	if weapon_instance == null:
		return 0

	return weapon_instance.get_damage()


func get_cooldown() -> float:
	if weapon_instance == null:
		return 1.0

	return weapon_instance.get_cooldown()


func get_range() -> float:
	if weapon_instance == null:
		return 0.0

	return weapon_instance.get_attack_range()


func get_nearest_enemy() -> Node2D:
	var owner_node := get_owner_node()
	if owner_node == null:
		return null
	if not owner_node.has_method("get_nearest_enemy_in_range"):
		return null

	return owner_node.call("get_nearest_enemy_in_range", get_range()) as Node2D
```

Setelah itu, ubah weapon script:

```gdscript
extends WeaponBase
class_name BasicGun
```

Lalu pindahkan logic setup khusus ke `_on_weapon_setup()`.

### Tahap 2: Pecah WeaponDefinition Per Tipe

Tujuan:

- `WeaponDefinition` hanya menyimpan field umum.
- Field khusus beam/aura/summon tidak menumpuk di resource utama.

Base:

Lokasi yang disarankan:

- `res://scripts/gameplay/weapon_definitions/WeaponDefinition.gd`

```gdscript
extends Resource
class_name WeaponDefinition

enum WeaponType {
	PROJECTILE,
	AURA,
	AREA,
	SUMMON,
	BEAM,
	MELEE,
}

@export var id := ""
@export var display_name := "Weapon"
@export_multiline var description := ""
@export var icon: Texture2D
@export var weapon_type: WeaponType = WeaponType.PROJECTILE
@export var weapon_scene: PackedScene
@export var base_damage := 10.0
@export var base_cooldown := 1.0
@export var base_range := 300.0
@export var max_level := 5
@export var damage_per_level := 0.0
@export var cooldown_reduction_per_level := 0.0
```

Projectile:

Lokasi:

- `res://scripts/gameplay/weapon_definitions/ProjectileWeaponDefinition.gd`

```gdscript
extends WeaponDefinition
class_name ProjectileWeaponDefinition

@export_group("Projectile")
@export var base_projectile_count := 1
@export var projectile_count_per_level := 0
@export var base_projectile_speed := 300.0
@export var projectile_speed_per_level := 0.0
@export var spread_angle_degrees := 8.0
```

Beam:

Lokasi:

- `res://scripts/gameplay/weapon_definitions/BeamWeaponDefinition.gd`

```gdscript
extends WeaponDefinition
class_name BeamWeaponDefinition

@export_group("Beam")
@export var beam_duration := 1.2
@export var beam_duration_per_level := 0.0
@export var beam_tick_interval := 0.2
@export var beam_tick_interval_reduction_per_level := 0.0
@export var beam_width := 5.0
@export var pierce_count := 1
```

Aura:

Lokasi:

- `res://scripts/gameplay/weapon_definitions/AuraWeaponDefinition.gd`

```gdscript
extends WeaponDefinition
class_name AuraWeaponDefinition

@export_group("Aura")
@export var aura_radius := 70.0
@export var aura_radius_per_level := 0.0
@export var tick_interval := 0.5
@export var tick_damage_multiplier := 1.0
@export var slow_percent := 0.0
@export var slow_duration := 0.0
@export var enable_knockback := false
```

Summon:

Lokasi:

- `res://scripts/gameplay/weapon_definitions/SummonWeaponDefinition.gd`

```gdscript
extends WeaponDefinition
class_name SummonWeaponDefinition

@export_group("Summon")
@export var minion_scene: PackedScene
@export var minion_projectile_scene: PackedScene
@export var minion_damage_multiplier := 0.7
@export var max_active_minions := 4
@export var summon_interval := 10.0
@export var minion_lifetime := 25.0
@export var minion_attack_cooldown := 1.5
@export var minion_attack_range := 400.0
@export var minion_projectile_speed := 400.0
@export var minion_orbit_radius := 60.0
```

Area:

Lokasi:

- `res://scripts/gameplay/weapon_definitions/AreaWeaponDefinition.gd`

```gdscript
extends WeaponDefinition
class_name AreaWeaponDefinition

@export_group("Area")
@export var area_scene: PackedScene
@export var area_radius := 64.0
@export var area_duration := 1.0
@export var area_tick_interval := 0.25
@export var spawn_at_enemy := true
```

Melee:

Lokasi:

- `res://scripts/gameplay/weapon_definitions/MeleeWeaponDefinition.gd`

```gdscript
extends WeaponDefinition
class_name MeleeWeaponDefinition

@export_group("Melee")
@export var swing_angle_degrees := 90.0
@export var swing_duration := 0.18
@export var knockback_enabled := true
@export var knockback_distance := 12.0
```

### Tahap 3: Rapikan AbilityManager Agar Generic

Tujuan:

- Menambah modifier baru tidak perlu edit enum dan getter khusus.
- Weapon/Player/Utility cukup query pakai key.

Gunakan key seperti:

```text
weapon.damage
weapon.cooldown
weapon.range
weapon.projectile_count
weapon.projectile_speed
weapon.beam_duration
weapon.beam_tick_interval
weapon.aura_radius
weapon.summon_count
player.max_hp
player.move_speed
player.pickup_radius
utility.magnet_duration
utility.magnet_pull_speed
```

Template `AbilityEffect` baru:

Lokasi:

- `res://abilities/scripts/AbilityEffect.gd`

```gdscript
extends Resource
class_name AbilityEffect

enum ValueType {
	FLAT,
	PERCENT,
}

enum StackMode {
	ADD,
	MULTIPLY,
	OVERRIDE,
}

@export var modifier_key: StringName
@export var value := 0.0
@export var value_type: ValueType = ValueType.FLAT
@export var stack_mode: StackMode = StackMode.ADD
```

Template `AbilityManager` generic:

Lokasi:

- `res://abilities/scripts/AbilityManager.gd`

```gdscript
extends RefCounted
class_name AbilityManager

var modifier_config: AbilityModifierConfig
var ability_stacks := {}
var active_modifiers: Array[Dictionary] = []


func add_ability(ability: Resource, rarity_override: int = -1) -> bool:
	if ability == null or not ability.has_method("get_effects"):
		return false

	var ability_id := str(ability.get("id"))
	if ability_id.is_empty():
		return false

	var current_stack := get_stack_count(ability_id)
	var stackable := bool(ability.get("stackable"))
	var max_stack := int(ability.get("max_stack"))
	if not stackable and current_stack > 0:
		return false
	if max_stack > 0 and current_stack >= max_stack:
		return false

	ability_stacks[ability_id] = current_stack + 1
	_add_modifiers(ability, ability_id, rarity_override)
	return true


func get_stack_count(ability_id: String) -> int:
	return int(ability_stacks.get(ability_id, 0))


func get_flat_modifier(modifier_key: StringName) -> float:
	var total := 0.0
	for modifier in active_modifiers:
		if modifier.get("modifier_key") != modifier_key:
			continue
		if int(modifier.get("value_type")) != AbilityEffect.ValueType.FLAT:
			continue

		total += float(modifier.get("value", 0.0))

	return total


func get_percent_modifier(modifier_key: StringName) -> float:
	var total := 0.0
	for modifier in active_modifiers:
		if modifier.get("modifier_key") != modifier_key:
			continue
		if int(modifier.get("value_type")) != AbilityEffect.ValueType.PERCENT:
			continue

		total += float(modifier.get("value", 0.0))

	return total


func apply_modifiers(base_value: float, modifier_key: StringName) -> float:
	var flat := get_flat_modifier(modifier_key)
	var percent := get_percent_modifier(modifier_key)
	return (base_value + flat) * (1.0 + percent)
```

Saran transisi aman:

- Jangan hapus getter lama dulu.
- Jadikan getter lama wrapper:

```gdscript
func get_weapon_damage_percent_modifier() -> float:
	return get_percent_modifier("weapon.damage")
```

### Tahap 4: Pindahkan Magnet Ke Component

Tujuan:

- `PlayerController` kembali fokus pada movement, HP, XP, dan bridge event.
- Utility lain bisa mengikuti pola component.

Node Player:

```text
Player
- Visual
- CollisionShape2D
- PickupArea
- WeaponHolder
- MagnetComponent
- PlayerController.gd
```

Template:

Lokasi:

- `res://scripts/gameplay/components/MagnetComponent.gd`

```gdscript
extends Node
class_name MagnetComponent

@export var config: MagnetConfig
@export var owner_path: NodePath = ".."

var magnet_remaining := 0.0
var activation_queue: Array[WeakRef] = []
var owner_node: Node2D


func _ready() -> void:
	owner_node = get_node(owner_path) as Node2D


func _physics_process(delta: float) -> void:
	if magnet_remaining <= 0.0:
		return

	magnet_remaining = maxf(magnet_remaining - delta, 0.0)
	_process_activation_queue()

	if magnet_remaining <= 0.0:
		activation_queue.clear()


func activate() -> void:
	if config == null or owner_node == null:
		return

	magnet_remaining = maxf(magnet_remaining, config.duration)
	_refresh_activation_queue()
	_process_activation_queue()


func _refresh_activation_queue() -> void:
	activation_queue.clear()
	for pickup_node in get_tree().get_nodes_in_group("pickup_item"):
		var pickup := pickup_node as Node2D
		if pickup == null:
			continue
		if not pickup.has_method("can_be_magnetized"):
			continue
		if not pickup.call("can_be_magnetized"):
			continue
		if config.radius > 0.0 and owner_node.global_position.distance_to(pickup.global_position) > config.radius:
			continue

		activation_queue.append(weakref(pickup))


func _process_activation_queue() -> void:
	var batch_size := maxi(1, config.activation_batch_size)
	var processed_count := 0

	while processed_count < batch_size and not activation_queue.is_empty():
		var pickup_ref: WeakRef = activation_queue.pop_back()
		processed_count += 1

		var pickup := pickup_ref.get_ref() as Node
		if pickup == null or not is_instance_valid(pickup):
			continue
		if pickup.has_method("activate_magnet_pull"):
			pickup.call("activate_magnet_pull", owner_node, magnet_remaining, config.pull_speed, config.radius)
```

Di `PlayerController`, cukup:

```gdscript
@onready var magnet_component: MagnetComponent = $MagnetComponent

func activate_magnet() -> void:
	magnet_component.activate()
```

### Tahap 5: PickupEffect Resource

Tujuan:

- `PickupItem` tidak perlu `match config.kind`.
- Pickup bisa punya banyak efek.
- Utility baru bisa dibuat via resource.

Template:

Lokasi:

- `res://scripts/gameplay/pickups/PickupEffect.gd`

```gdscript
extends Resource
class_name PickupEffect

enum EffectType {
	HEAL,
	ADD_XP,
	ACTIVATE_MAGNET,
	ADD_SHIELD,
	ADD_MOVE_SPEED_TEMP,
}

@export var effect_type: EffectType
@export var amount := 0.0
@export var duration := 0.0


func apply(player: Node) -> void:
	match effect_type:
		EffectType.HEAL:
			if player.has_method("heal"):
				player.heal(roundi(amount))
		EffectType.ADD_XP:
			if player.has_method("add_xp"):
				player.add_xp(roundi(amount))
		EffectType.ACTIVATE_MAGNET:
			if player.has_method("activate_magnet"):
				player.activate_magnet()
```

Template `PickupConfig` baru:

Lokasi:

- `res://scripts/gameplay/PickupConfig.gd`

```gdscript
extends Resource
class_name PickupConfig

@export var id := ""
@export var display_name := "Pickup"
@export var magnetizable := true
@export var visual_color := Color.WHITE
@export var label_template := ""
@export var effects: Array[PickupEffect] = []
```

Template `PickupItem` apply:

Lokasi:

- `res://scripts/gameplay/PickupItem.gd`

```gdscript
func _apply_to_player(player: Node) -> void:
	for effect in config.effects:
		if effect != null and effect.has_method("apply"):
			effect.apply(player)
```

Contoh resource:

```text
health_pickup.tres
- id = "health"
- display_name = "Health"
- magnetizable = true
- visual_color = green
- label_template = "HP: {amount}"
- effects = [HealEffect amount 5]

magnet_pickup.tres
- id = "magnet"
- display_name = "Magnet"
- magnetizable = false
- visual_color = yellow
- label_template = "MAGNET"
- effects = [ActivateMagnetEffect]
```

## Template Menambah Weapon Baru

### 1. Buat Definition

Buat resource data weapon di:

```text
res://resources/weapons/MyBeam.tres
```

Contoh isi:

```text
script = BeamWeaponDefinition
id = "my_beam"
display_name = "My Beam"
weapon_type = BEAM
weapon_scene = res://scenes/weapons/MyBeam.tscn
base_damage = 4
base_cooldown = 1.2
base_range = 480
max_level = 5
beam_duration = 1.0
beam_tick_interval = 0.2
```

### 2. Buat Scene

Buat scene weapon di:

```text
res://scenes/weapons/MyBeam.tscn
- Node2D
  - RayCast2D
  - Line2D
```

### 3. Buat Script

Buat script logic weapon di:

```text
res://scripts/gameplay/weapons/MyBeam.gd
```

```gdscript
extends WeaponBase
class_name MyBeam


func _physics_process(delta: float) -> void:
	var target := get_nearest_enemy()
	if target == null:
		return

	# Logic weapon di sini.
```

### 4. Tambahkan Reward Level Up

Buat resource reward di:

```text
res://abilities/definitions/weapons/my_beam_reward.tres
- script = AbilityDefinition
- id = "weapon_my_beam"
- display_name = "My Beam"
- weapon_definition = resources/weapons/MyBeam.tres
```

Lalu masukkan ke:

```text
res://abilities/default_ability_pool.tres
```

Starting weapon tidak perlu didaftarkan manual jika resource weapon ada di:

```text
resources/weapons/
```

## Template Menambah Modifier Baru

Contoh modifier baru: aura radius +20%.

Buat atau edit resource `AbilityEffect` yang dipasang di ability:

```text
res://abilities/definitions/offense/aura_radius_up.tres
```

Isi effect:

```text
modifier_key = "weapon.aura_radius"
value = 20
value_type = PERCENT
stack_mode = ADD
```

Weapon membaca:

```gdscript
var radius := base_radius
radius = ability_manager.apply_modifiers(radius, "weapon.aura_radius")
```

## Template Menambah Utility Baru

Contoh utility: Shield pickup.

1. Buat component:

```text
res://scripts/gameplay/components/ShieldComponent.gd
```

2. Tambahkan node ke Player:

```text
Player
- ShieldComponent
```

3. Buat `PickupEffect`:

```text
effect_type = ADD_SHIELD
amount = 1
duration = 5
```

4. Buat pickup config:

```text
res://resources/items/shield_pickup.tres
```

5. Enemy/drop table cukup mengarah ke pickup config tersebut.

## Checklist Setelah Refactor

- Player masih bisa memilih starting weapon.
- Weapon aktif tetap maksimal 4.
- Weapon yang sama naik level.
- Weapon baru dari `resources/weapons/` muncul di pilihan awal.
- Reward weapon tidak muncul kalau slot penuh.
- Ability lama tetap bekerja.
- Pickup HP, XP, dan Magnet tetap bekerja.
- Magnet tidak lagi berada di `PlayerController`.
- Godot headless tidak error:

```powershell
godot --headless --path . --quit
```
