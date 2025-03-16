#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <png.h>

// Replace BMP-specific structs with PNG-related structures
typedef struct {
    png_structp png_ptr;
    png_infop info_ptr;
    int width;
    int height;
    png_byte color_type;
    png_byte bit_depth;
    png_bytep *row_pointers;
} PNGImage;

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

// Function to load a PNG image
PNGImage* load_png_file(const char *file_path) {
    FILE *fp = fopen(file_path, "rb");
    if (!fp) {
        fprintf(stderr, "Error: Could not open file %s\n", file_path);
        return NULL;
    }

    // Check PNG signature
    unsigned char header[8];
    if (fread(header, 1, 8, fp) != 8 || png_sig_cmp(header, 0, 8)) {
        fprintf(stderr, "Error: %s is not a valid PNG file\n", file_path);
        fclose(fp);
        return NULL;
    }

    // Initialize PNG structs
    PNGImage *image = (PNGImage*)malloc(sizeof(PNGImage));
    if (!image) {
        fprintf(stderr, "Error: Memory allocation failed\n");
        fclose(fp);
        return NULL;
    }

    image->png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (!image->png_ptr) {
        fprintf(stderr, "Error: png_create_read_struct failed\n");
        free(image);
        fclose(fp);
        return NULL;
    }

    image->info_ptr = png_create_info_struct(image->png_ptr);
    if (!image->info_ptr) {
        fprintf(stderr, "Error: png_create_info_struct failed\n");
        png_destroy_read_struct(&image->png_ptr, NULL, NULL);
        free(image);
        fclose(fp);
        return NULL;
    }

    // Error handling
    if (setjmp(png_jmpbuf(image->png_ptr))) {
        fprintf(stderr, "Error: Error during PNG file reading\n");
        png_destroy_read_struct(&image->png_ptr, &image->info_ptr, NULL);
        free(image);
        fclose(fp);
        return NULL;
    }

    png_init_io(image->png_ptr, fp);
    png_set_sig_bytes(image->png_ptr, 8);
    png_read_info(image->png_ptr, image->info_ptr);

    image->width = png_get_image_width(image->png_ptr, image->info_ptr);
    image->height = png_get_image_height(image->png_ptr, image->info_ptr);
    image->color_type = png_get_color_type(image->png_ptr, image->info_ptr);
    image->bit_depth = png_get_bit_depth(image->png_ptr, image->info_ptr);

    // Read any color_type into 8bit depth, RGBA format
    if (image->bit_depth == 16)
        png_set_strip_16(image->png_ptr);

    if (image->color_type == PNG_COLOR_TYPE_PALETTE)
        png_set_palette_to_rgb(image->png_ptr);

    // PNG_COLOR_TYPE_GRAY_ALPHA is always 8 or 16bit depth
    if (image->color_type == PNG_COLOR_TYPE_GRAY && image->bit_depth < 8)
        png_set_expand_gray_1_2_4_to_8(image->png_ptr);

    if (png_get_valid(image->png_ptr, image->info_ptr, PNG_INFO_tRNS))
        png_set_tRNS_to_alpha(image->png_ptr);

    // These color_type don't have an alpha channel then fill it with 0xff
    if (image->color_type == PNG_COLOR_TYPE_RGB ||
        image->color_type == PNG_COLOR_TYPE_GRAY ||
        image->color_type == PNG_COLOR_TYPE_PALETTE)
        png_set_filler(image->png_ptr, 0xFF, PNG_FILLER_AFTER);

    if (image->color_type == PNG_COLOR_TYPE_GRAY ||
        image->color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
        png_set_gray_to_rgb(image->png_ptr);

    png_read_update_info(image->png_ptr, image->info_ptr);

    // Read file
    image->row_pointers = (png_bytep*)malloc(sizeof(png_bytep) * image->height);
    for (int y = 0; y < image->height; y++) {
        image->row_pointers[y] = (png_byte*)malloc(png_get_rowbytes(image->png_ptr, image->info_ptr));
    }

    png_read_image(image->png_ptr, image->row_pointers);
    fclose(fp);

    return image;
}

// Function to free PNG image resources
void free_png_image(PNGImage *image) {
    if (!image) return;
    
    if (image->row_pointers) {
        for (int y = 0; y < image->height; y++) {
            free(image->row_pointers[y]);
        }
        free(image->row_pointers);
    }
    
    if (image->png_ptr && image->info_ptr) {
        png_destroy_read_struct(&image->png_ptr, &image->info_ptr, NULL);
    }
    
    free(image);
}

// Function to get RGB color from PNG image at specified coordinates
RGB get_pixel_color(PNGImage *image, int x, int y) {
    RGB color;
    png_bytep row = image->row_pointers[y];
    png_bytep px = &(row[x * 4]); // Each pixel is 4 bytes (RGBA)
    
    color.red = px[0];
    color.green = px[1];
    color.blue = px[2];
    // Alpha is px[3], but we're not using it
    
    return color;
}

// Function to load palettes from a palette PNG file
Palette* load_palettes(const char *palette_path, int *num_palettes) {
    PNGImage *palette_image = load_png_file(palette_path);
    if (!palette_image) {
        return NULL; // Error already printed
    }
    
    // Each row in the palette file represents one palette
    *num_palettes = palette_image->height;
    if (*num_palettes <= 0) {
        fprintf(stderr, "No palettes found in palette file\n");
        free_png_image(palette_image);
        return NULL;
    }
    
    // Create palette structures
    Palette *palettes = malloc((*num_palettes) * sizeof(Palette));
    if (!palettes) {
        fprintf(stderr, "Memory allocation failed\n");
        free_png_image(palette_image);
        return NULL;
    }
    
    // Each row is a palette with 4 colors
    for (int p = 0; p < *num_palettes; p++) {
        bool has_black = false;
        
        // Read 4 pixels from the palette row (or as many as we have in width)
        for (int c = 0; c < 4 && c < palette_image->width; c++) {
            RGB color = get_pixel_color(palette_image, c, p);
            palettes[p].colors[c] = color;
            
            // Check if this palette contains black
            if (is_black(&color)) {
                has_black = true;
            }
        }
        
        palettes[p].has_black = has_black;
    }
    
    free_png_image(palette_image);
    
    return palettes;
}

void convert_png_to_assembly(const char *png_path, const char *palette_path, const char *output_path) {
    // Load palettes first
    int num_palettes = 0;
    Palette *palettes = load_palettes(palette_path, &num_palettes);
    if (!palettes) {
        return; // Error already printed
    }
    
    printf("Loaded %d palettes from %s\n", num_palettes, palette_path);
    
    // Now process the main PNG file
    PNGImage *image = load_png_file(png_path);
    if (!image) {
        free(palettes);
        return; // Error already printed
    }
    
    if (image->width % 16 != 0 || image->height % 16 != 0) {
        fprintf(stderr, "Image dimensions must be multiples of 16\n");
        free_png_image(image);
        free(palettes);
        return;
    }
    
    int width = image->width;
    int height = image->height;
    int tiles_x = width / 16;
    int tiles_y = height / 16;
    int total_tiles = tiles_x * tiles_y;
    
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
                    RGB color = get_pixel_color(image, img_x, img_y);
                    
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
        free_png_image(image);
        free(palettes);
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
    free_png_image(image);
    free(palettes);
    
    printf("Conversion complete! %d tiles processed (%d failed to find perfect palette match).\n", 
           total_tiles, failed_tiles);
}

int main(int argc, char *argv[]) {
    if (argc != 4) {
        printf("Usage: %s input.png palettes.png output.txt\n", argv[0]);
        return 1;
    }
    
    convert_png_to_assembly(argv[1], argv[2], argv[3]);
    return 0;
}