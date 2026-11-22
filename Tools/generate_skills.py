#!/usr/bin/env python3
"""Sinh các kỹ năng nhiều bước (Resources/Spells/Library/sk_*.tres) từ bảng mô tả bên dưới.
Chạy:  python3 Tools/generate_skills.py     (từ thư mục gốc project)
Sửa số liệu / thêm kỹ năng = sửa bảng SKILLS rồi chạy lại. Mỗi kỹ năng là các bước (SkillStep) chạy theo thời gian,
xem Resources/SkillStep.gd. Chỉ dùng 4 màu: Red (lửa), Blue (băng), Green (độc/gió), Purple (bóng tối). KHÔNG dùng Yellow.
"""
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Resources", "Spells", "Library")
FX = "res://Assets/Spell/Effect Bullet Impact Explosion 32x32/Sliced"
COLORS = {"Red": (0.95, 0.3, 0.25), "Blue": (0.35, 0.6, 1.0), "Green": (0.4, 0.85, 0.45), "Purple": (0.72, 0.42, 0.95)}
DMG_TYPE = {"Red": 1, "Blue": 2, "Green": 0, "Purple": 4}
VFX, BURST, PROJ, ZONE = 0, 1, 2, 3
CASTER, FRONT, AIM, PATH = 0, 1, 2, 3
KIND_SKILL, KIND_DASH = 4, 5


def fx(color, fid):
    return f"{FX}/{color}/{fid}"


class S:
    """Một bước. Tham số = tên trường SkillStep (xem SkillStep.gd)."""
    def __init__(self, type, **kw):
        self.type = type
        self.kw = kw


def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, tuple):
        return "Vector2(%s, %s)" % (v[0], v[1])
    if isinstance(v, str):
        return '"%s"' % v.replace('"', '\\"')
    return str(v)


def build_skill(sk):
    color = sk["color"]
    subs = []  # (id, [(prop, value_str)])

    def emit(step):
        extra = {}
        if "trail" in step.kw:
            extra["trail"] = 'SubResource("%s")' % emit(step.kw["trail"])
        if "on_end" in step.kw:
            ids = [emit(c) for c in step.kw["on_end"]]
            extra["on_end"] = 'Array[ExtResource("2_step")]([%s])' % ", ".join('SubResource("%s")' % i for i in ids)
        sid = "step_%d" % (len(subs) + 1)
        props = [("script", 'ExtResource("2_step")'), ("type", str(step.type))]
        for k, v in step.kw.items():
            if k in ("trail", "on_end"):
                continue
            props.append((k, fmt(v)))
        for k, v in extra.items():
            props.append((k, v))
        subs.append((sid, props))
        return sid

    top = [emit(s) for s in sk["steps"]]
    rgb = COLORS[color]
    lines = ['[gd_resource type="Resource" script_class="SpellData" format=3]', "",
             '[ext_resource type="Script" path="res://Resources/SpellData.gd" id="1_spell"]',
             '[ext_resource type="Script" path="res://Resources/SkillStep.gd" id="2_step"]', ""]
    for sid, props in subs:
        lines.append('[sub_resource type="Resource" id="%s"]' % sid)
        lines += ["%s = %s" % (k, v) for k, v in props]
        lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("1_spell")')
    lines.append('id = &"%s"' % sk["id"])
    lines.append('display_name = "%s"' % sk["name"])
    lines.append('description = "%s"' % sk["desc"].replace('"', "'"))
    lines.append("color = Color(%s, %s, %s, 1)" % rgb)
    lines.append("cooldown = %s" % float(sk["cooldown"]))
    lines.append("damage = %s" % float(sk.get("damage", DISPLAY_DAMAGE.get(sk["id"], 0.0))))
    lines.append("kind = %d" % sk.get("kind", KIND_SKILL))
    lines.append("cast_time = %s" % float(sk.get("cast_time", 0.1)))
    lines.append("recovery_time = %s" % float(sk.get("recovery", 0.25)))
    lines.append("damage_type = %d" % DMG_TYPE[color])
    if sk.get("ignore_kb"):
        lines.append("ignores_knockback_resistance = true")
    lines.append("steps = Array[ExtResource(\"2_step\")]([%s])" % ", ".join('SubResource("%s")' % i for i in top))
    if "charge" in sk:
        folder, scale, off = sk["charge"]
        lines.append('charge_vfx_folder = "%s"' % fx(color, folder))
        lines.append("charge_vfx_scale = %s" % float(scale))
        lines.append("charge_offset = %s" % float(off))
    ic, frame = sk["icon"]
    lines.append('icon_folder = "%s"' % fx(color, ic))
    lines.append("icon_frame = %d" % frame)
    lines.append("")
    return "\n".join(lines)


