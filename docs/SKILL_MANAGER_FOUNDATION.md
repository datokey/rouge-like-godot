# Skill Manager Foundation

Dokumen ini mencatat fondasi `SkillManager` untuk skill aktif. Sistem ini dibuat terpisah dari weapon dan passive ability agar mudah dirawat saat prototype berkembang.

## File yang Dibuat

- `res://scripts/gameplay/SkillDefinition.gd`
  Resource data dasar skill aktif.
- `res://scripts/gameplay/SkillInstance.gd`
  Runtime object untuk menyimpan definition, owner, dan level skill.
- `res://scripts/gameplay/SkillManager.gd`
  Manager aktif untuk slot, add, upgrade, remove, instantiate scene, dan offer context skill.
- `res://scripts/gameplay/skills/TrainingPulseSkill.gd`
  Runtime proof of concept skill aktif non-combat.
- `res://scenes/skills/TrainingPulseSkill.tscn`
  Scene skill proof of concept.
- `res://resources/skills/TrainingPulse.tres`
  Resource `SkillDefinition` proof of concept.
- `res://abilities/definitions/skills/training_pulse_reward.tres`
  Reward level-up untuk add/upgrade `Training Pulse`.

## File yang Diubah

- `res://abilities/scripts/AbilityDefinition.gd`
  Menambahkan `skill_definition` sebagai kontrak reward skill.
- `res://abilities/scripts/AbilityPoolConfig.gd`
  Filtering `SKILL_NEW` dan `SKILL_UPGRADE` sekarang mensyaratkan `skill_manager_active = true`.
- `res://scripts/gameplay/PlayerController.gd`
  Membuat `SkillManager`, menghubungkannya ke `SkillHolder`, meneruskan reward skill ke `SkillManager.add_skill()`, dan menggabungkan skill context ke offer context.
- `res://scenes/entities/Player.tscn`
  Menambahkan `SkillHolder` dan `max_skill_slots = 2`.
- `res://abilities/default_ability_pool.tres`
  Menambahkan `training_pulse_reward` ke pool.

## Batas Tanggung Jawab

`SkillManager` hanya menangani skill aktif:

- Slot skill.
- Daftar skill yang dimiliki.
- Level skill.
- Add skill baru.
- Upgrade skill yang sudah dimiliki.
- Remove skill.
- Instantiate scene skill.
- Offer context untuk filtering reward.

`SkillManager` tidak menangani:

- Passive ability.
- Stat modifier.
- RNG offer.
- UI pilihan upgrade.
- Logic weapon.
- Logic serangan weapon.

Passive ability dan stat modifier tetap menjadi tanggung jawab:

- `res://abilities/scripts/AbilityManager.gd`
- `res://abilities/scripts/AbilityEffect.gd`
- `res://abilities/definitions/**/*.tres`

## Struktur Data

`SkillDefinition` memiliki field:

- `id`
- `display_name`
- `description`
- `icon`
- `skill_scene`
- `max_level`

`SkillInstance` menyimpan:

- `definition`
- `level`
- `owner_node`

`SkillManager` menyimpan:

- `max_skill_slots`
- `skills`
- `skill_nodes`
- `owner_node`
- `skill_holder`

## Alur Add dan Upgrade Skill

1. Player memilih reward ability skill dari level-up.
2. `AbilitySelectionScreen` mengirim ability lewat `EventBus.ability_selected`.
3. `PlayerController.add_ability_to_manager()` mendeteksi `ability.is_skill_reward()`.
4. `PlayerController` mengambil `ability.skill_definition`.
5. `PlayerController` memanggil `SkillManager.add_skill(skill_definition)`.
6. Jika skill belum dimiliki dan slot tersedia:
   - `SkillManager` membuat `SkillInstance`.
   - `SkillManager` instantiate `SkillDefinition.skill_scene`.
   - Scene skill ditambahkan ke `Player/SkillHolder`.
   - Jika node skill punya `setup()`, method itu dipanggil dengan `SkillInstance`.
