from PIL import Image

def trim_icon_properly(input_path, output_path):
    """アイコンを適切にトリミングする"""
    img = Image.open(input_path).convert('RGBA')

    # 完全に不透明なピクセル（アルファ値255）のバウンディングボックスを取得
    pixels = img.load()
    width, height = img.size

    min_x, min_y = width, height
    max_x, max_y = 0, 0

    for x in range(width):
        for y in range(height):
            r, g, b, a = pixels[x, y]
            # アルファ値が10以上（ほぼ不透明）のピクセルを検出
            if a > 10:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)

    if min_x < max_x and min_y < max_y:
        # バウンディングボックスでクロップ
        cropped = img.crop((min_x, min_y, max_x + 1, max_y + 1))
        cropped.save(output_path, 'PNG')
        print(f"✅ トリミング完了: {output_path}")
        print(f"   元のサイズ: {img.size}")
        print(f"   新しいサイズ: {cropped.size}")
        print(f"   切り取られた領域: ({min_x}, {min_y}, {max_x + 1}, {max_y + 1})")
    else:
        print("❌ 有効なピクセルが見つかりませんでした")

if __name__ == '__main__':
    trim_icon_properly(
        'assets/icons/app_icon.png',
        'assets/icons/app_icon.png'
    )
