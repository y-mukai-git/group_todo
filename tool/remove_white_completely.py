from PIL import Image

def remove_white_completely(input_path, output_path):
    """白い領域を完全に除去する（より厳格な処理）"""
    img = Image.open(input_path).convert('RGBA')
    pixels = img.load()
    width, height = img.size

    cleaned_count = 0

    for x in range(width):
        for y in range(height):
            r, g, b, a = pixels[x, y]

            # 以下のいずれかに該当するピクセルを完全透過にする
            # 1. アルファ値が200未満（半透明）
            # 2. 明るい色（グレー・白っぽい）でアルファ値が250未満
            # 3. RGB値が200以上の明るいピクセル

            if a < 200:
                # 半透明ピクセルは完全透過
                pixels[x, y] = (0, 0, 0, 0)
                cleaned_count += 1
            elif r > 150 and g > 150 and b > 150:
                # 明るいグレー・白っぽいピクセルを透過
                pixels[x, y] = (0, 0, 0, 0)
                cleaned_count += 1

    img.save(output_path, 'PNG')
    print(f"✅ 白い領域完全除去完了: {output_path}")
    print(f"   処理ピクセル数: {cleaned_count}個")
    print(f"   画像サイズ: {img.size}")

if __name__ == '__main__':
    remove_white_completely(
        'assets/icons/app_icon_original.png',
        'assets/icons/app_icon_clean.png'
    )
