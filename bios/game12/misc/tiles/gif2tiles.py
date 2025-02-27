from PIL import Image

def convert_gif_to_assembly(gif_path, output_path):
    img = Image.open(gif_path)
    img = img.convert('RGB')
    width, height = img.size

    if width % 16 != 0 or height % 16 != 0:
        raise ValueError("Image dimensions must be multiples of 16.")

    tiles_x = width // 16
    tiles_y = height // 16

    all_palettes = []
    all_tiles = []

    for ty in range(tiles_y):
        for tx in range(tiles_x):
            tile_pixels = []
            for y in range(16):
                row_y = ty * 16 + y
                for x in range(16):
                    pixel_x = tx * 16 + x
                    pixel = img.getpixel((pixel_x, row_y))
                    tile_pixels.append(pixel)

            tile_rows = [tile_pixels[i*16:(i+1)*16] for i in range(16)]

            unique_colors = []
            for row in tile_rows:
                for pixel in row:
                    if pixel not in unique_colors:
                        unique_colors.append(pixel)
                        if len(unique_colors) > 4:
                            raise ValueError(f"Tile ({tx},{ty}) has more than 4 colors.")

            while len(unique_colors) < 4:
                unique_colors.append(unique_colors[-1])
                
            # Check if there's an existing palette with the same set of colors
            palette_index = -1
            for i, existing_palette in enumerate(all_palettes):
                if set(existing_palette) == set(unique_colors):
                    palette_index = i
                    break
                    
            if palette_index == -1:
                # No matching palette found, create a new one
                all_palettes.append(tuple(unique_colors))
                palette_index = len(all_palettes) - 1
                
            # Get the palette we'll use
            palette = all_palettes[palette_index]
            
            # Map pixels to palette indices
            indexed_rows = []
            for row in tile_rows:
                # Find index of each pixel in the palette we're using
                indexed_row = [palette.index(p) for p in row]
                indexed_rows.append(indexed_row)

            tile_data = []
            for row in indexed_rows:
                left = row[:8]
                right = row[8:]

                left_word = 0
                for p in left:
                    left_word = (left_word << 2) | p
                right_word = 0
                for p in right:
                    right_word = (right_word << 2) | p

                tile_data.append((left_word, right_word))

            all_tiles.append((palette_index, tile_data))

    with open(output_path, 'w') as f:
        for idx, (palette_index, tile_data) in enumerate(all_tiles):
            f.write(f"db 0x{palette_index:02X}\n")
            for left, right in tile_data:
                left_bin = bin(left)[2:].zfill(16)
                right_bin = bin(right)[2:].zfill(16)
                f.write(f"dw {left_bin}b, {right_bin}b\n")
            if idx != len(all_tiles) - 1:
                f.write("\n")

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 3:
        print("Usage: python converter.py input.gif output.txt")
        sys.exit(1)
    convert_gif_to_assembly(sys.argv[1], sys.argv[2])