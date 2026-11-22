#!/usr/bin/env python3
"""Cắt 5 sprite sheet "Effect Bullet Impact Explosion 32x32" (Blue/Green/Purple/Red/Yellow, mỗi sheet 640x512) thành
từng chuỗi hoạt ảnh RỜI: <out>/<Color>/<id>/0001.png, 0002.png ...  (mỗi thư mục = một hiệu ứng, dùng thẳng làm SpellData.vfx_folder).

Cả 5 sheet có CÙNG mặt nạ (đã kiểm tra), nên dùng một bảng cắt cho tất cả. Quy tắc cắt, để KHÔNG hiệu ứng nào dính điểm ảnh của hiệu ứng khác:
  a00..a09  : cột 0, ảnh tĩnh, cắt theo dải hàng (có hiệu ứng cao hơn 32 px nên không dùng lưới 32).
  b00..b09  : cột 2-4, 3 khung/hiệu ứng, cắt theo dải hàng (chiều cao thay đổi, rộng 32).
  c00..c15  : cột 6-9, 4 khung, lưới 32x32.
  d00..d15  : cột 11-14, 4 khung, lưới 32x32 (d12 = 4 ô lửa nối được với nhau: mỗi ô là một khung hoạt ảnh, vệt lửa).
  e00..e15  : cột 16-19, 4 khung, lưới 32x32.
Cuối cùng script KIỂM TRA mỗi điểm ảnh không trong suốt của sheet nằm trong đúng 1 ảnh cắt (không mất, không trùng).
Chạy:  python3 Tools/slice_fx_sheets.py "<thư mục chứa 5 file png>" "<thư mục xuất>"
"""
import os
import sys

import numpy as np
from PIL import Image

COLORS = ["Blue", "Green", "Purple", "Red"]  # Yellow đã loại bỏ khỏi game (Phase 17)
A_BANDS = [(3, 28), (32, 62), (71, 89), (101, 122), (129, 159), (161, 191), (195, 221), (224, 255), (259, 283), (291, 365)]
B_BANDS = [(0, 31), (32, 63), (64, 111), (112, 147), (148, 223), (224, 255), (256, 319), (320, 351), (352, 399), (400, 431)]
B_COLS = [64, 96, 128]


def regions():
    """Trả về danh sách (id, [(x, y, w, h), ...]) — mỗi tuple là một khung hình."""
    out = []
    for i, (y0, y1) in enumerate(A_BANDS):
        out.append(("a%02d" % i, [(0, y0, 32, y1 - y0 + 1)]))
    for i, (y0, y1) in enumerate(B_BANDS):
        out.append(("b%02d" % i, [(x, y0, 32, y1 - y0 + 1) for x in B_COLS]))
    for letter, x0 in (("c", 192), ("d", 352), ("e", 512)):
        for r in range(16):
            out.append(("%s%02d" % (letter, r), [(x0 + 32 * k, r * 32, 32, 32) for k in range(4)]))
    return out


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    regs = regions()
    for color in COLORS:
        path = os.path.join(src, "%s Effect Bullet Impact Explosion 32x32.png" % color)
        sheet = Image.open(path).convert("RGBA")
        alpha = np.array(sheet.getchannel("A")) > 0
        covered = np.zeros(alpha.shape, dtype=np.int32)
        count = 0
        for rid, frames in regs:
            folder = os.path.join(dst, color, rid)
            os.makedirs(folder, exist_ok=True)
            for n, (x, y, w, h) in enumerate(frames, 1):
                sheet.crop((x, y, x + w, y + h)).save(os.path.join(folder, "%04d.png" % n))
                covered[y:y + h, x:x + w] += 1
                count += 1
        bad_missing = int((alpha & (covered == 0)).sum())
        bad_overlap = int((covered > 1).sum())
        print("%s: %d hiệu ứng, %d khung | pixel bị bỏ sót: %d | vùng cắt chồng nhau: %d" % (color, len(regs), count, bad_missing, bad_overlap))
        if bad_missing or bad_overlap:
            sys.exit("Bảng cắt sai!")


if __name__ == "__main__":
    main()
