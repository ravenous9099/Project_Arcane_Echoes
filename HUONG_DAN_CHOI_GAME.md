# ARCANE ECHOES – Bảng hướng dẫn sử dụng

## 1. Điều khiển khi chơi
| Phím / chuột | Chức năng |
|---|---|
| W A S D | Di chuyển |
| Chuột trái | Spell ô 1 |
| Q | Spell ô 2 |
| E | Spell ô 3 |
| R | Ô Ultimate (chỉ có sau khi hạ Boss 1) |
| Space | Lướt (dash, có khung bất tử ngắn; lướt sát lúc đòn trúng = né hoàn hảo) |
| Esc | Tạm dừng / tiếp tục (menu: Tiếp tục, Chơi lại, Chữ debug, Menu chính, Thoát) |
| F5 | Chơi lại ngay |
| Enter | Chơi lại khi đã chết |
| 1 / 2 / 3, Backspace | Khi nhặt spell thứ 4: chọn ô bị thay (1 = chuột trái, 2 = Q, 3 = E), Backspace = bỏ qua |
| F1 | Bật/tắt bảng thống kê (DebugStats) |

## 2. Phím debug (chỉ để thử nghiệm, nên bỏ khi phát hành)
| Phím | Chức năng |
|---|---|
| F2 | Sinh 1 quái |
| F3 | Vẽ debug bản đồ |
| F4 / F10 | Stress test quái / test hiệu năng |
| F6 | Bật/tắt thanh máu Boss |
| F7 | +50 điểm |
| F8 | Dịch chuyển tới cổng Boss |
| F9 | Chạy integration test |
| B | Vào thẳng phòng Boss |
| K | Giết quái gần nhất |
| T | Test spell |
| Y | Nhặt spell kế tiếp |
| L | Giả lập Player chết |
| P | Tạm dừng kiểu cũ (nếu bật `debug_pause_key_enabled`) |

## 3. Luồng chơi
Menu chính → (cutscene, nếu có) → **Level 1** → Boss 1 (rơi Ultimate) → **Level 2** → Boss 2 → **Level 3** (băng tuyết) → Boss 3 → quay lại **Level 1** (vòng mới) cho tới khi chết.

## 4. Điểm qua màn và số lượng quái
Điểm cộng dồn qua các màn. "Điểm mở cổng" tính từ điểm lúc bắt đầu màn đó (sau điểm thưởng boss).
| | Level 1 | Level 2 | Level 3 |
|---|---|---|---|
| Giao diện map | mặc định | mùa thu | băng tuyết |
| Quái | Archer, Knight, Mage | Archer, Knight, Mage, Paladin, Wizard | CamoArcher (thay Archer), Knight, Mage, Paladin, Wizard |
| Tỉ lệ xuất hiện | Archer 2 : Knight 5 : Mage 3, **tối đa 2 Mage cùng lúc** | đều | CamoArcher 3, Knight 3, các loại còn lại 2 |
| Điểm mở cổng Boss | 400 | điểm hiện có + 400 | điểm hiện có + 400 |
| Ví dụ (đạt đúng mục tiêu) | 400 | 580 + 400 = 980 | 980 + 400 = 1380 |
| Điểm thưởng khi hạ Boss | +180 | 0 | 0 |
| Spell tối đa trên map | 2 | không giới hạn | không giới hạn |
| Quái nền (0 spell) | 3 | 5 | 5 |
| Quái cộng thêm mỗi spell | 3 | 2,5 | 2,5 |
| Mốc thưởng thêm | ≥1 spell: +2, ≥2 spell: +3 | ≥2: +2, ≥4: +4 | ≥2: +2, ≥4: +4 |
| Giãn cách spawn (s) | 2,0 | 1,8 | 1,8 |
| Boss | Chúa Tể Bóng Tối (1400 máu) | Hiệp Sĩ Tử Thần (1700) | Xạ Thủ Cung Dài (1300) |
| Phòng Boss | 4 cột đá | sân cát, 8 cột nhỏ vòng ngoài | sân băng, 10 khối đá/băng để nấp |

Công thức số quái: quái nền + làm tròn(số spell × quái mỗi spell) + thưởng mốc, bị chặn bởi tối đa 30. Mỗi spell còn làm nhịp spawn nhanh hơn 10% (tối thiểu 0,6 s).
Vòng lặp sau Boss 3: quay lại Level 1, mục tiêu = điểm hiện có + 400.