# Số sát thương "chính" hiển thị trong mô tả/kho (SpellData.damage); sát thương thật nằm trong từng bước.
DISPLAY_DAMAGE = {"sk_magma_stone": 45, "sk_sonic_flares": 45, "sk_inferno_dash_puff": 30, "sk_blazing_meteor": 55, "sk_disc_slash": 22,
                  "sk_sonic_wave": 18, "sk_frost_nova_barrage": 30, "sk_tornado_bloom": 35, "sk_vortex_slash": 28, "sk_toxic_cloud": 25,
                  "sk_void_orb": 40, "sk_shadow_seal": 30}

SKILLS = []

# ------------------------------------------------------------------------------------------------ Do người dùng mô tả
R = "Red"
SKILLS.append(dict(
    id="sk_magma_stone", name="Magma Stone", color=R, cooldown=6, cast_time=0.5, recovery=0.2,
    desc="Tích tụ 0.5s, bắn viên đá nham thạch lăn về phía con trỏ (tối đa 8 ô), để lại vệt lửa 4s (14 sát thương/giây). Phát nổ ở cuối đường hoặc khi chạm kẻ địch (45 sát thương).",
    charge=("d04", 2.6, 18), icon=("e03", 0),
    steps=[
        S(VFX, vfx_folder=fx(R, "c03"), anchor=FRONT, offset=26.0, vfx_scale=2.6, vfx_fps=16.0, rotate_to_dir=True),
        S(PROJ, vfx_folder=fx(R, "e03"), anchor=FRONT, offset=22.0, vfx_scale=2.0, vfx_fps=8.0, speed=200.0, max_range=256.0,
          stop_at_aim=True, contact_radius=12.0, spin_deg_per_sec=300.0,
          trail=S(ZONE, vfx_folder=fx(R, "d12"), vfx_scale=1.6, vfx_fps=10.0, duration=4.0, radius=20.0, damage=14.0, damage_type=1, tick_interval=1.0),
          trail_spacing=20.0,
          on_end=[S(BURST, vfx_folder=fx(R, "c05"), vfx_scale=3.0, vfx_fps=14.0, radius=60.0, damage=45.0, damage_type=1)]),
    ]))

SKILLS.append(dict(
    id="sk_sonic_flares", name="Sonic Flares", color=R, cooldown=7, cast_time=0.2, recovery=0.3, ignore_kb=True,
    desc="Đấm mạnh về phía con trỏ: tụ năng lượng 0.2s, hình thành quả cầu rồi nổ (40 sát thương trước mặt), sau đó bắn 5 luồng lửa bay nhanh 8 ô, nổ khi chạm hoặc hết tầm (45 sát thương, đẩy lùi 2 ô).",
    charge=("e02", 2.2, 26), icon=("d15", 1),
    steps=[
        S(VFX, vfx_folder=fx(R, "e01"), anchor=FRONT, offset=46.0, vfx_scale=2.2, vfx_fps=14.0, duration=0.3),
        S(BURST, vfx_folder=fx(R, "e12"), delay=0.3, anchor=FRONT, offset=62.0, vfx_scale=3.0, vfx_fps=14.0, radius=58.0, damage=40.0, damage_type=1),
        S(PROJ, vfx_folder=fx(R, "d15"), delay=0.32, anchor=FRONT, offset=62.0, vfx_scale=1.8, vfx_fps=16.0, rotate_to_dir=True,
          count=5, spread_deg=60.0, speed=520.0, max_range=256.0, contact_radius=10.0,
          on_end=[S(BURST, vfx_folder=fx(R, "e00"), vfx_scale=2.4, vfx_fps=16.0, radius=46.0, damage=45.0, damage_type=1, knockback_force=340.0)]),
    ]))

