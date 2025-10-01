from PIL import Image

def trim_transparent(input_path, output_path):
    """透過部分をトリミングして実際のアイコン領域だけ残す"""
    img = Image.open(input_path).convert('RGBA')

    # 透過でないピクセルの境界を取得
    bbox = img.getbbox()

    if bbox:
        # 境界ボックスでクロップ
        trimmed = img.crop(bbox)
        trimmed.save(output_path, 'PNG')
        print(f"✅ トリミング完了: {output_path}")
        print(f"   元のサイズ: {img.size}")
        print(f"   新しいサイズ: {trimmed.size}")
        print(f"   切り取られた領域: {bbox}")
    else:
        print("❌ 透過でないピクセルが見つかりませんでした")

if __name__ == '__main__':
    trim_transparent(
        'assets/icons/app_icon.png',
        'assets/icons/app_icon.png'
    )
