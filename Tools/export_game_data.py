#!/usr/bin/env python3
"""Xuất danh mục tài nguyên game (relic, spell, level) từ Resources/*.tres sang Data/game_data.json.
Chạy lại mỗi khi thêm / sửa relic, spell, level:   python3 Tools/export_game_data.py   (chạy ở thư mục gốc project)"""
import json, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

def parse_tres(path):
    props, in_res = {}, False
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("[resource]"):
            in_res = True
            continue
        if line.startswith("[") and in_res:
            break
        if in_res and " = " in line:
            k, v = line.split(" = ", 1)
            props[k.strip()] = v.strip()
    return props

def s(v):  # chuỗi Godot -> str
    m = re.match(r'^&?"(.*)"$', v or "")
    return m.group(1) if m else (v or "")

def num(v, default=0):
    try:
        return float(v) if "." in v else int(v)
    except (TypeError, ValueError):
        return default

out = {"version": 1, "relics": [], "spells": [], "levels": []}
for f in sorted((ROOT / "Resources/Relics").glob("*.tres")):
    p = parse_tres(f)
    row = {"id": s(p.get("id")), "name": s(p.get("display_name")), "description": s(p.get("description")),
           "price": num(p.get("price"), 0), "tier": num(p.get("tier"), 1)}
    for key in ("max_hp_pct", "damage_pct", "cooldown_pct", "move_speed_pct", "kill_heal", "gold_pct", "hp_drop_bonus"):
        if key in p:
            row[key] = num(p[key], 0)
    out["relics"].append(row)
for f in sorted((ROOT / "Resources/Spells").glob("*.tres")):
    p = parse_tres(f)
    if "id" not in p:
        continue
    out["spells"].append({"id": s(p.get("id")), "name": s(p.get("display_name")), "cooldown": num(p.get("cooldown"), 0), "damage": num(p.get("damage"), 0)})
for f in sorted((ROOT / "Resources/Levels").glob("*.tres")):
    p = parse_tres(f)
    out["levels"].append({"id": s(p.get("id")), "name": s(p.get("display_name")), "theme": s(p.get("theme_id")),
                          "goal_points": num(p.get("goal_points"), 0), "max_enemies": num(p.get("max_enemies"), 0)})
dest = ROOT / "Data/game_data.json"
dest.parent.mkdir(exist_ok=True)
dest.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
print("Đã ghi", dest, {k: len(v) for k, v in out.items() if isinstance(v, list)})
