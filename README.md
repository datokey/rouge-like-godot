# Proyek Baru Permainan

Dokumentasi ini menjelaskan fondasi game action roguelike top-down yang sedang dibangun di Godot.

## Status gameplay saat ini

- Player bergerak 8 arah memakai WASD.
- Camera mengikuti player di arena test.
- Enemy spawn otomatis di sekitar pinggir area kamera.
- Enemy mengejar player dan memberi damage saat bersentuhan.
- Player menembak otomatis ke enemy terdekat seperti Vampire Survivors.
- Projectile mengurangi HP enemy.
- Enemy punya peluang drop pickup HP saat mati.
- Pickup HP menyembuhkan player.
- HUD kiri atas menampilkan HP player.
- Saat player mati, muncul layar game over dengan tombol Restart dan Keluar.

## Struktur folder penting

- `scenes/`
  Scene Godot yang tampil di game.
- `scenes/entities/`
  Entity gameplay seperti `Player`, `Enemy`, `Projectile`, dan `HealthPickup`.
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
  HP player, movement speed, damage projectile, cooldown attack, dan range auto-shoot.
- `resources/actors/enemy_dummy.tres`
  HP enemy, movement speed, contact damage, contact cooldown, dan peluang drop HP.
- `resources/projectiles/player_projectile.tres`
  Kecepatan dan lifetime projectile.
- `resources/spawners/enemy_spawner_default.tres`
  Interval spawn, jumlah enemy per wave, scaling spawn, dan batas area spawn.
- `resources/items/health_pickup.tres`
  Jumlah HP yang dipulihkan pickup.

## Alur gameplay

1. `PlayerController` membaca `PlayerConfig`, lalu mengisi HP awal ke `GameState`.
2. `EnemySpawner` membaca `SpawnerConfig`, lalu spawn enemy secara berkala.
3. `EnemyController` membaca `EnemyConfig`, lalu mengejar player.
4. Player auto-shoot ke enemy terdekat dalam range.
5. `Projectile` memanggil `take_damage()` pada enemy yang terkena.
6. Saat enemy mati, enemy dapat spawn `HealthPickup` secara random.
7. `HealthPickup` memanggil `heal()` pada player.
8. `PlayerHud` mendengar event `player_health_changed` dari `EventBus`.
9. Jika HP player habis, `PlayerController` memanggil `player_died`.
10. `GameOverScreen` muncul dan menyediakan tombol Restart/Keluar.

## Catatan maintenance

- Untuk balancing, utamakan edit file `.tres` di `resources/`, bukan script.
- Untuk komunikasi antar sistem, pakai signal di `autoload/EventBus.gd`.
- Untuk state global seperti HP player dan mode game, pakai `autoload/GameState.gd`.
- Hindari spawn/free node physics langsung dari callback collision. Gunakan `call_deferred()` jika mengubah scene tree dari signal physics seperti `body_entered`.
- Entity yang perlu dicari sistem lain sebaiknya memakai group, misalnya `player` dan `enemy`.
