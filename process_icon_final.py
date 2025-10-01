from PIL import Image
from collections import deque

def process_icon_final(input_path, output_path):
    """最終的なアイコン処理：背景除去→トリミング"""
    img = Image.open(input_path).convert('RGBA')
    pixels = img.load()
    width, height = img.size

    print("🔄 ステップ1: Flood Fillで背景除去...")

    visited = [[False] * height for _ in range(width)]

    def is_background_pixel(x, y):
        """背景ピクセルかどうか判定（暗い色）"""
        r, g, b, a = pixels[x, y]
        # RGB値がすべて50以下の暗いピクセルを背景とみなす
        return r <= 50 and g <= 50 and b <= 50

    def flood_fill_bfs(start_x, start_y):
        """幅優先探索で連結した背景ピクセルを透過"""
        queue = deque([(start_x, start_y)])
        visited[start_x][start_y] = True
        count = 0

        while queue:
            x, y = queue.popleft()

            if is_background_pixel(x, y):
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

    print(f"   背景除去: {total_removed:,}ピクセル")

    print("🔄 ステップ2: トリミング...")

    # 不透明なピクセルのバウンディングボックスを取得
    min_x, min_y = width, height
    max_x, max_y = 0, 0

    for x in range(width):
        for y in range(height):
            r, g, b, a = pixels[x, y]
            if a > 10:  # ほぼ不透明なピクセル
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)

    if min_x < max_x and min_y < max_y:
        cropped = img.crop((min_x, min_y, max_x + 1, max_y + 1))
        cropped.save(output_path, 'PNG')
        print(f"✅ 処理完了: {output_path}")
        print(f"   元のサイズ: {width}x{height}")
        print(f"   新しいサイズ: {cropped.size}")
        print(f"   切り取られた領域: ({min_x}, {min_y}, {max_x + 1}, {max_y + 1})")
    else:
        print("❌ 有効なピクセルが見つかりませんでした")

if __name__ == '__main__':
    process_icon_final(
        'assets/icons/app_icon_original.png',
        'assets/icons/app_icon.png'
    )
