from PIL import Image

def analyze_icon(input_path):
    """アイコンのピクセル情報を分析"""
    img = Image.open(input_path).convert('RGBA')
    pixels = img.load()
    width, height = img.size

    alpha_distribution = {}
    color_samples = []

    for x in range(width):
        for y in range(height):
            r, g, b, a = pixels[x, y]

            # アルファ値の分布を記録
            alpha_key = f"{a // 50 * 50}-{min(a // 50 * 50 + 49, 255)}"
            alpha_distribution[alpha_key] = alpha_distribution.get(alpha_key, 0) + 1

            # サンプルピクセルを保存
            if len(color_samples) < 20 and a > 0:
                color_samples.append((x, y, r, g, b, a))

    print(f"📊 アイコン分析結果: {input_path}")
    print(f"   画像サイズ: {width}x{height}")
    print(f"\n   アルファ値分布:")
    for alpha_range in sorted(alpha_distribution.keys()):
        count = alpha_distribution[alpha_range]
        print(f"     {alpha_range}: {count:,}ピクセル")

    print(f"\n   サンプルピクセル（最初の20個）:")
    for x, y, r, g, b, a in color_samples[:20]:
        print(f"     ({x}, {y}): RGB({r}, {g}, {b}) Alpha={a}")

if __name__ == '__main__':
    analyze_icon('assets/icons/app_icon.png')
