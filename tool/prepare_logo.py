from pathlib import Path

from PIL import Image
import numpy as np

src = Path(r"c:\Users\xinta\Desktop\Lyrical\lyrical\logo\lyrical.png")
img = Image.open(src).convert("RGBA")
arr = np.asarray(img).copy()
r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
mask = (r < 28) & (g < 28) & (b < 28)
arr[mask, 3] = 0
transparent = Image.fromarray(arr, "RGBA")
transparent_path = src.parent / "lyrical_mark.png"
transparent.save(transparent_path)
print("saved", transparent_path, transparent.size)

size = max(transparent.size)
canvas = Image.new("RGBA", (size, size), (255, 255, 255, 255))
mark = transparent.copy()
target = int(size * 0.72)
mark.thumbnail((target, target), Image.Resampling.LANCZOS)
ox = (size - mark.width) // 2
oy = (size - mark.height) // 2
canvas.paste(mark, (ox, oy), mark)
icon_path = src.parent / "lyrical_app_icon.png"
out = canvas.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
out.save(icon_path, quality=95)
print("saved", icon_path, out.size)
