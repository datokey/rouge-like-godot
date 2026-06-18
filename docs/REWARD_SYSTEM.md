# Reward System

Level-up sekarang memakai tiga kategori reward: weapon, talisman, dan utility.

## Alur level-up

1. `PlayerController` membuat context dari `WeaponManager` dan `BuildManager`.
2. `RewardPoolConfig` mengumpulkan weapon baru, upgrade stat weapon yang dimiliki, talisman, dan utility.
3. Kandidat yang melanggar slot, max level, atau compatibility tag dibuang.
4. Kandidat dipilih tanpa duplikat berdasarkan `weight` memakai Autoload `Rng`, sehingga seed run dapat direproduksi.
5. Rarity di-roll terpisah berdasarkan `rarity_weights`; Luck hanya memperbesar bobot rarity tinggi dan tidak memengaruhi pemilihan jenis reward.
6. Jika kandidat valid kurang dari jumlah kartu, resolver mengisi sisanya dari `fallback_definitions`.
7. UI mengirim `RewardOffer` terpilih ke `BuildManager` untuk diterapkan.

## Konfigurasi

- Pool aktif: `res://upgrades/default_reward_pool.tres`
- Stat tiap weapon: field `upgrade_options` pada resource di `res://resources/weapons/`
- Talisman: `res://upgrades/talismans/`
- Utility: `res://upgrades/utilities/`
- Fallback: field `fallback_definitions` pada `res://upgrades/default_reward_pool.tres`
- Compatibility tag weapon: field `compatibility_tags` pada `WeaponDefinition`

Tag awal: `PROJECTILE`, `BEAM`, `AURA`, `SUMMON`, `USES_ATTACK_SPEED`, `CAN_CRIT`, dan `CAN_LIFESTEAL`.

Utility reroll dan tambahan pilihan sudah memiliki resource/config, tetapi belum dimasukkan ke pool aktif sampai kontrol UI untuk memakai reroll dan menampilkan tombol tambahan tersedia. Ini mencegah reward yang belum memberi efek nyata muncul kepada player.
