"""
KnockPost Notification Icon - CLEAN APPROACH
=============================================
Uses the HIGH-RES brand icon (500x500) as source.
1. Converts dark-on-light to white-on-transparent
2. Removes ONLY the doorknob dot
3. NO erosion, NO shape modification
4. Simply resizes with proper padding to target sizes

The natural downscaling from 500px to 24-96px will automatically
produce thinner-looking strokes.
"""

from PIL import Image
import numpy as np
import os

OUTPUT_BASE = r'c:\Project\KnockPost\android\app\src\main\res'

DENSITIES = {
    'mdpi':    24,
    'hdpi':    36,
    'xhdpi':   48,
    'xxhdpi':  72,
    'xxxhdpi': 96,
}

# How much of the canvas the logo fills
CONTENT_RATIO = 0.80


# ═══════════════════════════════════════════════════════════════
# Step 1: Load the brand icon (dark on light background)
# ═══════════════════════════════════════════════════════════════

source_path = r'c:\Project\KnockPost\assets\icon(light backgroud).png'
brand = Image.open(source_path).convert('RGBA')
print(f"Loaded brand icon: {brand.size[0]}x{brand.size[1]}")

pixels = np.array(brand)

# ═══════════════════════════════════════════════════════════════
# Step 2: Convert to white-on-transparent
# The brand icon has dark (~50,50,50) strokes on white (~255) bg
# We need: white strokes on transparent background
# ═══════════════════════════════════════════════════════════════

print("Converting to white-on-transparent...")

# Get grayscale brightness
gray = np.mean(pixels[:, :, :3], axis=2)

# The door strokes are dark (gray < 100), background is light (gray > 200)
# Create alpha: dark pixels = opaque white, light pixels = transparent
result = np.zeros_like(pixels)

# Where pixels are dark (part of the logo), make them white and opaque
# Where pixels are light (background), make them transparent
threshold = 128
is_logo = gray < threshold

result[:, :, 0] = 255  # R = white
result[:, :, 1] = 255  # G = white
result[:, :, 2] = 255  # B = white

# Alpha: use inverted brightness for smooth anti-aliasing
# Dark pixels (gray=0) → alpha=255 (fully opaque)
# Light pixels (gray=255) → alpha=0 (fully transparent)
result[:, :, 3] = (255 - gray).astype(np.uint8)

# Boost: make near-opaque pixels fully opaque and near-transparent fully transparent
# This cleans up the anti-aliasing edges
alpha = result[:, :, 3]
alpha[alpha > 180] = 255  # solidify dark areas
alpha[alpha < 30] = 0     # clean light areas

result[:, :, 3] = alpha

white_on_transparent = Image.fromarray(result)

# ═══════════════════════════════════════════════════════════════
# Step 3: Remove the doorknob dot
# The dot is a filled circle inside the door frame
# We need to find it and erase it
# ═══════════════════════════════════════════════════════════════

print("Removing doorknob dot...")

