#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#pragma pack(push, 1)
typedef struct {
    uint16_t type;          // "BM" (0x4D42)
    uint32_t size;          // Size of the file in bytes
    uint16_t reserved1;     // Reserved
    uint16_t reserved2;     // Reserved
    uint32_t offset;        // Offset to image data
} BMPHeader;

typedef struct {
    uint32_t size;          // Header size
    int32_t  width;         // Width of image
    int32_t  height;        // Height of image
    uint16_t planes;        // Number of color planes
    uint16_t bits;          // Bits per pixel
    uint32_t compression;   // Compression type
    uint32_t imagesize;     // Image size in bytes
    int32_t  xresolution;   // X resolution
    int32_t  yresolution;   // Y resolution
    uint32_t ncolors;       // Number of colors used
    uint32_t importantcolors; // Important colors
} BMPInfoHeader;

typedef struct {
    uint8_t blue;
    uint8_t green;
    uint8_t red;
    uint8_t reserved;
} BMPColorEntry;
#pragma pack(pop)

typedef struct {
    uint8_t red;
    uint8_t green;
    uint8_t blue;
} RGB;

typedef struct {
    RGB colors[4];
    bool has_black;
} Palette;

typedef struct {
    uint8_t palette_index;
    uint16_t tile_data[16][2];  // 16 rows, each with 2 words (left and right)
    bool is_sprite;
} Tile;

// Function to check if a color is black (zero RGB values)
bool is_black(const RGB *color) {
    return (color->red == 0 && color->green == 0 && color->blue == 0);
}

// Function to calculate how well a palette matches a set of colors
int calculate_palette_match(const RGB *colors, int num_colors, const Palette *palette) {
    int score = 0;
    
    // Check each unique color in the tile
    for (int i = 0; i < num_colors; i++) {
        bool color_found = false;
        
        // Try to find it in the palette
        for (int j = 0; j < 4; j++) {
            if (colors[i].red == palette->colors[j].red && 
                colors[i].green == palette->colors[j].green && 
                colors[i].blue == palette->colors[j].blue) {
                color_found = true;
                break;
            }
        }
        
        if (!color_found) {
            // If a color isn't found in the palette, this is a bad match
            return -1;
        }
    }
    
    // All colors were found in the palette
    return score;
}

// Function to find color index in palette
int find_color_in_palette(const RGB *color, const RGB *palette, int palette_size) {
    for (int i = 0; i < palette_size; i++) {
        if (color->red == palette[i].red &&
            color->green == palette[i].green &&
            color->blue == palette[i].blue) {
            return i;
        }
    }
    return -1;  // Color not found
}