| Quái | Máu | Điểm |
|---|---|---|
| Knight | 50 | 10 |
| Archer | 30 | 15 |
| Mage | 34 | 20 |
| Wizard | 36 | 20 |
| CamoArcher | 34 | 20 |
| Paladin | 130 | 30 |

**Trạng thái bất lợi**: choáng (không di chuyển, không dùng spell, không lướt) và trói chân (không đi/lướt được nhưng vẫn dùng spell, trừ R). Sau mỗi lần hết hiệu ứng có 0,8 s miễn nhiễm. CamoArcher bắn tên băng 15 sát thương, choáng 0,5 s; Boss 3 dùng cả choáng lẫn trói chân.

## 5. Ultimate lửa đỏ (ô R)
- Rơi sau khi hạ Boss 1; nhặt rồi luôn nằm ô R, không bị thay.
- **R thường** (hồi chiêu 4 s): lao 2–3 ô về phía chuột, đấm lửa mạnh. Trong lúc lao bạn bất tử.
- **Thanh mana** (hiện sau khi nhặt, bắt đầu 0): +5 mỗi đòn trúng, +10 mỗi quái hạ. Sau 1 s không đánh trúng, mana tụt 6/giây.
- **Đủ 100 mana**: ngừng tụt, hồi chiêu R reset, ô R sáng viền vàng "ULT". Bấm R: lao 7–10 ô, đấm liên hoàn 6 nhát, kết thúc bằng sóng xung kích đẩy lùi mọi kẻ địch kể cả Boss. Tiêu 100 mana.

## 6. Cài đặt bản đồ (Map)
Chọn node **World** trong `Main.tscn` (scene `procedural_level.tscn`), chỉnh ở Inspector (script MapGenerator.gd).
| Nhóm | Thuộc tính | Tác dụng |
|---|---|---|
| Kích thước | map_width / map_height (96 × 64) | Số ô của bản đồ; tile_size = 32 px |
| Seed | use_random_seed, fixed_seed | Tắt random và đặt seed để map luôn giống nhau |
| Phòng | min_room_size, room_margin, max_leaf_size, room_size_variance | Kích thước và độ thưa của phòng |
| Đường đi | corridor_width, extra_corridors, path_winding, side_branches, branch_length_min/max, path_edge_roughness | Độ rộng, số đường vòng, độ uốn lượn, đường nhánh |
| Trang trí đường | stone_patches_per_room, path_prop_density | Mảng đá, vật nhỏ trên đường |
| Cây và vật cản | tree_density (0,08), tree_clump_threshold, room_obstacle_ratio, grass_decor_density, start_clear_radius, max_unreachable_cells | Mật độ cây (giảm để thưa), vật cản trong phòng, vùng trống quanh điểm xuất phát |
| Cổng Boss | plaza_radius, portal_no_spawn_radius (260) | Kích thước quảng trường cổng, bán kính không sinh quái quanh cổng |
| Phòng Boss | arena_cell_size, arena_grid_size, arena_radius_cells | Kích thước đấu trường |
Theme map (Level 2 mùa thu) do `Scripts/Systems/MapTheme.gd`; asset Environment đặt đúng thư mục ghi trong HUONG_DAN_PHASE9.md.

