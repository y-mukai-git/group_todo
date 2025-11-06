from PIL import Image
from collections import deque

def remove_antialiasing(input_path, output_path):
    """アンチエイリアシングによる半透明の白い縁を除去"""
    img = Image.open(input_path).convert('RGBA')
    pixels = img.load()
    width, height = img.size

    print("🔄 ステップ1: 黒背景除去（Flood Fill）...")

    visited = [[False] * height for _ in range(width)]

    def is_dark_background(x, y):
        """暗い背景ピクセルの判定"""
        r, g, b, a = pixels[x, y]
        return r <= 30 and g <= 30 and b <= 30

    def flood_fill_bfs(start_x, start_y):
        """幅優先探索で連結した背景ピクセルを透過"""
        queue = deque([(start_x, start_y)])
        visited[start_x][start_y] = True
        count = 0

        while queue:
            x, y = queue.popleft()

            if is_dark_background(x, y):
                pixels[x, y] = (0, 0, 0, 0)
                count += 1

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

    print(f"   黒背景除去: {total_removed:,}ピクセル")

    print("🔄 ステップ2: 半透明の白い縁除去（エッジクリーニング）...")

    # 半透明ピクセルを完全透過に変換
    edge_cleaned = 0
    for x in range(width):
        for y in range(height):
            r, g, b, a = pixels[x, y]

            # 半透明（アルファ値が低い）かつ明るい色のピクセルを透過
            if 0 < a < 240:
                # 明るいグレー・白っぽいピクセル
                if r > 100 and g > 100 and b > 100:
                    pixels[x, y] = (0, 0, 0, 0)
                    edge_cleaned += 1
                # 非常に薄い（アルファ値50未満）ピクセルは色に関わらず透過
                elif a < 50:
                    pixels[x, y] = (0, 0, 0, 0)
                    edge_cleaned += 1

    print(f"   エッジクリーニング: {edge_cleaned:,}ピクセル")

    print("🔄 ステップ3: トリミング...")

    # 不透明なピクセルのバウンディングボックスを取得
    min_x, min_y = width, height
    max_x, max_y = 0, 0

    for x in range(width):
        for y in range(height):
            r, g, b, a = pixels[x, y]
            if a > 50:  # ある程度不透明なピクセル
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
    else:
        img.save(output_path, 'PNG')
        print(f"✅ 保存完了: {output_path}")

if __name__ == '__main__':
    remove_antialiasing(
        'assets/icons/app_icon_original.png',
        'assets/icons/app_icon.png'
    )