// Function to load palettes from a palette BMP file
Palette* load_palettes(const char *palette_path, int *num_palettes) {
    FILE *palette_file = fopen(palette_path, "rb");
    if (!palette_file) {
        fprintf(stderr, "Cannot open palette file %s\n", palette_path);
        return NULL;
    }
    
    BMPHeader header;
    BMPInfoHeader info;
    
    // Read BMP header
    if (fread(&header, sizeof(header), 1, palette_file) != 1) {
        fprintf(stderr, "Error reading palette BMP header\n");
        fclose(palette_file);
        return NULL;
    }
    
    if (header.type != 0x4D42) {  // 'BM'
        fprintf(stderr, "Not a valid BMP file for palettes\n");
        fclose(palette_file);
        return NULL;
    }
    
    // Read BMP info header
    if (fread(&info, sizeof(info), 1, palette_file) != 1) {
        fprintf(stderr, "Error reading palette BMP info\n");
        fclose(palette_file);
        return NULL;
    }
    
    if (info.bits != 4 && info.bits != 8) {
        fprintf(stderr, "Palette BMP must be 4-bit or 8-bit indexed\n");
        fclose(palette_file);
        return NULL;
    }
    
    // Each row in the palette file represents one palette
    *num_palettes = info.height;
    if (*num_palettes <= 0) {
        fprintf(stderr, "No palettes found in palette file\n");
        fclose(palette_file);
        return NULL;
    }
    
    // Read color table from palette BMP
    int num_colors = info.ncolors;
    if (num_colors == 0) {
        num_colors = 1 << info.bits;
    }
    
    BMPColorEntry *color_table = malloc(num_colors * sizeof(BMPColorEntry));
    if (!color_table) {
        fprintf(stderr, "Memory allocation failed\n");
        fclose(palette_file);
        return NULL;
    }
    
    if (fread(color_table, sizeof(BMPColorEntry), num_colors, palette_file) != num_colors) {
        fprintf(stderr, "Error reading palette color table\n");
        free(color_table);
        fclose(palette_file);
        return NULL;
    }
    
    // Convert color table to RGB
    RGB *rgb_palette = malloc(num_colors * sizeof(RGB));
    for (int i = 0; i < num_colors; i++) {
        rgb_palette[i].red = color_table[i].red;
        rgb_palette[i].green = color_table[i].green;
        rgb_palette[i].blue = color_table[i].blue;
    }
    
    free(color_table);
    
    // Move to pixel data
    fseek(palette_file, header.offset, SEEK_SET);
    
    int width = info.width;
    bool bottom_up = info.height > 0; // BMP is stored bottom to top by default
    
    // Allocate memory for pixel data
    uint8_t *pixel_data = malloc(width * (*num_palettes));
    if (!pixel_data) {
        fprintf(stderr, "Memory allocation failed\n");
        free(rgb_palette);
        fclose(palette_file);
        return NULL;
    }
    
    // Read pixel data
    int row_size = ((width * info.bits + 31) / 32) * 4; // BMP rows are padded to 4-byte boundary
    uint8_t *row_buffer = malloc(row_size);
    if (!row_buffer) {
        fprintf(stderr, "Memory allocation failed\n");
        free(pixel_data);
        free(rgb_palette);
        fclose(palette_file);
        return NULL;
    }
    
    for (int y = 0; y < *num_palettes; y++) {
        int file_y = bottom_up ? (*num_palettes - 1 - y) : y; // Handle bottom-up BMPs
        
        if (fread(row_buffer, 1, row_size, palette_file) != row_size) {
            fprintf(stderr, "Error reading palette pixel data\n");
            free(row_buffer);
            free(pixel_data);
            free(rgb_palette);
            fclose(palette_file);
            return NULL;
        }
        
        if (info.bits == 8) {
            memcpy(&pixel_data[file_y * width], row_buffer, width);
        }
        else { // 4-bit
            for (int x = 0; x < width; x++) {
                int byte_pos = x / 2;
                int is_high_nibble = (x % 2 == 0);
                if (is_high_nibble) {
                    pixel_data[file_y * width + x] = (row_buffer[byte_pos] >> 4) & 0x0F;
                } else {
                    pixel_data[file_y * width + x] = row_buffer[byte_pos] & 0x0F;
                }
            }
        }
    }
    
    free(row_buffer);
    
    // Create palette structures
    Palette *palettes = malloc((*num_palettes) * sizeof(Palette));
    if (!palettes) {
        fprintf(stderr, "Memory allocation failed\n");
        free(pixel_data);
        free(rgb_palette);
        fclose(palette_file);
        return NULL;
    }
    
    // Each row is a palette with 4 colors
    for (int p = 0; p < *num_palettes; p++) {
        bool has_black = false;
        
        // Read 4 pixels from the palette row
        for (int c = 0; c < 4 && c < width; c++) {
            int idx = pixel_data[p * width + c];
            palettes[p].colors[c] = rgb_palette[idx];
            
            // Check if this palette contains black
            if (is_black(&palettes[p].colors[c])) {
                has_black = true;
            }
        }
        
        palettes[p].has_black = has_black;
    }
    
    free(pixel_data);
    free(rgb_palette);
    fclose(palette_file);
    
    return palettes;
}

