# Card Pool: Analisis Sheet dan Panduan Implementasi

Sumber analisis: Google Spreadsheet **Milestone Game Roguelike Top-Down**, khususnya `Card Pool!A1:M121`, dengan konteks dari `Skill Upgrade Prototype!A1:I80`, `Build Archetypes!A1:G60`, `Balancing Lab!A1:H80`, dan `Milestone Tracker!A1:I80`.

## Ringkasan data Sheet

`Card Pool` mendefinisikan 15 baris kartu bernama/ber-ID, tetapi baru 13 yang memiliki nama dan hanya 12 yang memiliki ID. Dua baris terakhir (`UPG_WEIRD_004` dan `UPG_WEIRD_005`) belum berisi desain. Kolom yang tersedia adalah ID, Name, Type, Category, Rarity, Archetype, Main Effect, Tradeoff, Trigger, Stackable, Priority, Status, dan Notes.

Aturan desain lintas tab:

- Level-up menampilkan tiga kartu dan prototype menginginkan satu slot Safe, satu Risky, dan satu Weird jika kandidat valid tersedia.
- Rarity yang dipakai: Common, Uncommon, Rare, Epic, Legendary.
- Archetype: Brutal, Survivor, Chaos.
- Kartu Risky harus menarik tetapi memiliki tradeoff nyata; target kasar `Balancing Lab` adalah buff 25–60%.
- Efek yang disebut mencakup stat, weapon/summon, active skill, invincibility, stun, decoy, regen, XP conversion, projectile reflection, explosion, dan lifesteal.

Masalah data yang perlu dibereskan sebelum seluruh kartu dapat diproduksi:

- `Megafon Aksi` belum memiliki ID dan Status.
- Prefix beberapa ID tidak cocok dengan Category: `UPG_SAFE_001/003/005` ber-Category Risky, sementara `UPG_RISK_003/004/005` ber-Category Safe. Logic memakai field `category`, bukan prefix ID.
- Penamaan dan kapitalisasi Trigger belum konsisten (`Passive` dan `passive`).
- Beberapa efek belum punya angka tuning lengkap: cooldown, duration, radius, base damage, scaling per level, chance, dan batas stack.
- `Bukan Saya, Itu Oknum` belum memiliki Main Effect/Tradeoff.
- `Serangan Pajak` tidak memiliki Trigger, Stackable, Priority, Status, dan Notes.
- Sheet belum membedakan dengan tegas `Weapon New`, `Weapon Upgrade`, `Skill New`, `Skill Upgrade`, `Weapon Modifier`, `Skill Modifier`, dan `Global Modifier`.
- Belum ada kolom `Weight`, prerequisite terstruktur, min/max player level, max level/stack numerik, target weapon/skill ID, dan enabled flag. Kolom-kolom ini dibutuhkan agar konfigurasi tidak bergantung pada parsing teks.

## Sistem project yang sudah tersedia

- `AbilityDefinition`: data kartu, rarity, stack, effect, weight, target weapon/skill.
- `AbilityPoolConfig`: eligibility dasar, weighted roll tanpa duplikat, fallback.
- `AbilitySelectionScreen`: pause, tiga pilihan, dan queue level-up.
- `AbilityManager`: penyimpanan stack dan agregasi modifier runtime.
- `WeaponManager` / `WeaponInstance`: slot weapon, add/upgrade, level maksimum.
- `SkillManager` / `SkillInstance`: slot skill, add/upgrade, level maksimum.
- `PlayerController`: context player/slot dan titik masuk reward.

Tidak diperlukan inventory item generik untuk card pool prototype. Slot weapon dan skill sudah merupakan inventory runtime yang relevan. Penyimpanan upgrade saat ini hanya hidup selama satu run; belum ada save/load run atau meta-progression.

## Perubahan fondasi yang dibuat

- `AbilityDefinition` sekarang memiliki `enabled`, `archetype`, dan `eligibility_rules`.
- `AbilityEligibilityRule` menjadi kontrak rule reusable.
- `AbilityPrerequisiteRule` mendukung min/max level, required/blocked card, required weapon, dan required skill.
- `AbilityPoolConfig` memiliki `WEIGHTED` dan `CATEGORY_SLOTS`. Slot kategori dikonfigurasi lewat array, bukan hardcode di algoritma.
- `AbilityRewardApplier` memisahkan dispatch reward weapon, skill, dan modifier dari controller player.
- Context offer sekarang membawa `player_level` dan seluruh `selected_reward_counts`.
- `card_template.tres` adalah contoh kartu Risky dengan buff, tradeoff, prerequisite, stack, rarity, dan weight.