SKILLS.append(dict(
    id="sk_inferno_dash_puff", name="Inferno Dash Puff", color=R, cooldown=4, cast_time=0.0, recovery=0.0, kind=KIND_DASH,
    desc="Nâng cấp dash: đến nơi tạo Inferno Puff + vụ nổ (30 sát thương, biến mất sau 0.4s) và để lại wildfire dọc đường lướt (12 sát thương, 1s). Đang hồi chiêu thì dash như thường.",
    icon=("c06", 1),
    steps=[
        S(VFX, vfx_folder=fx(R, "c06"), anchor=CASTER, vfx_scale=3.0, vfx_fps=10.0, duration=0.4),
        S(BURST, vfx_folder=fx(R, "e12"), anchor=CASTER, vfx_scale=3.2, vfx_fps=10.0, duration=0.4, radius=56.0, damage=30.0, damage_type=1),
        S(ZONE, vfx_folder=fx(R, "e09"), anchor=PATH, path_spacing=28.0, vfx_scale=2.0, vfx_fps=10.0, duration=1.0, radius=22.0, damage=12.0, damage_type=1, tick_interval=1.0),
    ]))

# ------------------------------------------------------------------------------------------------ Kỹ năng thiết kế thêm
SKILLS.append(dict(
    id="sk_blazing_meteor", name="Blazing Meteor", color=R, cooldown=9, cast_time=0.35, recovery=0.3,
    desc="Đánh dấu vùng ngắm, 0.6s sau thiên thạch chính giáng xuống (55 sát thương) kèm 3 mảnh vụn nổ lần lượt xung quanh (25 sát thương) và để lại mặt đất cháy 3s.",
    charge=("c07", 2.4, 10), icon=("c09", 0),
    steps=[
        S(VFX, vfx_folder=fx(R, "e07"), anchor=AIM, max_range=320.0, vfx_scale=4.5, vfx_fps=6.0, duration=0.6),
        S(BURST, vfx_folder=fx(R, "c09"), delay=0.6, anchor=AIM, max_range=320.0, vfx_scale=4.0, vfx_fps=14.0, radius=80.0, damage=55.0, damage_type=1, knockback_force=220.0),
        S(BURST, vfx_folder=fx(R, "e12"), delay=0.6, anchor=AIM, max_range=320.0, vfx_scale=4.5, vfx_fps=12.0),
        S(ZONE, vfx_folder=fx(R, "d12"), delay=0.7, anchor=AIM, max_range=320.0, vfx_scale=2.2, vfx_fps=10.0, duration=3.0, radius=56.0, damage=10.0, damage_type=1, tick_interval=1.0),
        S(BURST, vfx_folder=fx(R, "c15"), delay=0.85, anchor=AIM, max_range=320.0, pos_offset=(-76.0, -30.0), vfx_scale=2.4, vfx_fps=14.0, radius=48.0, damage=25.0, damage_type=1),
        S(BURST, vfx_folder=fx(R, "c15"), delay=1.0, anchor=AIM, max_range=320.0, pos_offset=(74.0, -26.0), vfx_scale=2.4, vfx_fps=14.0, radius=48.0, damage=25.0, damage_type=1),
        S(BURST, vfx_folder=fx(R, "c15"), delay=1.15, anchor=AIM, max_range=320.0, pos_offset=(4.0, 70.0), vfx_scale=2.4, vfx_fps=14.0, radius=48.0, damage=25.0, damage_type=1),
    ]))

B = "Blue"
SKILLS.append(dict(
    id="sk_disc_slash", name="Disc Slash", color=B, cooldown=5, cast_time=0.15, recovery=0.25,
    desc="Chém một đường cung băng, tung 3 đĩa băng xoáy xuyên qua tối đa 3 kẻ địch (22 sát thương mỗi lần chạm) rồi vỡ vụn.",
    charge=("c10", 2.0, 14), icon=("c14", 0),
    steps=[
        S(VFX, vfx_folder=fx(B, "b02"), anchor=FRONT, offset=30.0, vfx_scale=3.0, vfx_fps=14.0, rotate_to_dir=True, vfx_rotation_offset_deg=180.0),
        S(PROJ, vfx_folder=fx(B, "c14"), delay=0.05, anchor=FRONT, offset=26.0, vfx_scale=2.0, vfx_fps=16.0, rotate_to_dir=True,
          count=3, spread_deg=36.0, speed=440.0, max_range=240.0, contact_radius=14.0, pierce=2, damage=22.0, damage_type=2, knockback_force=120.0,
          on_end=[S(VFX, vfx_folder=fx(B, "c10"), vfx_scale=2.0, vfx_fps=16.0)]),
    ]))

