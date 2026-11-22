#!/usr/bin/env python3
"""Nướng ảnh "Scene Overview.png" thành dữ liệu va chạm cho map Ruins (Resources/Maps/ruins_layout.json).

Cách làm: phân loại từng điểm ảnh theo màu (cỏ + đá lát = đi được; tường gạch, đồ vật, nền = chặn),
làm sạch bằng phép biến đổi hình thái, ép đi được ở các cầu thang, chặn thân cây, rồi gom thành lưới ô.
Chạy lại khi muốn chỉnh: python3 Tools/bake_ruins_layout.py <ảnh> <json_ra> [overlay.png]
Cần: pip install pillow numpy opencv-python
"""
import json, sys
import numpy as np, cv2
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else "Scene Overview.png"
OUT = sys.argv[2] if len(sys.argv) > 2 else "ruins_layout.json"
OVERLAY = sys.argv[3] if len(sys.argv) > 3 else None
CELL = 6  # số điểm ảnh gốc mỗi ô (ảnh 1200 -> lưới 200x200)

# ---- Toạ độ theo điểm ảnh của ảnh gốc 1200x1200 ----
# Cầu thang: ép đi được (màu bậc thang giống tường nên không tự nhận ra).
STAIR_RECTS = [
    (650, 146, 704, 238),   # lên sân cổng Boss (phía trên cùng)
    (390, 364, 438, 464),   # dưới bệ tượng, bên trái
    (578, 498, 636, 584),   # giữa map
    (806, 660, 858, 746),   # bên phải
    (322, 880, 378, 974),   # góc dưới trái
]
STAIR_POLYS = [
    [(198, 540), (255, 494), (292, 494), (292, 556), (250, 592), (214, 588)],  # thang chéo, bệ trái
    [(916, 524), (1008, 524), (1008, 612), (916, 612)],                        # thang chéo, bệ phải
]
# Cây: (tâm x, tâm y, bán kính x, bán kính y) chặn phần thân và tán dưới.
TREES = [(499, 150, 22, 30), (811, 205, 24, 36), (214, 445, 22, 40), (449, 500, 28, 40),
         (562, 780, 22, 34), (1025, 670, 22, 26), (650, 990, 28, 40)]
PORTAL = (674, 91)       # tâm vòng tròn đá ở trên cùng
PORTAL_RADIUS = 34
START = (560, 640)       # điểm xuất phát mong muốn của Player (sẽ dịch tới ô gần nhất đi được)
CHEST = (640, 693)

img = Image.open(SRC).convert("RGB")
a = np.array(img).astype(int)
R, G, B = a[..., 0], a[..., 1], a[..., 2]
grass = (B < 70) & (R > 100) & (G > 100) & (abs(R - G) < 30)
cobble = (R >= 138) & (R <= 180) & (G >= 136) & (G <= 178) & (B >= 118) & (B <= 165) & ((R - B) >= 3) & ((R - B) <= 28)
walk = (grass | cobble).astype(np.uint8)
walk = cv2.morphologyEx(walk, cv2.MORPH_OPEN, np.ones((7, 7), np.uint8))   # bỏ viền tường mảnh
walk = cv2.morphologyEx(walk, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))  # lấp khe vữa giữa các viên đá
for x0, y0, x1, y1 in STAIR_RECTS:
    walk[y0:y1, x0:x1] = 1
for poly in STAIR_POLYS:
    cv2.fillPoly(walk, [np.array(poly, np.int32)], 1)
cv2.circle(walk, PORTAL, PORTAL_RADIUS, 1, -1)
for cx, cy, rx, ry in TREES:
    cv2.ellipse(walk, (cx, cy), (rx, ry), 0, 0, 360, 0, -1)

h, w = walk.shape
gw, gh = w // CELL, h // CELL
blocked = np.zeros((gh, gw), np.uint8)
for gy in range(gh):
    for gx in range(gw):
        block = walk[gy * CELL:(gy + 1) * CELL, gx * CELL:(gx + 1) * CELL]
        blocked[gy, gx] = 1 if block.mean() < 0.5 else 0

# Ô "đi được cho Player": cả 3x3 xung quanh đều trống (thân Player rộng hơn 1 ô).
free = (blocked == 0).astype(np.uint8)
clear = cv2.erode(free, np.ones((3, 3), np.uint8), borderType=cv2.BORDER_CONSTANT, borderValue=0)

