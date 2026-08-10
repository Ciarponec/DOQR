"""Generate deterministic App Store exports from the approved DOQR UI captures."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from textwrap import wrap

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "store_assets" / "google_play"
OUTPUT_DIR = ROOT / "store_assets" / "app_store"
FONT_PATH = ROOT / "flutter_app" / "assets" / "fonts" / "Manrope-Variable.ttf"
ICON_PATH = (
    ROOT
    / "flutter_app"
    / "ios"
    / "Runner"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
    / "Icon-App-1024x1024@1x.png"
)
LAUNCH_DIR = (
    ROOT
    / "flutter_app"
    / "ios"
    / "Runner"
    / "Assets.xcassets"
    / "LaunchImage.imageset"
)

PHONE_EXPORTS = [
    (
        "phone-01-host-login.png",
        "iphone-6.9-01-host-login.png",
        "Kapın, tek taramayla ulaşılabilir.",
        "Ziyaretçi uygulama kurmadan QR kodunu tarar.",
    ),
    (
        "phone-02-home.png",
        "iphone-6.9-02-home.png",
        "Zil çaldığında anında haberdar ol.",
        "Ziyaretlerini ve dijital zillerini tek yerden yönet.",
    ),
    (
        "phone-03-plans.png",
        "iphone-6.9-03-plans.png",
        "Free veya Pro, kontrol sende.",
        "Sesli ve görüntülü görüşme ile kurye özellikleri Pro’da.",
    ),
]


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_PATH), size=size)


def gradient(size: tuple[int, int]) -> Image.Image:
    width, height = size
    top = (11, 18, 48)
    bottom = (32, 59, 146)
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        ratio = y / max(height - 1, 1)
        color = tuple(round(a + (b - a) * ratio) for a, b in zip(top, bottom))
        draw.line((0, y, width, y), fill=color)
    return image


def rounded_capture(source: Image.Image, target_width: int, radius: int) -> Image.Image:
    source = source.convert("RGB")
    target_height = round(source.height * target_width / source.width)
    resized = source.resize((target_width, target_height), Image.Resampling.LANCZOS)
    mask = Image.new("L", resized.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, resized.width - 1, resized.height - 1), radius=radius, fill=255
    )
    rgba = resized.convert("RGBA")
    rgba.putalpha(mask)
    return rgba


def add_shadow(canvas: Image.Image, capture: Image.Image, position: tuple[int, int]) -> None:
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_mask = capture.getchannel("A").filter(ImageFilter.GaussianBlur(30))
    shadow_color = Image.new("RGBA", capture.size, (0, 0, 0, 135))
    shadow_color.putalpha(shadow_mask)
    shadow.alpha_composite(shadow_color, (position[0], position[1] + 22))
    canvas.paste(shadow.convert("RGB"), (0, 0), shadow)
    canvas.paste(capture.convert("RGB"), position, capture)


def draw_brand(draw: ImageDraw.ImageDraw, icon: Image.Image, x: int, y: int, size: int) -> None:
    icon_small = icon.resize((size, size), Image.Resampling.LANCZOS)
    draw._image.paste(icon_small, (x, y))
    draw.text((x + size + 22, y + 7), "DOQR", font=font(round(size * 0.58)), fill="white")


def draw_wrapped(
    draw: ImageDraw.ImageDraw,
    text: str,
    position: tuple[int, int],
    max_chars: int,
    typeface: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int],
    spacing: int,
) -> int:
    lines = wrap(text, width=max_chars, break_long_words=False)
    y = position[1]
    for line in lines:
        draw.text((position[0], y), line, font=typeface, fill=fill)
        box = draw.textbbox((position[0], y), line, font=typeface)
        y = box[3] + spacing
    return y


def build_phone(
    icon: Image.Image,
    item: tuple[str, str, str, str],
    canvas_size: tuple[int, int] = (1290, 2796),
    output_name: str | None = None,
) -> Path:
    source_name, default_output_name, headline, subtitle = item
    output_name = output_name or default_output_name
    scale = min(canvas_size[0] / 1290, canvas_size[1] / 2796)
    canvas = gradient(canvas_size)
    draw = ImageDraw.Draw(canvas)
    draw_brand(
        draw,
        icon,
        round(70 * scale),
        round(58 * scale),
        round(78 * scale),
    )
    draw.text(
        (round(70 * scale), round(175 * scale)),
        headline,
        font=font(round(54 * scale)),
        fill="white",
    )
    draw.text(
        (round(70 * scale), round(255 * scale)),
        subtitle,
        font=font(round(29 * scale)),
        fill=(190, 207, 255),
    )

    source = Image.open(SOURCE_DIR / source_name)
    capture = rounded_capture(
        source,
        target_width=round(1160 * scale),
        radius=round(48 * scale),
    )
    add_shadow(canvas, capture, (round(65 * scale), round(430 * scale)))
    output = OUTPUT_DIR / output_name
    canvas.save(output, format="PNG", optimize=True)
    return output


def build_ipad(icon: Image.Image) -> Path:
    canvas = gradient((2732, 2048))
    draw = ImageDraw.Draw(canvas)
    draw_brand(draw, icon, 120, 120, 112)
    end_y = draw_wrapped(
        draw,
        "Kapın, tek taramayla ulaşılabilir.",
        (120, 360),
        max_chars=19,
        typeface=font(76),
        fill=(255, 255, 255),
        spacing=18,
    )
    draw_wrapped(
        draw,
        "Ziyaretçiler uygulama kurmadan QR kodunu tarar; sen iPad’den anında yanıt verirsin.",
        (120, end_y + 46),
        max_chars=31,
        typeface=font(37),
        fill=(190, 207, 255),
        spacing=16,
    )

    source = Image.open(SOURCE_DIR / "tablet-10-01-login.png")
    capture = rounded_capture(source, target_width=1660, radius=50)
    add_shadow(canvas, capture, (940, 430))
    output = OUTPUT_DIR / "ipad-13-01-host-login.png"
    canvas.save(output, format="PNG", optimize=True)
    return output


def export_icon(icon: Image.Image) -> Path:
    output = OUTPUT_DIR / "doqr-app-icon-1024.png"
    icon.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS).save(
        output, format="PNG", optimize=True
    )
    return output


def export_launch_images(icon: Image.Image) -> list[Path]:
    outputs: list[Path] = []
    for filename, size in (
        ("LaunchImage.png", 168),
        ("LaunchImage@2x.png", 336),
        ("LaunchImage@3x.png", 504),
    ):
        output = LAUNCH_DIR / filename
        icon.convert("RGB").resize((size, size), Image.Resampling.LANCZOS).save(
            output, format="PNG", optimize=True
        )
        outputs.append(output)
    return outputs


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(131072), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_manifest(exports: list[Path]) -> None:
    items = []
    for path in exports:
        with Image.open(path) as image:
            items.append(
                {
                    "file": path.relative_to(ROOT).as_posix(),
                    "width": image.width,
                    "height": image.height,
                    "mode": image.mode,
                    "sha256": sha256(path),
                }
            )
    manifest = {
        "schema_version": 1,
        "generator": "scripts/generate_app_store_assets.py",
        "sources": [
            "store_assets/google_play/phone-01-host-login.png",
            "store_assets/google_play/phone-02-home.png",
            "store_assets/google_play/phone-03-plans.png",
            "store_assets/google_play/tablet-10-01-login.png",
            "flutter_app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png",
        ],
        "exports": items,
    }
    (OUTPUT_DIR / "export-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    icon = Image.open(ICON_PATH).convert("RGB")
    app_store_exports = [build_phone(icon, item) for item in PHONE_EXPORTS]
    app_store_exports.extend(
        build_phone(
            icon,
            item,
            canvas_size=(1284, 2778),
            output_name=item[1].replace("iphone-6.9-", "iphone-6.5-"),
        )
        for item in PHONE_EXPORTS
    )
    app_store_exports.append(build_ipad(icon))
    app_store_exports.append(export_icon(icon))
    launch_exports = export_launch_images(icon)
    write_manifest(app_store_exports + launch_exports)


if __name__ == "__main__":
    main()