7. Jika skill sudah dimiliki:
   - `SkillManager.add_skill()` memanggil `upgrade_skill()`.
   - `SkillInstance.level` naik selama belum mencapai `max_level`.
   - Jika node skill punya `on_skill_upgraded()`, method itu dipanggil.
8. Jika skill sudah max level, upgrade gagal dan filtering reward berikutnya tidak menawarkan skill tersebut lagi.

## Offer Context Skill

`SkillManager.get_offer_context()` mengembalikan:

- `skill_manager_active`
- `can_add_skill`
- `owned_skill_ids`
- `owned_skill_levels`
- `owned_skill_max_levels`
- `max_skill_slots`
- `used_skill_slots`
- `available_skill_slots`

`PlayerController.get_reward_offer_context()` menggabungkan context ini dengan context weapon dan stack modifier. `AbilityPoolConfig` memakai context tersebut untuk filtering.

## Aturan Filtering Skill

`SKILL_NEW` valid jika:

- `skill_manager_active = true`.
- Skill belum dimiliki.
- Slot skill tersedia.

`SKILL_UPGRADE` valid jika:

- `skill_manager_active = true`.
- Skill sudah dimiliki.
- Level skill belum mencapai `max_level`.

Reward akuisisi skill yang sudah dimiliki tidak muncul sebagai skill baru. Setelah skill dimiliki, ability yang sama diklasifikasikan sebagai upgrade skill oleh `AbilityDefinition.AUTO`.

## Proof of Concept: Training Pulse

`Training Pulse` adalah skill aktif sederhana untuk menguji alur lifecycle.

File:

- Resource: `res://resources/skills/TrainingPulse.tres`
- Scene: `res://scenes/skills/TrainingPulseSkill.tscn`
- Runtime: `res://scripts/gameplay/skills/TrainingPulseSkill.gd`
- Reward: `res://abilities/definitions/skills/training_pulse_reward.tres`

Perilaku:

- Node skill mengikuti posisi player.
- Menggambar pulse visual kecil.
- Radius visual bertambah berdasarkan level.
- Tidak memberi damage.
- Tidak mengubah stat.
- Tidak berinteraksi dengan weapon.

Nilai penting:

- `max_level = 3`
- `max_stack = 3` pada reward.
- `max_skill_slots = 2` pada `Player.tscn`.

## Hasil Pengujian

Command yang berhasil:

```powershell
godot --headless --path . --quit
godot --headless --path . scenes/Main.tscn --quit
```

Hasil:

- Project load berhasil.
- `Main.tscn` load berhasil.
- Resource skill, reward skill, scene skill, dan script skill tidak menghasilkan error parse/load.

Catatan:

- Test script headless sementara lewat `--script` tidak bisa dijalankan di environment ini karena Godot tidak menemukan file script temporer walaupun file dibuat di filesystem. Karena itu validasi otomatis yang tercatat adalah load project dan load scene utama.
- Alur manual yang perlu dicek di editor/game: naik level sampai `Training Pulse` muncul, pilih reward, cek node masuk ke `SkillHolder`, pilih reward yang sama sampai level 3, lalu pastikan reward tidak muncul lagi setelah max level.

## Risiko dan Catatan Lanjutan

- Skill aktif baru harus punya `SkillDefinition.skill_scene`; tanpa scene, `SkillManager.add_skill()` gagal.
- Jangan memakai `SkillManager` untuk passive modifier. Gunakan `AbilityManager`.
- Jangan memindahkan logic weapon ke skill manager.
- Jika nanti ada skill yang menyerang, logic serangannya tetap berada di scene/script skill masing-masing, bukan di `PlayerController`, `AbilityManager`, atau `SkillManager`.
- Jika skill membutuhkan stat per level selain `max_level`, tambahkan field tuning ke subclass/resource skill secara bertahap, jangan memaksa semuanya ke manager.