# Tìm ô xuất phát gần START nhất.
sx, sy = START[0] // CELL, START[1] // CELL
best, bd = None, 1e9
for gy in range(gh):
    for gx in range(gw):
        if clear[gy, gx]:
            d = (gx - sx) ** 2 + (gy - sy) ** 2
            if d < bd:
                bd, best = d, (gx, gy)
start_cell = best


def components():
    n, labels = cv2.connectedComponents(clear, connectivity=4)
    return n, labels


def carve_bridges(min_cells=30):
    """Ảnh gốc có nhiều tầng tách nhau bằng vành tường mảnh. Với mỗi vùng đi được nhưng không nối với vùng
    của Player, tìm đường RẺ NHẤT (đi qua ít ô chặn nhất, tức chỗ tường mỏng nhất) tới vùng chính rồi đục lối rộng 3 ô."""
    import heapq
    carved = []
    for _ in range(40):
        n, labels = components()
        main = labels[start_cell[1], start_cell[0]]
        sizes = {i: int((labels == i).sum()) for i in range(1, n) if i != main}
        todo = [(sz, i) for i, sz in sizes.items() if sz >= min_cells]
        if not todo:
            break
        todo.sort(reverse=True)
        comp = todo[0][1]
        dist = np.full((gh, gw), 1e9)
        prev = {}
        pq = []
        for y, x in zip(*np.nonzero(labels == comp)):
            dist[y, x] = 0
            heapq.heappush(pq, (0, int(y), int(x)))
        goal = None
        while pq:
            d, y, x = heapq.heappop(pq)
            if d > dist[y, x]:
                continue
            if labels[y, x] == main:
                goal = (y, x)
                break
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 1 <= ny < gh - 1 and 1 <= nx < gw - 1:
                    nd = d + (8 if blocked[ny, nx] else 1)
                    if nd < dist[ny, nx]:
                        dist[ny, nx] = nd
                        prev[(ny, nx)] = (y, x)
                        heapq.heappush(pq, (nd, ny, nx))
        if goal is None:
            break
        cur, path = goal, []
        while cur in prev:
            path.append(cur)
            cur = prev[cur]
        for y, x in path:
            blocked[y - 1:y + 2, x - 1:x + 2] = 0
        free[:] = (blocked == 0)
        clear[:] = cv2.erode(free, np.ones((3, 3), np.uint8), borderType=cv2.BORDER_CONSTANT, borderValue=0)
        mid = path[len(path) // 2]
        carved.append((mid[1] * CELL, mid[0] * CELL, len(path)))
    return carved


carved = carve_bridges()
print("lối đục thêm (x, y theo ảnh gốc, độ dài ô):", carved)
n, labels = components()
reach = (labels == labels[start_cell[1], start_cell[0]]).astype(np.uint8)
portal_cell = (PORTAL[0] // CELL, PORTAL[1] // CELL)
print("lưới %dx%d | ô trống %d | Player đi được %d | tới được %d" % (gw, gh, free.sum(), clear.sum(), reach.sum()))
print("bắt đầu", start_cell, "| cổng boss tới được:", bool(reach[portal_cell[1], portal_cell[0]]))
unreach = int(clear.sum() - reach.sum())
print("ô đi được nhưng KHÔNG tới được:", unreach)

rows = ["".join("1" if blocked[y, x] else "0" for x in range(gw)) for y in range(gh)]
json.dump({
    "src_size": [w, h], "cell_src": CELL, "grid": [gw, gh], "rows": rows,
    "player_start_cell": list(start_cell), "portal_src": list(PORTAL), "portal_radius_src": PORTAL_RADIUS,
    "chest_src": list(CHEST),
}, open(OUT, "w"), separators=(",", ":"))

if OVERLAY:
    ov = np.array(img).copy()
    for gy in range(gh):
        for gx in range(gw):
            ys, xs = slice(gy * CELL, (gy + 1) * CELL), slice(gx * CELL, (gx + 1) * CELL)
            if blocked[gy, gx]:
                ov[ys, xs] = (ov[ys, xs] * 0.5 + np.array([200, 30, 30]) * 0.5).astype(np.uint8)
            elif clear[gy, gx] and not reach[gy, gx]:
                ov[ys, xs] = (ov[ys, xs] * 0.4 + np.array([30, 60, 255]) * 0.6).astype(np.uint8)
    Image.fromarray(ov).save(OVERLAY)