## Struktur folder

```text
abilities/
  scripts/
    AbilityDefinition.gd          # data kartu
    AbilityEffect.gd              # modifier numerik
    AbilityEligibilityRule.gd     # kontrak eligibility
    AbilityPrerequisiteRule.gd    # prerequisite umum
    AbilityPoolConfig.gd          # filter dan RNG offer
    AbilityRewardApplier.gd       # penerapan reward
    AbilityManager.gd             # stack/modifier selama run
  definitions/
    weapons/                      # reward weapon baru/upgrade
    skills/                       # reward skill baru/upgrade
    offense|defense|utility/...   # modifier/stat card
  templates/
    card_template.tres
  default_ability_pool.tres       # daftar kartu aktif dan fallback
scripts/gameplay/
  WeaponDefinition.gd, WeaponManager.gd, WeaponInstance.gd
  SkillDefinition.gd, SkillManager.gd, SkillInstance.gd
scripts/ui/
  AbilitySelectionScreen.gd
```

## Alur runtime

1. Player level-up dan UI meminta context runtime.
2. Pool menolak resource invalid/disabled, prerequisite gagal, slot penuh, target tidak dimiliki, max level tercapai, atau max stack tercapai.
3. Pool memilih kandidat berdasarkan `weight`. Pada `CATEGORY_SLOTS`, tiap nama kategori mengambil satu kandidat valid, kemudian slot kosong diisi weighted roll dari kandidat tersisa.
4. UI menampilkan offer tanpa duplikat.
5. Card terpilih dikirim ke `AbilityRewardApplier`.
6. Weapon masuk `WeaponManager`, skill masuk `SkillManager`, sedangkan modifier masuk `AbilityManager`.
7. Context berikutnya membaca kembali level, slot, ownership, dan stack runtime.

## Cara membuat kartu baru

1. Duplicate `res://abilities/templates/card_template.tres` ke subfolder `definitions` yang sesuai.
2. Beri `id` unik dan stabil. ID tidak boleh mengikuti nama tampilan yang mungkin berubah.
3. Isi `display_name`, `description`, `category`, `rarity`, `archetype`, `stackable`, `max_stack`, dan `weight`.
4. Set `enabled = true` setelah resource lengkap.
5. Untuk modifier stat, isi satu atau lebih `AbilityEffect`. Nilai negatif dapat menjadi tradeoff.
6. Untuk weapon baru, isi `weapon_definition`; untuk skill baru, isi `skill_definition`. Resource reward yang sama otomatis menjadi upgrade ketika item sudah dimiliki.
7. Untuk modifier spesifik, isi `target_weapon_id` atau `target_skill_id` dan pilih reward category yang tepat bila klasifikasi `AUTO` tidak cukup.
8. Tambahkan prerequisite sebagai subresource `AbilityPrerequisiteRule` atau rule custom turunan `AbilityEligibilityRule`.
9. Daftarkan resource ke `abilities` pada `default_ability_pool.tres`. Jangan daftarkan kartu berstatus Backlog/To Do yang implementasinya belum ada.

## Peluang kemunculan

`weight` adalah bobot relatif setelah filtering. Contoh bobot 3, 2, dan 1 menghasilkan perbandingan peluang 3:2:1 di antara kandidat valid, bukan persentase absolut. Rarity adalah metadata/scaling, bukan peluang otomatis. Jika rarity harus memengaruhi peluang, atur weight resource atau tambahkan rule/config rarity terpisah; jangan menyembunyikan tabel peluang di logic.

Untuk pola Sheet, set `roll_mode = CATEGORY_SLOTS` dan `category_slots = ["Safe", "Risky", "Weird"]` pada pool. Jika satu kategori tidak memiliki kandidat eligible, slot tersebut diisi kandidat valid lain agar UI tidak macet.

## Menentukan syarat kemunculan

Gunakan `AbilityPrerequisiteRule`:

- `minimum_player_level` / `maximum_player_level`
- `required_card_ids`
- `blocked_card_ids`
- `required_weapon_ids`
- `required_skill_ids`

