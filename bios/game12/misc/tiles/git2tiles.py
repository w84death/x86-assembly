from PIL import Image
import argparse
import numpy as np

def pack_row(pixels):
    """Pack 16 2-bit pixels into two 16-bit words"""
    word1 = sum((pix << (14 - i*2)) for i, pix in enumerate(pixels[:8]))
    word2 = sum((pix << (14 - i*2)) for i, pix in enumerate(pixels[8:]))
    return word1, word2

def process_tile(tile):
    """Quantize tile to 4 colors and return mapped pixels + palette"""
    # Convert to RGB for better color quantization
    rgb_tile = tile.convert('RGB')
    
    # Quantize to 4 colors using median cut
    quantized = rgb_tile.quantize(colors=4, method=1)
    
    # Get color mapping
    palette = quantized.getpalette()
    colors = []
    for i in range(4):
        colors.append(tuple(palette[i*3:i*3+3]))
    
    # Create pixel map
    pixel_map = []
    for y in range(16):
        for x in range(16):
            pixel_map.append(quantized.getpixel((x, y)))
    
    return pixel_map, colors

def convert_gif(gif_path, output_path):
    img = Image.open(gif_path)
    w, h = img.size
    tile_size = 16
    num_tiles = w // tile_size

    with open(output_path, 'w') as f:
        for tile_num in range(num_tiles):
            # Extract tile
            left = tile_num * tile_size
            tile = img.crop((left, 0, left + tile_size, tile_size))
            
            # Process tile and get mapped pixels
            pixels, palette_colors = process_tile(tile)
            
            # Write palette header (using tile number as palette ID)
            f.write(f"db 0x{tile_num:02x}          ; Palette {tile_num}\n")
            
            # Write pixel rows
            for y in range(16):
                row_pixels = pixels[y*16:(y+1)*16]
                word1, word2 = pack_row(row_pixels)
                f.write(f"dw {bin(word1)}, {bin(word2)}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Convert GIF tiles to ASM with individual palettes')
    parser.add_argument('input', help='Input GIF file')
    parser.add_argument('-o', '--output', default='tiles.asm', help='Output file')
    
    args = parser.parse_args()
    convert_gif(args.input, args.output)
