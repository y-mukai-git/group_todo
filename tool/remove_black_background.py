#!/usr/bin/env python3
"""
アプリアイコンから黒背景を削除して透過背景にする
アイコンの角丸形状を検出して、外側の黒背景だけを削除
"""
from PIL import Image
import sys

def remove_black_background_flood_fill(input_path, output_path):
    """
    四隅から塗りつぶし（flood fill）で黒背景を透過にする

    Args:
        input_path: 入力画像パス
        output_path: 出力画像パス
    """
    # 画像を開く
    img = Image.open(input_path).convert('RGBA')
    pixels = img.load()
    width, height = img.size

    # 塗りつぶし済みかどうかのフラグ
    visited = [[False] * height for _ in range(width)]

    def is_dark_pixel(x, y):
        """ピクセルが暗い（黒系）かチェック"""
        r, g, b, a = pixels[x, y]
        # RGB値が全て30以下なら黒系と判定
        return r <= 30 and g <= 30 and b <= 30

    def flood_fill(start_x, start_y):
        """指定座標から連結した黒ピクセルを透過にする（幅優先探索）"""
        if visited[start_x][start_y] or not is_dark_pixel(start_x, start_y):
            return

        queue = [(start_x, start_y)]
        visited[start_x][start_y] = True

        while queue:
            x, y = queue.pop(0)
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (r, g, b, 0)  # 透過

            # 上下左右の隣接ピクセルをチェック
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                nx, ny = x + dx, y + dy
                if 0 <= nx < width and 0 <= ny < height:
                    if not visited[nx][ny] and is_dark_pixel(nx, ny):
                        visited[nx][ny] = True
                        queue.append((nx, ny))

    # 四隅から塗りつぶし開始
    corners = [
        (0, 0),                # 左上
        (width - 1, 0),        # 右上
        (0, height - 1),       # 左下
        (width - 1, height - 1) # 右下
    ]

    for x, y in corners:
        flood_fill(x, y)

    # 保存
    img.save(output_path, 'PNG')
    print(f'✅ 黒背景を削除しました: {output_path}')
    print(f'   画像サイズ: {width}x{height}')

if __name__ == '__main__':
    input_file = 'assets/icons/app_icon.png'
    output_file = 'assets/icons/app_icon_transparent.png'

    try:
        # Flood fillで四隅から連結した黒背景だけ削除
        remove_black_background_flood_fill(input_file, output_file)
    except Exception as e:
        print(f'❌ エラー: {e}', file=sys.stderr)
        sys.exit(1)