Aturan bawaan pool tetap memeriksa ownership, max level, max stack, dan slot weapon/skill. Untuk syarat baru seperti HP di bawah 30%, waktu run, boss defeated, atau archetype score, buat Resource rule kecil turunan `AbilityEligibilityRule` lalu tambahkan ke `eligibility_rules` kartu. Context yang dibutuhkan harus dipublikasikan oleh player/run manager.

## Menghubungkan kartu ke gameplay

- **Weapon baru/upgrade:** buat `WeaponDefinition` + scene weapon; referensikan pada `weapon_definition`.
- **Skill baru/upgrade:** buat `SkillDefinition` + scene skill; referensikan pada `skill_definition`.
- **Weapon modifier:** gunakan key `weapon.*`; isi `target_weapon_id` bila hanya berlaku ke satu weapon.
- **Skill modifier:** gunakan key `skill.*`; skill runtime harus membaca modifier tersebut dari manager (adapter ini belum tersedia untuk Training Pulse).
- **Stat player:** gunakan key `player.*`; getter player harus membaca key tersebut. Saat ini yang siap adalah max HP dan move speed. Pickup radius sudah ada sebagai base config, tetapi belum membaca modifier manager.
- **Tradeoff:** tambahkan effect kedua bernilai negatif. Jangan simpan tradeoff hanya sebagai teks.
- **Perilaku custom:** buat weapon/skill scene tersendiri atau effect command khusus. Jangan menambah `match card_id` ke PlayerController.

## Dependensi yang belum tersedia untuk kartu Sheet

- Registry/handler status effect (slow, stun, invincible, attack lock, enemy speed buff).
- Event XP pickup terpusat dan XP multiplier untuk Rekapitulasi/Popularitas.
- Active skill input/cooldown/duration framework untuk Bansos Dash dan Imunitas Dewan.
- Decoy/aggro target abstraction dan bodyguard defense behavior.
- Projectile behavior pipeline untuk reflect, split, pierce, dan friendly self-damage.
- Crit, defense, regen, lifesteal, gold/drop economy, dan projectile speed sebagai stat/modifier terstandar.
- Per-target weapon/skill modifier aggregation; target ID sudah ada di data/filter, tetapi `AbilityManager` saat ini masih mengagregasi key secara global.
- Save/load snapshot jika upgrade harus bertahan setelah run ditutup.
- Debug level-up/card inspector untuk acceptance testing cepat.

## Rencana pengerjaan bertahap

1. **Normalisasi data Sheet:** tambahkan kolom reward category, weight, max stack/level, target ID, prerequisite, enabled, dan angka tuning; perbaiki ID/status kosong.
2. **Fondasi pool:** gunakan rule, category slots, weighted RNG, fallback, dan validator resource yang sudah tersedia.
3. **Vertical slice stat:** produksi kartu damage, cooldown, move speed, max HP, projectile count, dan pickup radius; verifikasi buff + debuff.
4. **Weapon/skill acquisition:** migrasikan satu kartu weapon dan satu active skill dengan slot/max-level penuh.
5. **Gameplay contracts:** tambah event XP, status effect, projectile behavior, crit/defense/regen, dan active cooldown hanya saat kartu prioritas memerlukannya.
6. **Kartu custom per kelompok:** Janji Manis/Koalisi/Kipas; lalu Bansos/Imunitas; terakhir kartu Weird yang berisiko tinggi.
7. **Tooling dan QA:** validator ID duplikat/referensi hilang, debug level-up, simulasi distribusi weight, save snapshot, dan regression test headless.

## Risiko integrasi

- Mengaktifkan `CATEGORY_SLOTS` sebelum pool punya kandidat Safe/Risky/Weird yang cukup akan meningkatkan pengulangan fallback.
- Modifier bertarget masih diterapkan global; jangan merilis card modifier spesifik weapon sebelum aggregator mengenali target ID.
- UI saat ini mencatat pilihan ketika tombol ditekan; jika reward gagal diterapkan karena resource rusak, histori lokal tetap bertambah. Validasi resource harus dilakukan sebelum kartu didaftarkan.
- Card Sheet mengandung banyak behavior yang membutuhkan event/status systems. Mengubahnya menjadi modifier angka saja akan menghilangkan intent desain.
