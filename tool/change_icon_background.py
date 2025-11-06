from PIL import Image

def change_background_color(input_path, output_path, target_color):
    """アイコンの背景色を変更する"""
    img = Image.open(input_path).convert('RGBA')
    pixels = img.load()
    width, height = img.size

    # 各ピクセルをチェックして暗い色（背景）を置き換え
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            # 暗い色の範囲（R, G, B < 100）を検出して置き換え
            if r < 100 and g < 100 and b < 100:
                pixels[x, y] = target_color

    img.save(output_path, 'PNG')

    print(f"✅ 背景色変更完了: {output_path}")
    print(f"   新しい背景色: {target_color}")
    print(f"   サイズ: {img.size}")

if __name__ == '__main__':
    # #151826をRGBAに変換
    target_color = (21, 24, 38, 255)  # #151826

    change_background_color(
        'assets/icons/app_icon.png',
        'assets/icons/app_icon.png',
        target_color
    )

    # iOS用アイコンも再生成
    from create_ios_icon import create_ios_icon
    create_ios_icon(
        'assets/icons/app_icon.png',
        'assets/icons/app_icon_ios.png',
        target_color
    )
