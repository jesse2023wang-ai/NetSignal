from PIL import Image, ImageDraw
import os
import subprocess
import shutil

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RESOURCES_DIR = os.path.join(SCRIPT_DIR, "Resources")

def generate_signal_icon(size):
    """Generate a signal bar icon with semi-transparent background + green bars (anti-aliased)"""
    scale = 4  # supersample for anti-aliasing
    big = size * scale
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Semi-transparent rounded background (drawn at 4x, then scaled down)
    radius = big // 6
    bg_padding = big // 16
    draw.rounded_rectangle(
        [bg_padding, bg_padding, big - bg_padding, big - bg_padding],
        radius=radius,
        fill=(255, 255, 255, 51)  # white 20% alpha
    )

    bar_count = 4
    bar_width = max(2, big // 8)
    bar_spacing = max(1, big // 16)
    total_width = bar_count * bar_width + (bar_count - 1) * bar_spacing
    start_x = (big - total_width) // 2
    base_y = big // 6
    max_bar_height = big - base_y - big // 8

    green = (76, 175, 80)

    for i in range(bar_count):
        bar_height = max_bar_height * (i + 1) // bar_count
        x = start_x + i * (bar_width + bar_spacing)
        y = big - base_y - bar_height
        radius = max(1, bar_width // 3)
        draw.rounded_rectangle(
            [x, y, x + bar_width, y + bar_height],
            radius=radius,
            fill=green
        )

    # Scale down with high-quality resampling for anti-aliasing
    return img.resize((size, size), Image.LANCZOS)

def main():
    os.makedirs(RESOURCES_DIR, exist_ok=True)

    # 1. Generate 512x512 PNG for alert dialogs (high-res, will be scaled down in code)
    icon_png_path = os.path.join(RESOURCES_DIR, "AppIcon.png")
    img_png = generate_signal_icon(512)
    img_png.save(icon_png_path)
    print(f"Generated {icon_png_path}")

    # 2. Generate iconset for .icns (DMG / Finder icon)
    iconset_dir = os.path.join(RESOURCES_DIR, "AppIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)

    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    for size, filename in sizes:
        img = generate_signal_icon(size)
        img.save(os.path.join(iconset_dir, filename))

    # 3. Generate .icns
    icns_path = os.path.join(RESOURCES_DIR, "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
    print(f"Generated {icns_path}")

    # 4. Clean up iconset
    shutil.rmtree(iconset_dir)
    print("Done. Files in Resources/: AppIcon.png, AppIcon.icns")

if __name__ == "__main__":
    main()