SKILLS.append(dict(
    id="sk_sonic_wave", name="Sonic Wave", color=B, cooldown=6, cast_time=0.25, recovery=0.3,
    desc="Phát ba đợt sóng âm hình cung liên tiếp, xuyên mọi kẻ địch trên đường (18 sát thương mỗi đợt, đẩy lùi nhẹ).",
    charge=("e06", 2.4, 16), icon=("b06", 0),
    steps=[
        S(PROJ, vfx_folder=fx(B, "b06"), delay=0.0 + i * 0.14, anchor=FRONT, offset=24.0, vfx_scale=3.0, vfx_fps=12.0, rotate_to_dir=True,
          speed=380.0, max_range=288.0, contact_radius=18.0, pierce=99, damage=18.0, damage_type=2, knockback_force=140.0,
          on_end=[S(VFX, vfx_folder=fx(B, "c10"), vfx_scale=1.6, vfx_fps=16.0)])
        for i in range(3)
    ]))

SKILLS.append(dict(
    id="sk_frost_nova_barrage", name="Frost Nova Barrage", color=B, cooldown=8, cast_time=0.3, recovery=0.3,
    desc="Nổ băng quanh người (30 sát thương, đẩy lùi), sau đó 8 mũi băng bắn ra mọi hướng, nổ khi chạm hoặc hết tầm (20 sát thương).",
    charge=("c11", 2.4, 0), icon=("c01", 0),
    steps=[
        S(BURST, vfx_folder=fx(B, "c01"), anchor=CASTER, vfx_scale=4.0, vfx_fps=14.0, radius=92.0, damage=30.0, damage_type=2, knockback_force=300.0),
        S(PROJ, vfx_folder=fx(B, "d10"), delay=0.3, anchor=CASTER, offset=30.0, vfx_scale=1.6, vfx_fps=14.0, rotate_to_dir=True,
          count=8, spread_deg=315.0, speed=360.0, max_range=210.0, contact_radius=10.0,
          on_end=[S(BURST, vfx_folder=fx(B, "c11"), vfx_scale=1.8, vfx_fps=14.0, radius=44.0, damage=20.0, damage_type=2)]),
    ]))

G = "Green"
SKILLS.append(dict(
    id="sk_tornado_bloom", name="Tornado Bloom", color=G, cooldown=10, cast_time=0.35, recovery=0.3,
    desc="Hoa gió nở tại con trỏ (20 sát thương), lốc xoáy quay 3s (9 sát thương mỗi 0.5s) rồi nổ tung khi kết thúc (35 sát thương, đẩy lùi).",
    charge=("c01", 2.0, 12), icon=("c00", 0),
    steps=[
        S(BURST, vfx_folder=fx(G, "c01"), anchor=AIM, max_range=300.0, vfx_scale=3.2, vfx_fps=14.0, radius=62.0, damage=20.0, damage_type=0),
        S(ZONE, vfx_folder=fx(G, "c00"), delay=0.15, anchor=AIM, max_range=300.0, vfx_scale=2.6, vfx_fps=12.0, duration=3.0, radius=54.0, damage=9.0, damage_type=0, tick_interval=0.5),
        S(BURST, vfx_folder=fx(G, "c09"), delay=3.15, anchor=AIM, max_range=300.0, vfx_scale=3.2, vfx_fps=14.0, radius=70.0, damage=35.0, damage_type=0, knockback_force=260.0),
    ]))

SKILLS.append(dict(
    id="sk_vortex_slash", name="Vortex Slash", color=G, cooldown=7, cast_time=0.2, recovery=0.3,
    desc="Hai nhát chém cung liên tiếp (28 sát thương mỗi nhát) rồi xoáy lốc 2s trước mặt (7 sát thương mỗi 0.4s).",
    charge=("e04", 2.0, 20), icon=("d02", 0),
    steps=[
        S(BURST, vfx_folder=fx(G, "b02"), anchor=FRONT, offset=42.0, vfx_scale=3.2, vfx_fps=14.0, rotate_to_dir=True, vfx_rotation_offset_deg=180.0, radius=58.0, damage=28.0, damage_type=0, knockback_force=160.0),
        S(BURST, vfx_folder=fx(G, "b05"), delay=0.16, anchor=FRONT, offset=46.0, vfx_scale=3.2, vfx_fps=14.0, rotate_to_dir=True, radius=58.0, damage=28.0, damage_type=0, knockback_force=160.0),
        S(ZONE, vfx_folder=fx(G, "d02"), delay=0.3, anchor=FRONT, offset=70.0, vfx_scale=2.6, vfx_fps=14.0, duration=2.0, radius=54.0, damage=7.0, damage_type=0, tick_interval=0.4),
    ]))