## 7. Cài đặt màn chơi, quái, độ khó
| Muốn chỉnh | Ở đâu |
|---|---|
| Điểm qua màn, điểm thưởng Boss, loại quái, tỉ lệ và giới hạn từng loại (`enemy_weights`, `enemy_caps`), số quái, spell tối đa, nhịp spawn | `Resources/Levels/level_1.tres`, `level_2.tres`, `level_3.tres` (mở bằng Inspector) |
| Quái tối đa, khoảng cách sinh quái (350–900 px), hệ số nhịp theo spell | node EnemySpawner trong `Main.tscn` (giá trị ngưỡng được level ghi đè khi vào màn) |
| Máu, tốc độ, điểm từng quái | `Scenes/Enemies/*.tscn` (max_health, move_speed, score_value) |
| Máu người chơi (100), lướt (tốc độ 560, hồi 0,9 s) | `Scenes/Player/player.tscn` |
| Độ khó chung | `Resources/CombatTuning.gd` (tài nguyên CombatTuning): enemy_health/damage/speed_multiplier, player_damage_multiplier, boss_damage_multiplier |
| Mana / Ultimate | CombatTuning, nhóm "Mana / Ultimate": mana_max 100, mana_per_hit 5, mana_per_kill 10, mana_decay_per_second 6, mana_decay_delay 1 |
| Hiệu ứng | CombatTuning: hitstop, rung màn hình, âm thanh, hiện số sát thương, hệ số đẩy lùi |
| Sát thương/tầm Ultimate | `Resources/Spells/fire_fist*.tres` |
| Boss 2: chu kỳ triệu hồi (6 s), số lính (2), tối đa (8), combo, nhảy | `Scenes/Enemies/DeathKnightBoss.tscn` |
| Boss 3: triệu hồi CamoArcher (7 s), số phát BARRAGE, số bẫy, lùi nhanh | `Scenes/Enemies/LongbowBoss.tscn` |
| Hiệu ứng choáng/trói của tên và bẫy | `stun_duration`, `root_duration` trong `Resources/EnemyAttacks/ice_arrow.tres`, `Resources/BossAttacks/lb_*.tres` |
| Miễn nhiễm sau choáng/trói | `status_immunity_time` trong player.gd |
| Hình nền / logo menu, cutscene | `Scenes/UI/MainMenu.tscn` (background_texture, logo_texture, cutscene_scene) |

## 8. Khi đang chơi
- Thanh điểm trên HUD là tiến độ tới mục tiêu của màn hiện tại. Đủ điểm thì cổng Boss mở; đi vào cổng để gặp Boss.
- Ô spell hiện hồi chiêu; viền vàng "ULT" nghĩa là Ultimate sẵn sàng.
- Các giá trị trên là mặc định ở bản Phase 9 chưa test trong Godot; có thể lệch nếu bạn đã chỉnh trong Inspector.


## Bổ sung Phase 11
- **Tab**: mở kho Spell, kéo thả biểu tượng vào ô Chuột trái / Q / E. Esc hoặc Tab để đóng.
- **Shockwave Shield**: phần thưởng sau Boss level 2 (thay Thunder), hồi chiêu 20s, hồi 20 HP, miễn sát thương 2.5s, đẩy lùi Enemy, choáng Boss.
- **Viên máu**: Enemy chết có 12% rơi, nhặt hồi 20 HP.
- **Mini map**: góc trên phải, chấm đỏ là Enemy. Spell ngẫu nhiên chỉ còn Fireball, Frost Shard, Shadow Burst.


## Bổ sung Phase 12
- **Combo** (cạnh phải): đánh trúng +1, né hoàn hảo +2, bị thương -2; mỗi 5 điểm lên 1 hạng (F→SSS), 2.5s không có điểm thì tụt hạng. Hạng cao tăng sát thương, giảm hồi chiêu, hồi máu khi hạ Enemy.
- **Vàng**: Enemy rơi 30% (3-7 đồng), Boss 100-120. Dùng mua relic.
- **Sảnh chờ**: vào đầu lượt chơi và sau mỗi Boss. F nói chuyện với Người Giữ Đèn (lưu game) và Relic Merchant (mua/bán relic). Cổng phía bắc sang level kế.
- **Tiếp tục**: menu chính hiện nút khi có file lưu.

## Phase 13
- **Chơi mới** → nhập tên → cutscene → sảnh chờ. Tên hiện trên thanh máu.
- Menu chính có **HALL OF FAME** (top lượt chơi: điểm, ngày giờ, thời gian sống sót, spell đã dùng, sát thương, hạ gục, relic, vàng).
- Bị thương: **tụt 1 hạng combo và mất hết điểm combo đang tích**.
- **Level 4 (cuối)**: hầm ngục đá, 15-20 địch cùng lúc. Phòng Boss chữ nhật rộng; lần lượt 3 Boss (hạ xong mỗi Boss hồi 50% máu). Hạ Boss cuối → ending + hạng Hall of Fame.

## Âm thanh (Phase 14)
Menu tạm dừng (Esc) có hai slider: *Âm lượng hiệu ứng* và *Âm lượng nhạc nền* (kéo về 0 để tắt). Nhạc đổi theo bối cảnh: menu/sảnh, khám phá, phòng Boss, ending. Xem `HUONG_DAN_PHASE14.md`.
