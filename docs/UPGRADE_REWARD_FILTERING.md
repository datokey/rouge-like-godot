# Upgrade Reward Filtering Refactor

Dokumen ini mencatat refactor sistem pilihan upgrade saat player naik level. Refactor ini tidak mengubah logic serangan weapon; perubahan hanya menyentuh metadata reward, context runtime, filtering kandidat, RNG offer, dan fallback offer.

## File yang Diubah

- `res://abilities/scripts/AbilityDefinition.gd`
  Menambahkan kategori reward, weight RNG, target weapon/skill, dan helper klasifikasi.
- `res://abilities/scripts/AbilityPoolConfig.gd`
  Mengganti filtering lama dengan pipeline kategori reward dan weighted RNG tanpa duplikat.
- `res://abilities/scripts/AbilityManager.gd`
  Menambahkan akses read-only untuk stack ability yang sudah dipilih.
- `res://scripts/gameplay/WeaponManager.gd`
  Memperluas context weapon: owned IDs, level, max level, slot maksimal, slot terpakai, slot tersedia.
- `res://scripts/gameplay/PlayerController.gd`
  Menambahkan `get_reward_offer_context()` yang menggabungkan context weapon, skill aktif, dan stack modifier.
- `res://scripts/ui/AbilitySelectionScreen.gd`
  Mengirim context lengkap ke ability pool dan mencatat selected reward/stack count.
- `res://abilities/default_ability_pool.tres`
  Menambahkan `fallback_abilities` dari ability yang sudah ada.

## Kategori Reward

Kategori baru ada di `AbilityDefinition.RewardCategory`:

- `AUTO`
- `WEAPON_NEW`
- `WEAPON_UPGRADE`
- `SKILL_NEW`
- `SKILL_UPGRADE`
- `WEAPON_MODIFIER`
- `SKILL_MODIFIER`
- `GLOBAL_MODIFIER`

Default semua ability lama adalah `AUTO`, agar resource lama tetap kompatibel.

Klasifikasi `AUTO` saat ini:

- Jika `weapon_definition` terisi:
  - Weapon belum dimiliki: `WEAPON_NEW`.
  - Weapon sudah dimiliki: `WEAPON_UPGRADE`.
- Jika `skill_id` terisi:
  - Skill belum dimiliki: `SKILL_NEW`.
  - Skill sudah dimiliki: `SKILL_UPGRADE`.
- Jika effect memakai key `weapon.*` atau `target_weapon_id` terisi: `WEAPON_MODIFIER`.
- Jika effect memakai key `skill.*` atau `target_skill_id` terisi: `SKILL_MODIFIER`.
- Selain itu: `GLOBAL_MODIFIER`.

## Offer Context

Context dikumpulkan saat `AbilitySelectionScreen` akan roll offer.

Context weapon berasal dari `WeaponManager.get_offer_context()`:

- `owned_weapon_ids`
- `owned_weapon_levels`
- `owned_weapon_max_levels`
- `max_weapon_slots`
- `used_weapon_slots`
- `available_weapon_slots`
- `can_add_weapon`

Context player berasal dari `PlayerController.get_reward_offer_context()`:

- Semua context weapon di atas.
- `owned_skill_ids`
- `owned_skill_levels`
- `owned_skill_max_levels`
- `max_skill_slots`
- `used_skill_slots`
- `available_skill_slots`
- `can_add_skill`
- `selected_reward_ids`
- `modifier_stack_counts`

Catatan: project saat ini sudah memiliki fondasi `SkillManager`. `Player.tscn` memakai `max_skill_slots = 2`, dan context skill berasal dari `SkillManager.get_offer_context()`.

## Alur Filtering

Filtering terjadi di `AbilityPoolConfig.get_valid_abilities()` sebelum RNG.

Aturannya:

- Weapon baru valid hanya jika weapon belum dimiliki dan `can_add_weapon = true`.
- Weapon upgrade valid hanya jika weapon sudah dimiliki dan levelnya belum mencapai max level.
- Skill baru valid hanya jika skill belum dimiliki dan `can_add_skill = true`.
- Skill upgrade valid hanya jika skill sudah dimiliki dan levelnya belum mencapai max level.
- Akuisisi weapon/skill yang sudah dimiliki tidak lolos sebagai reward baru.
- Modifier unik (`stackable = false`) tidak muncul lagi jika sudah pernah dipilih.
- Modifier stackable muncul kembali sampai `max_stack`; `max_stack = 0` berarti tidak dibatasi oleh max stack.
- Weapon modifier hanya valid jika player punya weapon. Jika `target_weapon_id` diisi, weapon tersebut harus dimiliki.
- Skill modifier hanya valid jika player punya skill. Jika `target_skill_id` diisi, skill tersebut harus dimiliki.
- Global modifier hanya mengikuti aturan unique/stackable/max_stack.
- Jika slot weapon penuh, `WEAPON_NEW` tidak valid.
- Jika slot skill penuh, `SKILL_NEW` tidak valid.
- Jika kedua slot penuh, kandidat yang tersisa hanya upgrade dan modifier yang valid.

## Weighted RNG

Setelah filtering selesai, `AbilityPoolConfig.roll_offers()` memilih offer memakai weighted RNG.

Aturan RNG:

- Target jumlah offer mengikuti `min(offer_count, max_offer_count)`.
- Tiap `AbilityDefinition` memiliki `weight`.
- Weight default adalah `1.0`, sehingga resource lama tetap punya peluang normal.
- Weight dikalikan 1000 lalu di-roll sebagai integer agar cocok dengan `Rng.range_i()`.
- Offer diambil tanpa duplikat dalam satu halaman pilihan.
- Setelah satu reward dipilih, reward itu dihapus dari kandidat roll halaman tersebut.
- Jika semua weight kandidat `0`, sistem fallback ke random uniform antar kandidat.

## Fallback Reward

Fallback dijalankan jika kandidat valid hasil roll kurang dari target offer.

Sumber fallback:

1. `fallback_abilities` di `default_ability_pool.tres`.
2. Jika `fallback_abilities` kosong/tidak valid, pool mencoba global modifier valid dari `abilities`.

Fallback saat ini:

- `max_hp`
- `move_speed`
- `sharp_bullet`

Fallback tetap mematuhi filtering:

- Tidak menduplikasi offer yang sudah muncul di halaman yang sama.
- Tetap mematuhi `stackable` dan `max_stack`.
- Tetap memakai weighted RNG.

Jika seluruh pool dan fallback benar-benar tidak punya kandidat valid, UI lama masih aman karena `AbilitySelectionScreen` akan resume game saat `current_offers` kosong. Dengan konfigurasi default saat ini, fallback dirancang agar kasus tersebut tidak terjadi pada run normal.

## Kompatibilitas Sistem Lama

Reward weapon lama seperti `basic_gun_reward.tres` dan `beam_gun_reward.tres` tetap memakai field `weapon_definition`.

Dengan kategori `AUTO`:

- Saat weapon belum dimiliki, reward dianggap sebagai akuisisi weapon baru.
- Saat weapon sudah dimiliki, reward dianggap sebagai upgrade weapon.
- `WeaponManager.add_weapon()` tetap menjadi satu pintu: add jika belum punya, upgrade jika sudah punya.

Ability modifier lama tetap memakai:

- `stackable`
- `max_stack`
- `effects`
- `modifier_key`

Tidak ada perubahan ke script serangan weapon:

- `BasicGun.gd`
- `BeamGun.gd`
- `AuraWeapon.gd`
- `KoalisiDadakan.gd`
- `Simpatisan.gd`

## Hasil Pengujian

Command yang dijalankan:

```powershell
godot --headless --path . --quit
godot --headless --path . scenes/Main.tscn --quit
```

Hasil:

- Project load berhasil.
- Scene `Main.tscn` load berhasil.
- Tidak ada error parse/resource dari perubahan script dan resource pool.

## Catatan Lanjutan

- Sistem skill aktif dasar sudah tersedia melalui `SkillManager`.
- Reward skill proof of concept yang terdaftar saat ini adalah `training_pulse_reward`.
- Untuk modifier spesifik weapon, isi `target_weapon_id` di `AbilityDefinition`.
- Untuk modifier spesifik skill, isi `target_skill_id`.
- Untuk reward yang ingin dikontrol manual, ubah `reward_category` dari `AUTO` ke kategori eksplisit.
- Untuk mengatur peluang reward, ubah `weight` pada resource `AbilityDefinition`.