SKILLS.append(dict(
    id="sk_toxic_cloud", name="Toxic Cloud", color=G, cooldown=8, cast_time=0.3, recovery=0.25,
    desc="Ném bình độc về phía con trỏ, nổ (25 sát thương) và để lại đám mây độc 4s (6 sát thương mỗi 0.5s).",
    charge=("c08", 1.8, 14), icon=("e05", 1),
    steps=[
        S(PROJ, vfx_folder=fx(G, "c08"), anchor=FRONT, offset=18.0, vfx_scale=1.8, vfx_fps=10.0, speed=280.0, max_range=288.0,
          stop_at_aim=True, contact_radius=12.0, spin_deg_per_sec=360.0,
          on_end=[S(BURST, vfx_folder=fx(G, "c09"), vfx_scale=2.8, vfx_fps=14.0, radius=60.0, damage=25.0, damage_type=0),
                  S(ZONE, vfx_folder=fx(G, "e05"), delay=0.1, vfx_scale=3.0, vfx_fps=8.0, duration=4.0, radius=58.0, damage=6.0, damage_type=0, tick_interval=0.5)]),
    ]))

P = "Purple"
SKILLS.append(dict(
    id="sk_void_orb", name="Void Orb", color=P, cooldown=8, cast_time=0.4, recovery=0.3,
    desc="Quả cầu hư không bay chậm xuyên qua kẻ địch (15 sát thương mỗi mục tiêu), nổ ở cuối đường (40 sát thương, đẩy lùi).",
    charge=("d08", 2.0, 18), icon=("e08", 0),
    steps=[
        S(PROJ, vfx_folder=fx(P, "e08"), anchor=FRONT, offset=22.0, vfx_scale=2.0, vfx_fps=12.0, speed=130.0, max_range=224.0,
          contact_radius=16.0, pierce=99, damage=15.0, damage_type=4, spin_deg_per_sec=-200.0,
          on_end=[S(BURST, vfx_folder=fx(P, "e12"), vfx_scale=3.4, vfx_fps=14.0, radius=64.0, damage=40.0, damage_type=4, knockback_force=240.0)]),
    ]))

SKILLS.append(dict(
    id="sk_shadow_seal", name="Shadow Seal", color=P, cooldown=9, cast_time=0.3, recovery=0.3,
    desc="Khắc ấn bóng tối tại con trỏ: 3s gây 10 sát thương mỗi 0.5s cho kẻ đứng trong ấn, rồi ấn vỡ tung (30 sát thương).",
    charge=("e14", 2.2, 12), icon=("d09", 0),
    steps=[
        S(VFX, vfx_folder=fx(P, "d08"), anchor=AIM, max_range=300.0, vfx_scale=3.6, vfx_fps=8.0, vfx_loop=True, duration=3.0),
        S(ZONE, vfx_folder=fx(P, "d09"), anchor=AIM, max_range=300.0, vfx_scale=3.2, vfx_fps=8.0, duration=3.0, radius=62.0, damage=10.0, damage_type=4, tick_interval=0.5),
        S(BURST, vfx_folder=fx(P, "c05"), delay=3.0, anchor=AIM, max_range=300.0, vfx_scale=3.4, vfx_fps=14.0, radius=66.0, damage=30.0, damage_type=4, knockback_force=180.0),
    ]))


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.startswith("sk_") and f.endswith(".tres"):
            os.remove(os.path.join(OUT, f))
    for sk in SKILLS:
        assert "Yellow" not in sk["color"]
        with open(os.path.join(OUT, sk["id"] + ".tres"), "w", encoding="utf-8") as fh:
            fh.write(build_skill(sk))
    print("Đã sinh %d kỹ năng vào %s" % (len(SKILLS), OUT))


if __name__ == "__main__":
    main()
