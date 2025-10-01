from PIL import Image

def clean_icon_edges(input_path, output_path):
    """アイコンのエッジにある半透明の白っぽいピクセルを完全に透過にする"""
    img = Image.open(input_path).convert('RGBA')
    pixels = img.load()
    width, height = img.size

    cleaned_count = 0

    for x in range(width):
        for y in range(height):
            r, g, b, a = pixels[x, y]

            # 半透明ピクセル（アルファ値が低い）を完全透過に
            if a < 250:
                # 明るい色（白っぽい）も除去
                if r > 200 and g > 200 and b > 200:
                    pixels[x, y] = (r, g, b, 0)
                    cleaned_count += 1
                # アルファ値が非常に低いピクセルは色に関わらず透過
                elif a < 50:
                    pixels[x, y] = (r, g, b, 0)
                    cleaned_count += 1

    img.save(output_path, 'PNG')
    print(f"✅ エッジクリーニング完了: {output_path}")
    print(f"   処理ピクセル数: {cleaned_count}個")

if __name__ == '__main__':
    clean_icon_edges(
        'assets/icons/app_icon.png',
        'assets/icons/app_icon.png'
    )