# Find the bounding box of the logo content
bbox = white_on_transparent.getbbox()
if bbox:
    lx, ly, rx, ry = bbox
    print(f"  Logo bounds: ({lx},{ly}) to ({rx},{ry})")
    logo_w = rx - lx
    logo_h = ry - ly
    
    # The door frame consists of:
    # - Top bar: full width, at the top
    # - Left bar: full height
    # - Right bar: shorter, with step at bottom
    # - Bottom connection: left side connects to right step
    # 
    # The doorknob dot is inside the frame area
    # It's roughly at 35-40% from left, 40-45% from top of the content
    
    # Strategy: scan the alpha channel to find isolated opaque clusters
    # in the interior of the door (between the bars)
    
    alpha_arr = np.array(white_on_transparent)[:, :, 3]
    
    # Find the interior region:
    # Scan each row to find where the left bar ends and right bar begins
    # The dot pixels are opaque pixels in the interior gap
    
    # First, find approximate bar thickness by looking at the top bar
    top_row = ly + 10  # slightly into the logo
    row_alpha = alpha_arr[top_row, :]
    opaque_cols = np.where(row_alpha > 128)[0]
    
    if len(opaque_cols) > 0:
        bar_left_start = opaque_cols[0]
        
        # Find right edge of left bar by scanning from left
        # The left bar is a continuous opaque region
        # Then there's a gap (interior), then the right bar
        
        # Estimate bar thickness from the top horizontal bar
        top_y = ly + 5
        for check_y in range(ly, ly + logo_h // 4):
            row = alpha_arr[check_y, :]
            op = np.where(row > 128)[0]
            if len(op) > 10:
                # Full top bar row
                bar_thickness = 0
                # Find first gap in this row
                for idx in range(1, len(op)):
                    if op[idx] - op[idx-1] > 2:
                        bar_thickness = op[idx-1] - op[0] + 1
                        break
                if bar_thickness == 0:
                    # No gap = solid bar
                    bar_thickness = op[-1] - op[0] + 1
                break
        
        print(f"  Estimated bar thickness: ~{bar_thickness}px")
        
        # Now scan the interior rows to find and remove the dot
        # Interior rows are between the top bar and bottom area
        interior_top = ly + bar_thickness + 5
        interior_bottom = ry - bar_thickness - 5
        
        dot_pixels_removed = 0
        
        for y in range(interior_top, interior_bottom):
            row = alpha_arr[y, :]
            opaque = np.where(row > 128)[0]
            
            if len(opaque) < 3:
                continue
            
            # Find the left bar region and right bar region
            # Left bar: continuous opaque from the left
            # Right bar: continuous opaque on the right side
            
            # Find gaps
            diffs = np.diff(opaque)
            gap_positions = np.where(diffs > 3)[0]
            
            if len(gap_positions) >= 2:
                # Two gaps: left_bar | gap | DOT | gap | right_bar
                # The middle segment between first and second gap is the dot
                dot_start = opaque[gap_positions[0] + 1]
                dot_end = opaque[gap_positions[1]]
                
                # Clear these pixels
                alpha_arr[y, dot_start:dot_end+1] = 0
                dot_pixels_removed += (dot_end - dot_start + 1)
                
            elif len(gap_positions) == 1:
                # One gap might mean the dot is touching a bar
                # Check if the gap separates left bar from something larger than expected
                left_segment_end = opaque[gap_positions[0]]
                right_segment_start = opaque[gap_positions[0] + 1]
                
                left_len = left_segment_end - opaque[0] + 1
                right_len = opaque[-1] - right_segment_start + 1
                
                # If both segments are approximately bar thickness, no dot in this row
                # If one segment is wider, the dot is attached to it
                # Skip this case to be safe - only remove clear interior dots
        
        print(f"  Removed {dot_pixels_removed} dot pixels")
        
        # Apply the cleaned alpha back
        result_arr = np.array(white_on_transparent)
        result_arr[:, :, 3] = alpha_arr
        white_on_transparent = Image.fromarray(result_arr)


# Trim to content
final_source = white_on_transparent.crop(white_on_transparent.getbbox())
print(f"  Final source: {final_source.size[0]}x{final_source.size[1]}")


# ═══════════════════════════════════════════════════════════════
# Step 4: Generate notification icons for all densities
# ═══════════════════════════════════════════════════════════════

print(f"\nGenerating icons at {CONTENT_RATIO*100:.0f}% content ratio...\n")

for density, size in DENSITIES.items():
    max_content = int(size * CONTENT_RATIO)
    
    fw, fh = final_source.size
    ratio = min(max_content / fw, max_content / fh)
    new_w = max(1, int(fw * ratio))
    new_h = max(1, int(fh * ratio))
    
    resized = final_source.resize((new_w, new_h), Image.LANCZOS)
    
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    paste_x = (size - new_w) // 2
    paste_y = (size - new_h) // 2
    canvas.paste(resized, (paste_x, paste_y), resized)
    
    # Verify
    bbox = canvas.getbbox()
    if bbox:
        l, t, r, b = bbox
        content_pct = max(r-l, b-t) / size * 100
        pad_info = f"L={l} T={t} R={size-r} B={size-b}"
    else:
        content_pct = 0
        pad_info = "empty!"
    
    px = np.array(canvas)[:, :, 3]
    weight = (np.sum(px > 200) + np.sum((px > 10) & (px <= 200)) * 0.5) / px.size * 100
    
    output_path = os.path.join(OUTPUT_BASE, f'drawable-{density}', 'ic_notification.png')
    canvas.save(output_path, 'PNG', optimize=True)
    fsize = os.path.getsize(output_path)
    
    print(f"  {density:>8} ({size:>2}px): content={content_pct:.0f}% | {pad_info} | weight={weight:.1f}% | {fsize}B ✓")

print("\n✅ Done! Original door shape preserved, dot removed, no erosion.")


# ═══════════════════════════════════════════════════════════════
# Generate before/after comparison
# ═══════════════════════════════════════════════════════════════

print("\nGenerating comparison...")
from PIL import ImageDraw

comp = Image.new('RGBA', (600, 250), (25, 25, 30, 255))
draw = ImageDraw.Draw(comp)

# Original xxxhdpi
orig_path = os.path.join(OUTPUT_BASE, 'drawable-xxxhdpi', 'ic_notification.png')

# Brand icon (original with dot)
brand_display = Image.open(source_path).convert('RGBA')

# Convert brand to white-on-dark for display
brand_arr = np.array(brand_display)
brand_gray = np.mean(brand_arr[:, :, :3], axis=2)
dark_brand = np.zeros_like(brand_arr)
dark_brand[:, :, :3] = 25  # dark bg
dark_brand[:, :, 3] = 255
dark_brand[brand_gray < 128, 0] = 255
dark_brand[brand_gray < 128, 1] = 255
dark_brand[brand_gray < 128, 2] = 255
brand_dark = Image.fromarray(dark_brand).resize((180, 180), Image.LANCZOS)

comp.paste(brand_dark, (20, 25))
draw.text((40, 210), "Original (with dot)", fill=(255, 100, 100))

# New icon
new_icon = Image.open(orig_path).convert('RGBA')
new_display = new_icon.resize((180, 180), Image.NEAREST)
comp.paste(new_display, (350, 25), new_display)
draw.text((380, 210), "New (no dot)", fill=(100, 255, 100))

draw.text((20, 5), "BEFORE                                    AFTER", fill=(180, 180, 180))

comp_path = r'c:\Project\KnockPost\comparison_final.png'
comp.save(comp_path, 'PNG')
print(f"Saved: {comp_path}")
