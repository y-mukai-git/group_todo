from PIL import Image

def create_ios_icon(input_path, output_path, bg_color):
    """iOS用アイコン作成：透過部分を指定色で塗りつぶす"""
    img = Image.open(input_path).convert('RGBA')

    # 背景レイヤーを作成（指定色で塗りつぶし）
    background = Image.new('RGBA', img.size, bg_color)

    # 背景の上にアイコンを合成
    result = Image.alpha_composite(background, img)

    # RGBに変換（透過なし）
    result_rgb = result.convert('RGB')

    result_rgb.save(output_path, 'PNG')
    print(f"✅ iOS用アイコン作成完了: {output_path}")
    print(f"   背景色: {bg_color}")
    print(f"   サイズ: {result_rgb.size}")

if __name__ == '__main__':
    # テーマカラー（primaryColor）で背景を塗りつぶし
    create_ios_icon(
        'assets/icons/app_icon.png',
        'assets/icons/app_icon_ios.png',
        (90, 105, 120, 255)  # #5A6978 in RGBA
    )
