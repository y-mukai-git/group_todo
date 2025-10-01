from PIL import Image
from collections import deque

def fix_icon_properly(input_path, output_path):
    """アイコンを適切に修正：黒背景のみ除去、アイコン本体は保持"""
    img = Image.open(input_path).convert('RGBA')
    pixels = img.load()
    width, height = img.size

    print("🔄 黒い背景のみを除去...")

    visited = [[False] * height for _ in range(width)]

    def is_black_background(x, y):
        """純粋な黒背景かどうか判定（非常に厳格）"""
        r, g, b, a = pixels[x, y]
        # RGB値がすべて30以下の非常に暗いピクセルのみ背景とみなす
        return r <= 30 and g <= 30 and b <= 30

    def flood_fill_bfs(start_x, start_y):
        """幅優先探索で連結した黒背景ピクセルを透過"""
        queue = deque([(start_x, start_y)])
        visited[start_x][start_y] = True
        count = 0

        while queue:
            x, y = queue.popleft()

            if is_black_background(x, y):
                pixels[x, y] = (0, 0, 0, 0)
                count += 1

                # 4方向の隣接ピクセルをチェック
                for dx, dy in [(0, 1), (1, 0), (0, -1), (-1, 0)]:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < width and 0 <= ny < height and not visited[nx][ny]:
                        visited[nx][ny] = True
                        queue.append((nx, ny))

        return count

    # 四隅から flood fill
    total_removed = 0
    corners = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
    for x, y in corners:
        if not visited[x][y]:
            removed = flood_fill_bfs(x, y)
            total_removed += removed

    print(f"   除去したピクセル数: {total_removed:,}")

    print("🔄 トリミング...")

    # 不透明なピクセルのバウンディングボックスを取得
    min_x, min_y = width, height
    max_x, max_y = 0, 0

    for x in range(width):
        for y in range(height):
            r, g, b, a = pixels[x, y]
            if a > 10:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)

    if min_x < max_x and min_y < max_y:
        cropped = img.crop((min_x, min_y, max_x + 1, max_y + 1))
        cropped.save(output_path, 'PNG')
        print(f"✅ 修正完了: {output_path}")
        print(f"   元のサイズ: {width}x{height}")
        print(f"   新しいサイズ: {cropped.size}")
    else:
        img.save(output_path, 'PNG')
        print(f"✅ 保存完了（トリミングなし）: {output_path}")

if __name__ == '__main__':
    fix_icon_properly(
        'assets/icons/app_icon_original.png',
        'assets/icons/app_icon.png'
    )