void convert_bmp_to_assembly(const char *bmp_path, const char *palette_path, const char *output_path) {
    // Load palettes first
    int num_palettes = 0;
    Palette *palettes = load_palettes(palette_path, &num_palettes);
    if (!palettes) {
        return; // Error already printed
    }
    
    printf("Loaded %d palettes from %s\n", num_palettes, palette_path);
    
    // Now process the main BMP file
    FILE *bmp_file = fopen(bmp_path, "rb");
    if (!bmp_file) {
        fprintf(stderr, "Cannot open BMP file %s\n", bmp_path);
        free(palettes);
        return;
    }
    
    BMPHeader header;
    BMPInfoHeader info;
    
    // Read BMP header
    if (fread(&header, sizeof(header), 1, bmp_file) != 1) {
        fprintf(stderr, "Error reading BMP header\n");
        free(palettes);
        fclose(bmp_file);
        return;
    }
    
    if (header.type != 0x4D42) {  // 'BM'
        fprintf(stderr, "Not a valid BMP file\n");
        free(palettes);
        fclose(bmp_file);
        return;
    }
    
    // Read BMP info header
    if (fread(&info, sizeof(info), 1, bmp_file) != 1) {
        fprintf(stderr, "Error reading BMP info\n");
        free(palettes);
        fclose(bmp_file);
        return;
    }
    
    if (info.bits != 4 && info.bits != 8) {
        fprintf(stderr, "Only 4-bit or 8-bit indexed BMPs are supported\n");
        free(palettes);
        fclose(bmp_file);
        return;
    }
    
    if (info.width % 16 != 0 || info.height % 16 != 0) {
        fprintf(stderr, "Image dimensions must be multiples of 16\n");
        free(palettes);
        fclose(bmp_file);
        return;
    }
    
    int num_colors = info.ncolors;
    if (num_colors == 0) {
        num_colors = 1 << info.bits;
    }
    
    // Read color table from main BMP
    BMPColorEntry *color_table = malloc(num_colors * sizeof(BMPColorEntry));
    if (!color_table) {
        fprintf(stderr, "Memory allocation failed\n");
        free(palettes);
        fclose(bmp_file);
        return;
    }
    
    if (fread(color_table, sizeof(BMPColorEntry), num_colors, bmp_file) != num_colors) {
        fprintf(stderr, "Error reading color table\n");
        free(color_table);
        free(palettes);
        fclose(bmp_file);
        return;
    }
    
    // Move to pixel data
    fseek(bmp_file, header.offset, SEEK_SET);
    
    int width = info.width;
    int height = abs(info.height); // Handle negative height (top-down BMPs)
    bool bottom_up = info.height > 0; // BMP is stored bottom to top by default
    
    int tiles_x = width / 16;
    int tiles_y = height / 16;
    int total_tiles = tiles_x * tiles_y;
    
    // Convert color table to RGB
    RGB *rgb_palette = malloc(num_colors * sizeof(RGB));
    for (int i = 0; i < num_colors; i++) {
        rgb_palette[i].red = color_table[i].red;
        rgb_palette[i].green = color_table[i].green;
        rgb_palette[i].blue = color_table[i].blue;
    }
    
    free(color_table);
    
    // Allocate memory for pixel data
    uint8_t *pixel_data = malloc(width * height);
    if (!pixel_data) {
        fprintf(stderr, "Memory allocation failed\n");
        free(rgb_palette);
        free(palettes);
        fclose(bmp_file);
        return;
    }
    
    // Read pixel data
    int row_size = ((width * info.bits + 31) / 32) * 4; // BMP rows are padded to 4-byte boundary
    uint8_t *row_buffer = malloc(row_size);
    if (!row_buffer) {
        fprintf(stderr, "Memory allocation failed\n");
        free(pixel_data);
        free(rgb_palette);
        free(palettes);
        fclose(bmp_file);
        return;
    }
    
    for (int y = 0; y < height; y++) {
        int file_y = bottom_up ? (height - 1 - y) : y; // Handle bottom-up BMPs
        
        if (fread(row_buffer, 1, row_size, bmp_file) != row_size) {
            fprintf(stderr, "Error reading pixel data\n");
            free(row_buffer);
            free(pixel_data);
            free(rgb_palette);
            free(palettes);
            fclose(bmp_file);
            return;
        }
        
        if (info.bits == 8) {
            memcpy(&pixel_data[file_y * width], row_buffer, width);
        }
        else { // 4-bit
            for (int x = 0; x < width; x++) {
                int byte_pos = x / 2;
                int is_high_nibble = (x % 2 == 0);
                if (is_high_nibble) {
                    pixel_data[file_y * width + x] = (row_buffer[byte_pos] >> 4) & 0x0F;
                } else {
                    pixel_data[file_y * width + x] = row_buffer[byte_pos] & 0x0F;
                }
            }
        }
    }
    
    free(row_buffer);
    
    // Process tiles
    Tile *all_tiles = malloc(total_tiles * sizeof(Tile));
    int failed_tiles = 0;
    
    for (int ty = 0; ty < tiles_y; ty++) {
        for (int tx = 0; tx < tiles_x; tx++) {
            int tile_index = ty * tiles_x + tx;
            RGB tile_colors[256]; // For holding all 16x16 pixels
            RGB unique_colors[16]; // More than enough for checking uniqueness
            int unique_count = 0;
            bool has_black = false;
            
            // Extract tile pixels and identify unique colors
            for (int y = 0; y < 16; y++) {
                int img_y = ty * 16 + y;
                for (int x = 0; x < 16; x++) {
                    int img_x = tx * 16 + x;
                    int pixel_index = pixel_data[img_y * width + img_x];
                    RGB color = rgb_palette[pixel_index];
                    
                    // Store the color
                    tile_colors[y*16 + x] = color;
                    
                    // Check if it's black
                    if (is_black(&color)) {
                        has_black = true;
                    }
                    
                    // Check if this color is already in unique_colors
                    bool found = false;
                    for (int i = 0; i < unique_count; i++) {
                        if (unique_colors[i].red == color.red &&
                            unique_colors[i].green == color.green &&
                            unique_colors[i].blue == color.blue) {
                            found = true;
                            break;
                        }
                    }
                    
                    if (!found) {
                        if (unique_count >= 16) {
                            fprintf(stderr, "Warning: Too many unique colors in tile (%d,%d)\n", tx, ty);
                        } else {
                            unique_colors[unique_count++] = color;
                        }
                    }
                }
            }
            
            // Check if this is a sprite (has black color)
            bool is_sprite = has_black;
            all_tiles[tile_index].is_sprite = is_sprite;
            
            // Find best matching palette
            int best_palette = -1;
            int best_score = -1;
            
            for (int p = 0; p < num_palettes; p++) {
                // Skip palettes with black if this is not a sprite
                if (!is_sprite && palettes[p].has_black) continue;
                
                // Skip palettes without black if this is a sprite
                if (is_sprite && !palettes[p].has_black) continue;
                
                int score = calculate_palette_match(unique_colors, unique_count, &palettes[p]);
                if (score >= 0 && (best_palette == -1 || score > best_score)) {
                    best_palette = p;
                    best_score = score;
                }
            }
            
            if (best_palette == -1) {
                fprintf(stderr, "Warning: No matching palette for tile (%d,%d), using palette 0\n", tx, ty);
                best_palette = 0;  // Default to the first palette
                failed_tiles++;
            }
            
            // Store palette index
            all_tiles[tile_index].palette_index = best_palette;
            
            // Map pixels to palette indices
            for (int row = 0; row < 16; row++) {
                uint16_t left_word = 0;
                uint16_t right_word = 0;
                
                for (int col = 0; col < 8; col++) {
                    RGB *pixel = &tile_colors[row*16 + col];
                    int color_index = find_color_in_palette(pixel, palettes[best_palette].colors, 4);
                    if (color_index == -1) {
                        // Should not happen since we validated palette match
                        color_index = 0;
                    }
                    left_word = (left_word << 2) | color_index;
                }
                
                for (int col = 8; col < 16; col++) {
                    RGB *pixel = &tile_colors[row*16 + col];
                    int color_index = find_color_in_palette(pixel, palettes[best_palette].colors, 4);
                    if (color_index == -1) {
                        // Should not happen since we validated palette match
                        color_index = 0;
                    }
                    right_word = (right_word << 2) | color_index;
                }
                
                all_tiles[tile_index].tile_data[row][0] = left_word;
                all_tiles[tile_index].tile_data[row][1] = right_word;
            }
        }
    }
    
    // Write assembly output
    FILE *out_file = fopen(output_path, "w");
    if (!out_file) {
        fprintf(stderr, "Cannot open output file %s\n", output_path);
        free(all_tiles);
        free(pixel_data);
        free(rgb_palette);
        free(palettes);
        fclose(bmp_file);
        return;
    }

       // Function to map RGB color to the closest color in our custom palette
    // Returns the index in the DawnBringer 16 palette (0-15)
    int map_color_to_palette_index(const RGB *color) {
        // DawnBringer 16 palette (converted from the game's CustomPalette RGB values)
        // Each entry is (R, G, B) in 0-255 range
        static const RGB dawn_bringer[16] = {
            {0, 0, 0},       // 0 - Black
            {68, 32, 52},    // 1 - Deep purple
            {48, 52, 109},   // 2 - Navy blue
            {78, 74, 78},    // 3 - Dark gray
            {133, 76, 48},   // 4 - Brown
            {52, 101, 36},   // 5 - Dark green
            {208, 70, 72},   // 6 - Red
            {117, 113, 97},  // 7 - Light gray
            {89, 125, 206},  // 8 - Blue
            {210, 125, 44},  // 9 - Orange
            {133, 149, 161}, // 10 - Steel blue
            {109, 170, 44},  // 11 - Green
            {210, 170, 153}, // 12 - Pink/Beige
            {109, 194, 202}, // 13 - Cyan
            {218, 212, 94},  // 14 - Yellow
            {222, 238, 214}  // 15 - White
        };
    
        // Find closest match by calculating Euclidean distance in RGB space
        int best_match = 0;
        int min_distance = 255*255*3; // Max possible distance
    
        for (int i = 0; i < 16; i++) {
            int dr = color->red - dawn_bringer[i].red;
            int dg = color->green - dawn_bringer[i].green;
            int db = color->blue - dawn_bringer[i].blue;
            
            int distance = dr*dr + dg*dg + db*db;
            
            if (distance < min_distance) {
                min_distance = distance;
                best_match = i;
            }
        }
        
        return best_match;
    }
    
    // Replace the palette export section in the convert_bmp_to_assembly function with:
    
    // First, export the palette definitions
    fprintf(out_file, "Palettes:\n");
    for (int p = 0; p < num_palettes; p++) {
        // For each palette, map the original colors to the custom palette indices
        fprintf(out_file, "db ");
        for (int c = 0; c < 4; c++) {
            // Map each RGB color to the closest color in our DawnBringer palette
            int color_index = map_color_to_palette_index(&palettes[p].colors[c]);
            
            fprintf(out_file, "0x%X", color_index);
            if (c < 3) fprintf(out_file, ", ");
        }
        fprintf(out_file, " ; Palette 0x%X\n", p);
    }
    fprintf(out_file, "\n");
    
    // Then export the tiles data as before
    for (int i = 0; i < total_tiles; i++) {
        fprintf(out_file, "db 0x%02X ; %s\n", all_tiles[i].palette_index, 
                all_tiles[i].is_sprite ? "sprite" : "tile");
        
        for (int row = 0; row < 16; row++) {
            char left_bin[17], right_bin[17];
            
            uint16_t left = all_tiles[i].tile_data[row][0];
            uint16_t right = all_tiles[i].tile_data[row][1];
            
            // Convert to binary strings
            for (int bit = 0; bit < 16; bit++) {
                left_bin[15-bit] = ((left >> bit) & 1) ? '1' : '0';
                right_bin[15-bit] = ((right >> bit) & 1) ? '1' : '0';
            }
            left_bin[16] = right_bin[16] = '\0';
            
            fprintf(out_file, "dw %sb, %sb\n", left_bin, right_bin);
        }
        
        if (i < total_tiles - 1) {
            fprintf(out_file, "\n");
        }
    }
    
    // Clean up
    fclose(out_file);
    free(all_tiles);
    free(pixel_data);
    free(rgb_palette);
    free(palettes);
    fclose(bmp_file);
    
    printf("Conversion complete! %d tiles processed (%d failed to find perfect palette match).\n", 
           total_tiles, failed_tiles);
}

int main(int argc, char *argv[]) {
    if (argc != 4) {
        printf("Usage: %s input.bmp palettes.bmp output.txt\n", argv[0]);
        return 1;
    }
    
    convert_bmp_to_assembly(argv[1], argv[2], argv[3]);
    return 0;
}