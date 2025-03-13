; GAME12 - 2D Game Engine for DOS
;
; Fast rendering of big maps with full screen viewport.
; Backend for strategic/simulation games. Based on GAME11 ideas.
; 
; http://smol.p1x.in/assembly/#game12
; Created by Krzysztof Krystian Jankowski
; MIT License
; 02/2025

org 0x100
use16

; =========================================== MEMORY ALLOCATION ================

_BASE_         equ 0x2000           ; Start of memory
_GAME_TICK_    equ _BASE_ + 0x00    ; 2 bytes
_GAME_STATE_   equ _BASE_ + 0x02    ; 1 byte
_RNG_          equ _BASE_ + 0x03    ; 2 bytes
_VIEWPORT_X_   equ _BASE_ + 0x05    ; 2 bytes
_VIEWPORT_Y_   equ _BASE_ + 0x07    ; 2 byte
_CURSOR_X_     equ _BASE_ + 0x09    ; 2 bytes
_CURSOR_Y_     equ _BASE_ + 0x0B    ; 2 bytes
_INTERACTION_MODE_ equ _BASE_ + 0x0D ; 1 byte
; 25b free to use
_TILES_        equ _BASE_ + 0x20    ; 40 tiles = 10K = 0x2800
_MAP_          equ _BASE_ + 0x4820  ; Map data 128*128*1b= 0x4000
_ENTITIES_     equ _BASE_ + 0x8820  ; Entities 255 * 3b = 0x2FD
; 35.6K

; =========================================== GAME STATES ======================

STATE_INIT_ENGINE       equ 0
STATE_QUIT              equ 1
STATE_TITLE_SCREEN_INIT equ 2
STATE_TITLE_SCREEN      equ 3
STATE_MENU_INIT         equ 4
STATE_MENU              equ 5
STATE_GAME_NEW          equ 6
STATE_GAME_INIT         equ 7
STATE_GAME              equ 8
STATE_MAP_VIEW_INIT     equ 9
STATE_MAP_VIEW          equ 10
STATE_DEBUG_VIEW_INIT   equ 11
STATE_DEBUG_VIEW        equ 12
STATE_GENERATE_MAP      equ 13

; =========================================== KEYBOARD CODES ===================

KB_ESC      equ 0x01
KB_UP       equ 0x48
KB_DOWN     equ 0x50
KB_LEFT     equ 0x4B
KB_RIGHT    equ 0x4D
KB_ENTER    equ 0x1C
KB_SPACE    equ 0x39
KB_DEL      equ 0x53
KB_BACK     equ 0x0E
KB_Q        equ 0x10
KB_W        equ 0x11
KB_M        equ 0x32
KB_TAB      equ 0x0F
KB_F1       equ 0x3B
KB_F2       equ 0x3C

; =========================================== TILES NAMES ======================

TILE_MUD             equ 0x0
TILE_MUD2            equ 0x1
TILE_MUD_GRASS       equ 0x2
TILE_GRASS           equ 0x3
TILE_BUSH            equ 0x4
TILE_TREE            equ 0x5
TILE_MOUNTAIN        equ 0x6
TILE_PLATFORM        equ 0x7
META_TILES_MASK         equ 0x1F

TILE_TRAIN_HORIZONTAL   equ 0x7
TILE_TRAIN_DOWN         equ 0x8
TILE_TRAIN_UP           equ 0x9
TILE_CART_VERTICAL      equ 0xA
TILE_CART_HORIZONTAl    equ 0xB
TILE_BUILDING_1         equ 23
TILE_BUILDING_2         equ 24
TILE_BUILDING_3         equ 25

TILE_RESOURCE_BLUE      equ 32
TILE_RESOURCE_ORANGE    equ 35
TILE_RESOURCE_RED       equ 38
SHIFT_RESOURCE_VERTICAL    equ 1
SHIFT_RESOURCE_HORIZONTAL  equ 2

TILE_CURSOR_NORMAL      equ 42

META_INVISIBLE_WALL     equ 0x20    ; For collision detection
META_TRANSPORT          equ 0x40    ; For railroads
META_SPECIAL            equ 0x80

META_EMPTY                 equ 0x0
META_TRAIN                 equ 0x1
META_EMPTY_CART            equ 0x2
EMETA_EMPTY_CART           equ 0x4
EMETA_RESOURCE_BLUE        equ 0x8
EMETA_RESOURCE_ORANGE      equ 0x10
META_RESOURCE_RED          equ 0x20

MODE_VIEWPORT_PANNING      equ 0
MODE_RAILROAD_BUILDING     equ 1
MODE_BUILDING_CONSTRUCTION equ 2

; =========================================== MISC SETTINGS ====================

SCREEN_WIDTH         equ 320
SCREEN_HEIGHT        equ 200
MAP_SIZE             equ 128      ; Map size in cells DO NOT CHANGE
VIEWPORT_WIDTH       equ 20      ; Full screen 320
VIEWPORT_HEIGHT      equ 12      ; by 192 pixels
VIEWPORT_GRID_SIZE   equ 16      ; Individual cell size DO NOT CHANGE
SPRITE_SIZE          equ 16      ; Sprite size 16x16

; =========================================== COLORS / DB16 ====================

   COLOR_BLACK         equ 0
   COLOR_DEEP_PURPLE   equ 1
   COLOR_NAVY_BLUE     equ 2
   COLOR_DARK_GRAY     equ 3
   COLOR_BROWN         equ 4
   COLOR_DARK_GREEN    equ 5
   COLOR_RED           equ 6
   COLOR_LIGHT_GRAY    equ 7
   COLOR_BLUE          equ 8
   COLOR_ORANGE        equ 9
   COLOR_STEEL_BLUE    equ 10
   COLOR_GREEN         equ 11
   COLOR_PINK          equ 12
   COLOR_CYAN          equ 13
   COLOR_YELLOW        equ 14
   COLOR_WHITE         equ 15

; =========================================== INITIALIZATION ===================

start:
   mov ax, 0x13         ; Init 320x200, 256 colors mode
   int 0x10             ; Video BIOS interrupt

   mov ax, 0xA000       ; VGA memory segment
   mov es, ax           ; Set ES to VGA memory segment
   xor di, di           ; Set DI to 0

   mov ax, 0x9000       
   mov ss, ax           ; Set stack segment to 0x9000
   mov sp, 0xFFFF       ; Set stack pointer to 0xFFFF

   call initialize_custom_palette
   mov byte [_GAME_STATE_], STATE_INIT_ENGINE
   mov word [_VIEWPORT_X_], MAP_SIZE/2-VIEWPORT_WIDTH/2
   mov word [_VIEWPORT_Y_], MAP_SIZE/2-VIEWPORT_HEIGHT/2
   mov word [_CURSOR_X_], MAP_SIZE/2
   mov word [_CURSOR_Y_], MAP_SIZE/2

; =========================================== GAME LOOP ========================

main_loop:

; =========================================== GAME STATES ======================

   movzx bx, byte [_GAME_STATE_]    ; Load state into BX
   shl bx, 1                        ; Multiply by 2 (word size)
   jmp word [StateJumpTable + bx]   ; Jump to handle

game_state_satisfied:

; =========================================== KEYBOARD INPUT ===================

check_keyboard:
   mov ah, 01h         ; BIOS keyboard status function
   int 16h             ; Call BIOS interrupt
   jz .done

   mov ah, 00h         ; BIOS keyboard read function
   int 16h             ; Call BIOS interrupt

   ; ========================================= STATE TRANSITIONS ===============
   mov si, StateTransitionTable
   mov cx, StateTransitionTableEnd-StateTransitionTable
   .check_transitions:      
      mov bl, [_GAME_STATE_]
      cmp bl, [si]        ; Check current state
      jne .next_entry
      
      cmp ah, [si+1]      ; Check key press
      jne .next_entry
      
      mov bl, [si+2]      ; Get new state
      mov [_GAME_STATE_], bl
      jmp .transitions_done

   .next_entry:
      add si, 3           ; Move to next entry
      loop .check_transitions

   .transitions_done:

   ; ========================================= GAME LOGIC INPUT ================

   ; todo: handle game logic inputs

   cmp byte [_GAME_STATE_], STATE_GAME
   jne .done

   cmp byte [_INTERACTION_MODE_], MODE_VIEWPORT_PANNING
   je .viewport_panning
   cmp byte [_INTERACTION_MODE_], MODE_RAILROAD_BUILDING
   je .railroad_building
   jmp .done

   .viewport_panning:
      cmp ah, KB_UP
      je .move_viewport_up
      cmp ah, KB_DOWN
      je .move_viewport_down
      cmp ah, KB_LEFT
      je .move_viewport_left
      cmp ah, KB_RIGHT
      je .move_viewport_right
      cmp ah, KB_ENTER
      je .swap_mode
   jmp .done

   .move_viewport_up:
      cmp word [_VIEWPORT_Y_], 0
      je .done
      dec word [_VIEWPORT_Y_]
      dec word [_CURSOR_Y_]
   jmp .redraw_terrain
   .move_viewport_down:
      cmp word [_VIEWPORT_Y_], MAP_SIZE-VIEWPORT_HEIGHT
      jae .done
      inc word [_VIEWPORT_Y_]
      inc word [_CURSOR_Y_]
   jmp .redraw_terrain
   .move_viewport_left:
      cmp word [_VIEWPORT_X_], 0
      je .done
      dec word [_VIEWPORT_X_]
      dec word [_CURSOR_X_]
   jmp .redraw_terrain
   .move_viewport_right:
      cmp word [_VIEWPORT_X_], MAP_SIZE-VIEWPORT_WIDTH
      jae .done
      inc word [_VIEWPORT_X_]
      inc word [_CURSOR_X_]
   jmp .redraw_terrain

   .railroad_building:
      cmp ah, KB_UP
      je .move_cursor_up
      cmp ah, KB_DOWN
      je .move_cursor_down
      cmp ah, KB_LEFT
      je .move_cursor_left
      cmp ah, KB_RIGHT
      je .move_cursor_right
      cmp ah, KB_SPACE
      je .construct_railroad
      cmp ah, KB_ENTER
      je .swap_mode
   jmp .done

   .swap_mode:
      xor byte [_INTERACTION_MODE_], 0x1
   jmp .done
   
   .move_cursor_up:
      cmp word [_CURSOR_Y_], 0
      je .done
      dec word [_CURSOR_Y_]
   jmp .redrawn_tile
   .move_cursor_down:
      cmp word [_CURSOR_Y_], MAP_SIZE-1
      jae .done
      inc word [_CURSOR_Y_]
   jmp .redrawn_tile
   .move_cursor_left:
      cmp word [_CURSOR_X_], 0
      je .done
      dec word [_CURSOR_X_]
   jmp .redrawn_tile
   .move_cursor_right:
      cmp word [_CURSOR_X_], MAP_SIZE-1
      jae .done
      inc word [_CURSOR_X_]
   jmp .redrawn_tile

   .construct_railroad:
      mov ax, [_CURSOR_Y_]
      shl ax, 7   ; Y * 128
      add ax, [_CURSOR_X_]
      mov di, _MAP_
      add di, ax
      mov al, [di]
      test al, META_TRANSPORT
      jnz .done
      and al, 0x3
      add al, META_TRANSPORT
      mov [di], al      
      jmp .redrawn_tile

   .redrawn_tile:
      ; to be optimize later
      ; for now redrawn everything
   .redraw_terrain:
      call draw_terrain
      call draw_entities
      call draw_cursor
      jmp .done


.done:

; =========================================== GAME TICK ========================

wait_for_tick:
   xor ax, ax           ; Function 00h: Read system timer counter
   int 0x1a             ; Returns tick count in CX:DX
   mov bx, dx           ; Store the current tick count
   .wait_loop:
      int 0x1a          ; Read the tick count again
      cmp dx, bx
      je .wait_loop     ; Loop until the tick count changes

call stop_sound
inc word [_GAME_TICK_]  ; Increment game tick

; =========================================== ESC OR LOOP ======================

jmp main_loop

; =========================================== EXIT TO DOS ======================

exit:
   call stop_sound
   mov ax, 0x0003       ; Set video mode to 80x25 text mode
   int 0x10             ; Call BIOS interrupt
   mov si, QuitText     ; Draw message after exit
   xor dx, dx           ; At 0/0 position
   call draw_text
   
   mov ax, 0x4c00      ; Exit to DOS
   int 0x21            ; Call DOS
   ret                 ; Return to DOS

















; =========================================== LOGIC FOR GAME STATES ============

StateJumpTable:
   dw init_engine
   dw exit
   dw init_title_screen
   dw live_title_screen
   dw init_menu
   dw live_menu
   dw new_game
   dw init_game
   dw live_game
   dw init_map_view
   dw live_map_view
   dw init_debug_view
   dw live_debug_view

StateTransitionTable:
    db STATE_TITLE_SCREEN, KB_ESC,   STATE_QUIT
    db STATE_TITLE_SCREEN, KB_ENTER, STATE_MENU_INIT
    db STATE_MENU,         KB_ESC,   STATE_QUIT
    db STATE_MENU,         KB_F1,    STATE_GAME_NEW
    db STATE_MENU,         KB_ENTER, STATE_GAME_INIT
    db STATE_MENU,         KB_F2,    STATE_DEBUG_VIEW_INIT
    db STATE_GAME,         KB_ESC,   STATE_MENU_INIT
    db STATE_GAME,         KB_TAB,   STATE_MAP_VIEW_INIT
    db STATE_MAP_VIEW,     KB_ESC,   STATE_MENU_INIT
    db STATE_MAP_VIEW,     KB_TAB,   STATE_GAME_INIT
    db STATE_DEBUG_VIEW,   KB_ESC,   STATE_MENU_INIT
StateTransitionTableEnd:

init_engine:
   mov byte [_GAME_TICK_], 0x0
   mov word [_RNG_], 0x42

   mov word [_VIEWPORT_X_], MAP_SIZE/2-VIEWPORT_WIDTH/2
   mov word [_VIEWPORT_Y_], MAP_SIZE/2-VIEWPORT_HEIGHT/2
   mov word [_CURSOR_X_], MAP_SIZE/2
   mov word [_CURSOR_Y_], MAP_SIZE/2

   call init_sound
   call decompress_tiles
   call generate_map
   call init_entities
   call init_gameplay_elements

   mov byte [_GAME_STATE_], STATE_TITLE_SCREEN_INIT

jmp game_state_satisfied

init_title_screen:
   mov si, start
   mov cx, 40*25
   .random_numbers:
      lodsb
      and ax, 0x1
      add al, 0x30
      mov ah, 0x0e
      mov bh, 0
      mov bl, COLOR_DARK_GRAY
      int 0x10
   loop .random_numbers

   mov si, WelcomeText
   mov dx, 0x140B
   mov bl, COLOR_WHITE
   call draw_text

   call play_sound
   mov byte [_GAME_STATE_], STATE_TITLE_SCREEN
jmp game_state_satisfied

live_title_screen:
   mov si, PressEnterText
   mov dx, 0x1516
   mov bl, COLOR_WHITE
   test word [_GAME_TICK_], 0x4
   je .blink
      mov bl, COLOR_BLACK
   .blink:
   call draw_text
   
jmp game_state_satisfied

init_menu:
   call draw_terrain

   mov di, SCREEN_WIDTH*48
   mov al, COLOR_DEEP_PURPLE
   call draw_gradient

   call draw_minimap

   mov si, MainMenuText
   mov dx, 0x060a          ; Y/X position
   mov bl, COLOR_WHITE
   call draw_text

   mov si, MainMenu
   mov dx, 0x090d            ; Skip 2 lines
   mov bl, COLOR_YELLOW
   mov cx, 5            ; Number of menu entries
   .next_menu_entry:
      pusha
      call draw_text
      popa
      inc dh
      inc dh
      add si, MainMenuEnd-MainMenu
   loop .next_menu_entry
   .end_menu:

   mov byte [_GAME_STATE_], STATE_MENU
jmp game_state_satisfied

live_menu:
   nop
jmp game_state_satisfied

new_game:
   call generate_map
   call init_entities
   call init_gameplay_elements

   mov byte [_VIEWPORT_X_], MAP_SIZE/2-VIEWPORT_WIDTH/2
   mov byte [_VIEWPORT_Y_], MAP_SIZE/2-VIEWPORT_HEIGHT/2
   mov byte [_GAME_STATE_], STATE_MENU_INIT
jmp game_state_satisfied

init_game:
   mov al, COLOR_NAVY_BLUE
   call clear_screen
   call draw_terrain
   call draw_entities
   call draw_cursor
   mov byte [_GAME_STATE_], STATE_GAME
jmp game_state_satisfied

live_game:
   nop
jmp game_state_satisfied

init_map_view:
   call draw_minimap
   mov byte [_GAME_STATE_], STATE_MAP_VIEW
jmp game_state_satisfied

live_map_view:
   nop
jmp game_state_satisfied

init_debug_view:
   mov al, COLOR_BLACK
   call clear_screen

   mov di, 320*16+16
   xor ax, ax
   mov cx, (TilesCompressedEnd-TilesCompressed)/2
   .spr:
      call draw_sprite
      inc ax
      mov bx, ax
      and bx, 0x7
      cmp bx, 0
      jne .skip_new_line
         add di, 320*SPRITE_SIZE-SPRITE_SIZE*8
      .skip_new_line:
      add di, 16
   loop .spr

   mov byte [_GAME_STATE_], STATE_DEBUG_VIEW
jmp game_state_satisfied

live_debug_view:
   nop
jmp game_state_satisfied


























; =========================================== PROCEDURES =======================

; =========================================== CUSTOM PALETTE ===================
; IN: Palette data in RGB format
; OUT: VGA palette initialized
initialize_custom_palette:
   mov si, CustomPalette      ; Palette data pointer
   mov dx, 03C8h        ; DAC Write Port (start at index 0)
   xor al, al           ; Start with color index 0
   out dx, al           ; Send color index to DAC Write Port
   mov dx, 03C9h        ; DAC Data Port
   mov cx, 16*3         ; 16 colors × 3 bytes (R, G, B)
   rep outsb            ; Send all RGB values
ret

CustomPalette:
; DawnBringer 16 color palette
; https://github.com/geoffb/dawnbringer-palettes
; Converted from 8-bit to 6-bit for VGA
db  0,  0,  0    ; #000000 - Black
db 17,  8, 13    ; #442434 - Deep purple
db 12, 13, 27    ; #30346D - Navy blue
db 19, 18, 19    ; #4E4A4E - Dark gray
db 33, 19, 12    ; #854C30 - Brown
db 13, 25,  9    ; #346524 - Dark green
db 52, 17, 18    ; #D04648 - Red
db 29, 28, 24    ; #757161 - Light gray
db 22, 31, 51    ; #597DCE - Blue
db 52, 31, 11    ; #D27D2C - Orange
db 33, 37, 40    ; #8595A1 - Steel blue
db 27, 42, 11    ; #6DAA2C - Green
db 52, 42, 38    ; #D2AA99 - Pink/Beige
db 27, 48, 50    ; #6DC2CA - Cyan
db 54, 53, 23    ; #DAD45E - Yellow
db 55, 59, 53    ; #DEEED6 - White

; =========================================== DRAW TEXT ========================
; IN:
;  SI - Pointer to text
;  DL - X position
;  DH - Y position
;  BX - Color
draw_text:
   mov ah, 0x02   ; Set cursor
   xor bh, bh     ; Page 0
   int 0x10

.next_char:
   lodsb          ; Load next character from SI into AL
   test al, al    ; Check for string terminator
   jz .done       ; If terminator, we're done
   
   mov ah, 0x0E   ; Teletype output
   mov bh, 0      ; Page 0
   int 0x10       ; BIOS video interrupt
   
   jmp .next_char ; Process next character
   
   .done:
ret

; =========================================== GET RANDOM =======================
; OUT: AX - Random number
get_random:
   mov ax, [_RNG_]
   inc ax
   rol ax, 1
   xor ax, 0x1337
   mov [_RNG_], ax
ret

; =========================================== CLEAR SCREEN =====================
; IN: AL - Color
; OUT: VGA memory cleared (fullscreen)
clear_screen:
   mov ah, al
   mov cx, SCREEN_WIDTH*SCREEN_HEIGHT/2    ; Number of pixels
   xor di, di           ; Start at 0
   rep stosw            ; Write to the VGA memory
ret

; =========================================== DRAW GRADIENT ====================
; IN:
; DI - Position
; AL - Color
; OUT: VGA memory filled with gradient
draw_gradient:
mov ah, al
   mov dl, 0xD                ; Number of bars to draw
   .draw_gradient:
      mov cx, SCREEN_WIDTH*4           ; Number of pixels high for each bar
      rep stosw               ; Write to the VGA memory
      
      cmp dl, 0x8             ; Check if we are in the middle
      jl .down                ; If not, decrease 
      inc al                  ; Increase color in right pixel
      jmp .up
      .down:
      dec al                  ; Decrease color in left pixel
      .up:
      
      xchg al, ah             ; Swap colors (left/right pixel)
      dec dl                  ; Decrease number of bars to draw
      jg .draw_gradient       ; Loop until all bars are drawn
ret

; =========================================== GENERATE MAP =====================
generate_map:
   mov di, _MAP_
   mov si, TerrainRules
   mov cx, MAP_SIZE
   
   .next_row:
      mov dx, MAP_SIZE
      .next_cell:
         cmp dx, MAP_SIZE
         jne .not_first
            call get_random
            and ax, 0x3
            mov [di], al
            jmp .check_top
         .not_first:

         .check_left:
         movzx bx, [di-1]
         shl bx, 2
         call get_random
         and ax, 0x3
         add bx, ax
         mov al, [si+bx]
         mov [di], al            ; Save terrain tile ID

         cmp cx, MAP_SIZE
         je .skip_first_row
         .check_top:
         movzx bx, [di-MAP_SIZE]
         shl bx, 2
         call get_random
         and ax, 0x3
         add bx, ax
         mov bl, [si+bx]

         call get_random
         test ax, 0x1
         jnz .skip_first_row
         mov [di], bl            ; Save terrain tile ID
         mov al, bl
         .skip_first_row:       

         inc di
         dec dx
      jnz .next_cell
   loop .next_row
   
   call set_meta_data
ret

set_meta_data:
   mov di, _MAP_
   mov si, di
   mov cx, MAP_SIZE*MAP_SIZE
   .next_cell:
         lodsb

         .check_invisible_walls:
         cmp al, TILE_MOUNTAIN
         je .set_wall
         cmp al, TILE_TREE
         je .set_wall
         cmp al, TILE_BUSH
         
         jmp .skip_invisible_walls

         .set_wall:
            add al, META_INVISIBLE_WALL
         .skip_invisible_walls:

         stosb
   loop .next_cell
ret

; =========================================== DRAW TERRAIN =====================
; OUT: Terrain drawn on the screen
draw_terrain:
   xor di, di
   mov si, _MAP_ 
   mov ax, [_VIEWPORT_Y_]  ; Y coordinate
   shl ax, 7               ; Y * 64
   add ax, [_VIEWPORT_X_]  ; Y * 64 + X
   add si, ax
   xor ax, ax
   mov cx, VIEWPORT_HEIGHT
   .draw_line:
      push cx
      mov cx, VIEWPORT_WIDTH
      .draw_cell:
         lodsb
         mov bl, al
         and al, META_TILES_MASK ; clear metadata
         call draw_tile

         test bl, META_TRANSPORT
         jz .skip_draw_transport
         .draw_transport:
            xor ax, ax
            dec si
            .test_up:
               test byte [si-MAP_SIZE], META_TRANSPORT
               jz .test_right
               add al, 0x8
            .test_right:
               test byte [si+1], META_TRANSPORT
               jz .test_down
               add al, 0x4
            .test_down:
            test byte [si+MAP_SIZE], META_TRANSPORT
            jz .test_left
               add al, 0x2
            .test_left:
            test byte [si-1], META_TRANSPORT
            jz .done_calculating
               add al, 0x1
            .done_calculating:
            inc si
            mov bx, RailroadsList
            xlatb
            add al, 19  ; Shift to railroad tiles
            call draw_sprite

         .skip_draw_transport:

         add di, SPRITE_SIZE
      loop .draw_cell
      add di, SCREEN_WIDTH*(SPRITE_SIZE-1)
      add si, MAP_SIZE-VIEWPORT_WIDTH
      pop cx
   loop .draw_line
ret

; =========================================== DRAW TERRAIN TILE ===============
; IN: BX - Y/X
; OUT: Tile drawn on the screen
redraw_terrain_tile: 
   push si
   mov si, _MAP_ 
   movzx ax, bh   ; Y coordinate
   shl ax, 7      ; Y * 64
   add al, bl     ; Y * 64 + X
   add si, ax
   lodsb
   and al, META_TILES_MASK ; clear metadata
   call draw_tile
   pop si
ret

; =========================================== DECOMPRESS SPRITE ===============
; IN: SI - Compressed sprite data
; OUT: Sprite decompressed to _TILES_
decompress_sprite:
   pusha

   lodsb
   movzx dx, al   ; save palette
   shl dx, 2      ; multiply by 4 (palette size)

   mov cx, SPRITE_SIZE    ; Sprite width
  .plot_line:
      push cx           ; Save lines
      lodsw             ; Load 16 pixels
     
      mov cx, SPRITE_SIZE      ; 16 pixels in line
      .draw_pixel:
         cmp cx, SPRITE_SIZE/2
         jnz .cont
            lodsw
         .cont:
         rol ax, 2        ; Shift to next pixel

         mov bx, ax     ; Saves word
         and bx, 0x3    ; Cut last 2 bits
         add bx, dx     ; add palette shift
         mov byte bl, [Palettes+bx] ; get color from palette
         mov byte [_TILES_+di], bl  ; Write pixel color 
         inc di           ; Move destination to next pixel
      loop .draw_pixel

   pop cx                   ; Restore line counter
   loop .plot_line
  popa
ret

; =========================================== DECOMPRESS TILES ===============
; OUT: Tiles decompressed to _TILES_
decompress_tiles:
   xor di, di
   mov cx, TilesCompressedEnd-TilesCompressed
   .decompress_next:
      push cx

      mov bx, TilesCompressedEnd-TilesCompressed
      sub bx, cx
      shl bx, 1
      mov si, [TilesCompressed+bx] 
      
      call decompress_sprite
      add di, SPRITE_SIZE*SPRITE_SIZE

      pop cx
   loop .decompress_next
ret

; =========================================== DRAW TILE ========================
; IN: SI - Tile data
; AL - Tile ID
; DI - Position
; OUT: Tile drawn on the screen
draw_tile:  
   pusha 
   shl ax, 8         ; Multiply by 256 (tile size in array)
   mov si, _TILES_   ; Point to tile data
   add si, ax        ; Point to tile data
   mov bx, SPRITE_SIZE
   .draw_tile_line:
      mov cx, SPRITE_SIZE/4
      rep movsd      ; Move 2px at a time
      add di, SCREEN_WIDTH-SPRITE_SIZE ; Next line
      dec bx
   jnz .draw_tile_line
   popa
ret

; =========================================== DRAW SPRITE ======================
; IN:
; AL - Sprite ID
; DI - Position
; OUT: Sprite drawn on the screen
draw_sprite:  
   pusha
   shl ax, 8         ; Multiply by 256 (tile size in array)
   mov si, _TILES_   ; Point to tile data
   add si, ax        ; Point to sprite data
   mov bx, SPRITE_SIZE
   .draw_tile_line:
      mov cx, SPRITE_SIZE
      .draw_next_pixel:
         lodsb
         test al, al
         jz .skip_transparent_pixel
            mov byte [es:di], al
         .skip_transparent_pixel:
         inc di
      loop .draw_next_pixel
      add di, SCREEN_WIDTH-SPRITE_SIZE ; Next line
      dec bx
   jnz .draw_tile_line
   popa
ret

; =========================================== INIT ENTITIES ====================
init_entities:
   mov di, _ENTITIES_
   mov cx, 0x80
   .next_entity:
      call get_random
      and al, MAP_SIZE-1    ; X position (0-127)
      and ah, MAP_SIZE-1    ; Y position (0-127)
      mov word [di], ax     ; Store X,Y position
      add di, 2

      call get_random
      and ax, 0x7           ; Entity type (0-7)
      mov byte [di], al     ; Store entity type
      inc di                ; Move to next entity

      mov byte [di], 0x0   ; META data
      inc di
      loop .next_entity

   mov word [di], 0x0      ; Terminator
ret

; =========================================== DRAW ENTITIES ====================
; OUT: Entities drawn on the screen
draw_entities:
   mov si, _ENTITIES_
   .next_entity:
      lodsw
      test ax, ax
      jz .done

      .check_bounds:
         movzx bx, ah
         sub bx, [_VIEWPORT_Y_]
         jc .skip_entity
         cmp bx, VIEWPORT_HEIGHT
         jge .skip_entity

         movzx cx, al
         sub cx, [_VIEWPORT_X_]
         jc .skip_entity
         cmp cx, VIEWPORT_WIDTH
         jge .skip_entity
         
      .calculate_position:
         shl bx, 4         
         sub bx, 0x4             ; Shift entities up by 4 pixels
         shl cx, 4
         imul bx, SCREEN_WIDTH
         add bx, cx               ; AX = Y * 16 * 320 + X * 16
         mov di, bx               ; Move result to DI

      .draw_on_screen:
         lodsb                ; Load tile ID
         add ax, 0x7          ; Skip ground tiles id's
         call draw_sprite

      .check_if_cart:
         lodsb                ; Load META data
         test al, EMETA_EMPTY_CART
         jz .next_entity

         test al, EMETA_RESOURCE_ORANGE
         jnz .draw_orange_cart
         test al, EMETA_RESOURCE_BLUE
         jnz .draw_blue_cart
         jmp .next_entity
         
         .draw_orange_cart:
            mov al, TILE_RESOURCE_ORANGE+SHIFT_RESOURCE_HORIZONTAL
            call draw_sprite
            jmp .next_entity

         .draw_blue_cart:
            mov al, TILE_RESOURCE_BLUE+SHIFT_RESOURCE_HORIZONTAL
            call draw_sprite
            jmp .next_entity

      jmp .next_entity
      .skip_entity:
         add si, 2
         jmp .next_entity
   .done:
ret

draw_cursor:
   mov bx, [_CURSOR_Y_]    ; Y coordinate
   sub bx, [_VIEWPORT_Y_]  ; Y - Viewport Y
   shl bx, 4               ; Y * 16
   mov ax, [_CURSOR_X_]    ; X coordinate
   sub ax, [_VIEWPORT_X_]  ; X - Viewport X
   shl ax, 4               ; X * 16  
   imul bx, SCREEN_WIDTH   ; Y * 16 * 320
   add bx, ax              ; Y * 16 * 320 + X * 16
   mov di, bx              ; Move result to DI
   mov al, TILE_CURSOR_NORMAL
   call draw_sprite
ret

draw_minimap:
.draw_frame:
      mov di, SCREEN_WIDTH*30+90
      mov ax, COLOR_BROWN
      mov cx, 140
      .draw_line:
         push cx
         mov cx, 70
         rep stosw
         pop cx
         add di, 320-140
      loop .draw_line

   .draw_mini_map:
      mov si, _MAP_              ; Map data
      mov di, SCREEN_WIDTH*36+96          ; Map position on screen
      mov bx, TerrainColors      ; Terrain colors array
      mov cx, MAP_SIZE           ; Columns
      .draw_loop:
         push cx
         mov cx, MAP_SIZE        ; Rows
         .draw_row:
            lodsb                ; Load map cell
            and al, META_TILES_MASK ; Clear metadata
            xlatb                ; Translate to color
            mov ah, al           ; Copy color for second pixel
            mov [es:di], al      ; Draw 1 pixels
            add di, 1            ; Move to next column
         loop .draw_row
         pop cx
         add di, 320-MAP_SIZE    ; Move to next row
      loop .draw_loop

      xor ax, ax
   
   mov si, _ENTITIES_
   .next_entity:
      lodsw
      test ax, ax
      jz .end_entities
      movzx bx, ah
      imul bx, SCREEN_WIDTH
      movzx cx, al
      add bx, cx
      mov di, SCREEN_WIDTH*35+96
      add di, bx
      inc si
      mov byte [es:di], COLOR_WHITE
   loop .next_entity
   .end_entities:

   .draw_viewport_box:
      mov di, SCREEN_WIDTH*35+96
      mov ax, [_VIEWPORT_Y_]  ; Y coordinate
      imul ax, 320
      add ax, [_VIEWPORT_X_]  ; Y * 64 + X
      add di, ax
      mov ax, COLOR_WHITE
      mov ah, al
      mov cx, VIEWPORT_WIDTH/2
      rep stosw
      add di, SCREEN_WIDTH*VIEWPORT_HEIGHT-VIEWPORT_WIDTH
      mov cx, VIEWPORT_WIDTH/2
      rep stosw
ret

init_gameplay_elements:
   mov di, _MAP_ + 128*64+64
   mov cx, 8
   .add_meta:
      and byte [di], 3
      add byte [di], META_TRANSPORT
      inc di
   loop .add_meta
   mov byte [di-MAP_SIZE-8], TILE_MUD+META_TRANSPORT
   mov byte [di-MAP_SIZE*2-8], TILE_MUD+META_TRANSPORT
   mov byte [di+MAP_SIZE-2], TILE_MUD+META_TRANSPORT
   mov byte [di+MAP_SIZE*2-2], TILE_MUD+META_TRANSPORT


   mov di, _MAP_ + 128*63+68
   mov cx, 4
   .add_meta2:
      mov byte [di], TILE_PLATFORM
      inc di
   loop .add_meta2

   mov di, _ENTITIES_
   mov word [di], 0x4042 ; 64x64
   mov byte [di+2], TILE_CART_HORIZONTAl
   mov byte [di+3], META_EMPTY_CART
   
   add di, 4
   mov word [di], 0x4043 ; 64x64
   mov byte [di+2], TILE_CART_HORIZONTAl
   mov byte [di+3], META_EMPTY_CART+EMETA_EMPTY_CART+EMETA_RESOURCE_BLUE

   add di, 4
   mov word [di], 0x4044 ; 64x64
   mov byte [di+2], TILE_CART_HORIZONTAl
   mov byte [di+3], META_EMPTY_CART+EMETA_EMPTY_CART+EMETA_RESOURCE_ORANGE

   add di, 4
   mov word [di], 0x4045 ; 64x64
   mov byte [di+2], TILE_TRAIN_HORIZONTAL
   mov byte [di+3], META_TRAIN

   add di, 4
   mov word [di], 0x3F44 ; 64x64
   mov byte [di+2], TILE_BUILDING_1
   mov byte [di+3], META_EMPTY
   add di, 4
   mov word [di], 0x3F45 ; 64x64
   mov byte [di+2], TILE_BUILDING_2
   mov byte [di+3], META_EMPTY
   add di, 4
   mov word [di], 0x3F47 ; 64x64
   mov byte [di+2], TILE_BUILDING_3
   mov byte [di+3], META_EMPTY
ret

init_sound:
   mov al, 182         ; Binary mode, square wave, 16-bit divisor
   out 43h, al         ; Write to PIT command register[2]
ret

play_sound:
   mov ax, 4560        ; Middle C frequency divisor
   out 42h, al         ; Low byte first
   mov al, ah          
   out 42h, al         ; High byte[2]

   in al, 61h          ; Read current port state
   or al, 00000011b    ; Set bits 0 and 1
   out 61h, al         ; Enable speaker output[2][3]
ret

stop_sound:
   in al, 61h
   and al, 11111100b   ; Clear bits 0-1
   out 61h, al
   ret

AudioSamples:
db 0x80, 0x8C, 0x98, 0xA4, 0xAF, 0xB9, 0xC1, 0xC7
db 0xCB, 0xCD, 0xCC, 0xC9, 0xC4, 0xBD, 0xB3, 0xA8
db 0x9C, 0x8F, 0x83, 0x77, 0x6D, 0x65, 0x5F, 0x5B
db 0x5A, 0x5B, 0x5F, 0x65, 0x6D, 0x77, 0x83, 0x8F
db 0x9C, 0xA8, 0xB3, 0xBD, 0xC4, 0xC9, 0xCC, 0xCD
db 0xCB, 0xC7, 0xC1, 0xB9, 0xAF, 0xA4, 0x98, 0x8C
db 0x80, 0x74, 0x68, 0x5C, 0x51, 0x47, 0x3F, 0x39
db 0x35, 0x33, 0x34, 0x37, 0x3C, 0x43, 0x4D, 0x58
db 0x64, 0x71, 0x7D, 0x89, 0x93, 0x9B, 0xA1, 0xA5
db 0xA6, 0xA5, 0xA1, 0x9B, 0x93, 0x89, 0x7D, 0x71
db 0x64, 0x58, 0x4D, 0x43, 0x3C, 0x37, 0x34, 0x33
db 0x35, 0x39, 0x3F, 0x47, 0x51, 0x5C, 0x68, 0x74









; =========================================== DATA =============================




; =========================================== TEXT DATA ========================

WelcomeText db 'P1X ASSEMBLY ENGINE V12.01', 0x0
PressEnterText db 'PRESS ENTER', 0x0
QuitText db 'Thanks for playing!',0x0D,0x0A,'Visit http://smol.p1x.in for more games..', 0x0D, 0x0A, 0x0
MainMenuText db '"Mycelium Overlords"',0x0
MainMenu:
   ;----+----+----14
db 'F1: New Map   ',0x0
MainMenuEnd:
db 'ENTER: Play   ',0x0
db 'TAB: Minimap  ',0x0
db 'ARR: Pan view ',0x0
db 'ESC: Quit/Menu',0x0

; =========================================== TERRAIN GEN RULES ================

TerrainRules:
db 0, 1, 1, 1  ; Swamp
db 0, 1, 2, 2  ; Mud
db 1, 2, 2, 3  ; Some Grass
db 2, 3, 3, 4  ; Dense Grass
db 2, 3, 4, 5  ; Bush
db 4, 5, 5, 6  ; Tree
db 5, 5, 5, 6  ; Mountain

TerrainColors:
db 0x4         ; Swamp
db 0x4         ; Mud
db 0x4         ; Some Grass
db 0x5         ; Dense Grass
db 0x5         ; Bush
db 0x5         ; Forest
db 0xA         ; Mountain

; =========================================== TILES ============================

RailroadsList:
db 1, 1, 5, 0
db 1, 1, 2, 3
db 5, 4, 5, 6
db 7, 8, 9, 10, 11

TilesCompressed:
dw SwampTile, MudTile, SomeGrassTile, DenseGrassTile, BushTile, TreeTile, MountainTile, PlatformSprite ; 7
dw NectocyteSprite, GloopendraSprite, MycelurkSprite, VenomireSprite, WhirlygigSprite, OgorSprite ; 5
dw TrainHorizontalMotor, TrainVerticalMotor, TrainVertical2Motor, TrainVerticalEmpty, TrainHorizontalEmpty ; 10
dw Railroads3Sprite, Railroads5Sprite, Railroads6Sprite, Railroads7Sprite, Railroads9Sprite, Railroads10Sprite, Railroads11Sprite
dw Railroads12Sprite, Railroads13Sprite, Railroads14Sprite, Railroads15Sprite
dw House1Sprite, House2Sprite, House3Sprite ; 27
dw ResourceBlueSprite, ResourceBlueHorizontalSprite, ResourceBlueVerticalSprite ;38
dw ResourceOrangeSprite, ResourceOrangeHorizontalSprite, ResourceOrangeVerticalSprite ;41
dw ResourceRedSprite, ResourceRedHorizontalSprite, ResourceRedVerticalSprite ; 44
dw CursorSprite
TilesCompressedEnd:

Palettes:
db 0x2, 0x4, 0x5, 0xB ; Palette 0x0
db 0x2, 0x5, 0x3, 0xA ; Palette 0x1
db 0x5, 0xB, 0xE, 0xF ; Palette 0x2
db 0x1, 0x5, 0x3, 0xA ; Palette 0x3
db 0x0, 0x2, 0x5, 0xB ; Palette 0x4
db 0x0, 0x2, 0xE, 0xB ; Palette 0x5
db 0x0, 0x9, 0xE, 0xA ; Palette 0x6
db 0x0, 0x3, 0x4, 0x9 ; Palette 0x7
db 0x0, 0x1, 0xE, 0xF ; Palette 0x8
db 0x0, 0x1, 0x3, 0xF ; Palette 0x9
db 0x0, 0x1, 0x9, 0xE ; Palette 0xA
db 0x0, 0x2, 0x3, 0x6 ; Palette 0xB
db 0x0, 0x2, 0xB, 0xE ; Palette 0xC
db 0x0, 0x1, 0x3, 0xF ; Palette 0xD
db 0x0, 0x4, 0x3, 0xA ; Palette 0xE
db 0x0, 0x2, 0x3, 0x6 ; Palette 0xF
db 0x0, 0x9, 0xE, 0xF ; Palette 0x10
db 0x0, 0x8, 0xD, 0xF ; Palette 0x11
db 0x0, 0x2, 0x3, 0x7 ; Palette 0x12
db 0x0, 0x1, 0x4, 0x9 ; Palette 0x13
db 0x0, 0x1, 0x8, 0xD ; Palette 0x14
db 0x0, 0x2, 0x7, 0xA ; Palette 0x15

SwampTile:
db 0x00
dw 1010010101101010b, 1010100101011010b
dw 1001010101101010b, 1010010101010110b
dw 0101011001011001b, 1001010101010101b
dw 0101101010101010b, 0101010101010101b
dw 0101101010010101b, 1001010101011001b
dw 0101011001010101b, 0101010101100110b
dw 1001101001010101b, 0101010101011010b
dw 1001011010010101b, 0101010101100110b
dw 0101011010100101b, 0110010110101010b
dw 0101101010010101b, 0101101001101010b
dw 0101101001010101b, 0110101010101010b
dw 0101101001100101b, 1001101001101001b
dw 0101101010011001b, 0110100101010101b
dw 1001011010101010b, 1010100110010110b
dw 1010010110101010b, 1010101001101010b
dw 1010100101011010b, 1010101010101010b
MudTile:
db 0x00
dw 1010100101011010b, 1010101010101010b
dw 1010010101010110b, 1010100110101010b
dw 0101010101010101b, 0101010110101010b
dw 0101010101010101b, 0101011011011001b
dw 0101011001010101b, 0101011010011001b
dw 0101100110101010b, 0101010110100101b
dw 1001011001111010b, 1001010101010110b
dw 1010100111111001b, 1001010101011010b
dw 1010101110100110b, 0101010101101010b
dw 0101101010010101b, 0101101001100110b
dw 0101011001010101b, 1011100110011010b
dw 0101010101010110b, 1010101001011001b
dw 0101011010010101b, 1001010101010101b
dw 1001100111100101b, 0101101001100110b
dw 1010101110011001b, 1010101010011010b
dw 1010101010101010b, 1010101010101010b
SomeGrassTile:
db 0x00
dw 1010010110101010b, 1111101010101010b
dw 1001011010101011b, 1101101010111010b
dw 0101010101101010b, 1010101010101001b
dw 0110101001011001b, 1010100110101001b
dw 1010011010011010b, 1001100101100101b
dw 1011110110010101b, 0101010101011010b
dw 1001111010010110b, 1010010110100110b
dw 1010101001011010b, 1001010101101010b
dw 1010101001011011b, 1110100110011110b
dw 1001010110100110b, 1010100110111010b
dw 0101100101101010b, 0101010101101001b
dw 0110111001010101b, 0101010110100101b
dw 1011111001010110b, 1001010101010110b
dw 0111100101100111b, 0110100101011010b
dw 1010100110101111b, 1111101001101110b
dw 1110100110101011b, 1111101001101111b
DenseGrassTile:
db 0x0
dw 1010101011111010b, 1010101010111110b
dw 1110101010111010b, 1010101010101010b
dw 1111101010101011b, 1010111010111010b
dw 1010101010101111b, 1011111010101110b
dw 1011111010101010b, 1011111011111010b
dw 1011101011111010b, 1010101011101011b
dw 1010101111111010b, 1110101010101011b
dw 1010101010101011b, 1110101011111010b
dw 1111101010101010b, 1010101111101010b
dw 1110101011111010b, 1010101010101010b
dw 1010101111111011b, 1110101110101010b
dw 1110101010101011b, 1110111110101111b
dw 1010111110101111b, 1010111110101110b
dw 1010101111101010b, 1010101010101010b
dw 1011101011101010b, 1110101010111110b
dw 1011111010101010b, 1011101010101010b
BushTile:
db 0x00
dw 1010101011111110b, 1010101010111110b
dw 1110101110111111b, 1010111010101010b
dw 1111111111100000b, 1011110011111010b
dw 1010111111111010b, 1111101011111110b
dw 1011111110000010b, 1110001000101110b
dw 1011000000101110b, 1000001111000011b
dw 1010111010111111b, 1010111111111011b
dw 1010111011111111b, 0011111110001010b
dw 1111110011111111b, 0010110000001010b
dw 1110000010101110b, 0010100010101010b
dw 1010001111100000b, 1010101010111110b
dw 1110111111111010b, 1011111011111111b
dw 1010111110110011b, 1111100000111110b
dw 1010100010000011b, 1111110010111010b
dw 1011101011101010b, 1110101010101110b
dw 1011111010101010b, 1011101010101010b
TreeTile:
db 0x00
dw 1111101010111111b, 1010000010111110b
dw 1110111110101010b, 1111111010001110b
dw 1011111010111111b, 1011111111101010b
dw 1011111011111111b, 1110111110100010b
dw 1011111011101000b, 0000111010100010b
dw 1010101010101111b, 1000001010100000b
dw 1000111111101111b, 1111000010000000b
dw 0011111111110011b, 1110100000110000b
dw 0010101110101111b, 1010100011110000b
dw 0010001011001010b, 1010001111100010b
dw 1000110000101011b, 0010001110000010b
dw 1000101010100000b, 1100000000001111b
dw 1010000000101000b, 0000110000111111b
dw 1010100000000000b, 0000000010110010b
dw 1010101010101010b, 1011101010001010b
dw 1010101010101011b, 1111111010101010b
MountainTile:
db 0x02
dw 0000000101000000b, 0000000001010000b
dw 0100000000000000b, 0000000000000000b
dw 0100000011000000b, 0101001100010000b
dw 0000000011110000b, 0100001100000000b
dw 0000001111111000b, 0000101100110000b
dw 0100001111111100b, 0000111010110001b
dw 0000111110111110b, 0010101011100000b
dw 0000111010101010b, 0010101111101100b
dw 0000111010101110b, 1000101110111000b
dw 0000101010101011b, 1000101010101010b
dw 0010100010101000b, 1000001010001010b
dw 0010100000101000b, 0010000010011001b
dw 0010100000101000b, 0000100010000101b
dw 0010000010100010b, 0000101001010100b
dw 0100000100000001b, 0001011001010001b
dw 0101000000000000b, 0100000001000100b

BushCoverSprite:
db 0x04
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000001100b, 0000001111000000b
dw 0000000000111111b, 0000111111110000b
dw 0000110011111111b, 0011111111010000b
dw 0011110111111111b, 0110110101010000b
dw 0000010110101111b, 0110100110101000b
dw 0010011111100101b, 1010101010111000b
dw 1110111111111010b, 1011111011111010b
dw 0010101011110111b, 1111110101111100b
dw 1010101011010111b, 1111110110111010b
dw 1011101010101010b, 1110101010101110b
dw 1011111010101010b, 1011101010101010b

NectocyteSprite:
db 0x06
dw 0000000000000000b, 0000000000000000b
dw 0000000000001010b, 1000000000000000b
dw 0000000000100110b, 1010000000000000b
dw 0000000010101010b, 1010100000000000b
dw 0000001010100101b, 1011101100000000b
dw 0000001001100101b, 1010110100000000b
dw 0000101010111010b, 0111011001000000b
dw 0000101010101011b, 1010111111000000b
dw 0000100110010110b, 0101101110000000b
dw 0000101010010110b, 0101110111000000b
dw 0000101011101011b, 1011100111000000b
dw 0000001010011111b, 1111011100000000b
dw 0000000001110110b, 1101100000000000b
dw 0000000000011001b, 1010000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
GloopendraSprite:
db 0x13
dw 0000000000001111b, 1010000000000000b
dw 0000000000101111b, 1110010000000000b
dw 0000000010111110b, 1010100100000000b
dw 0000000001111001b, 0110011000000000b
dw 0000000001100111b, 1101110100000000b
dw 0000000001100111b, 1001100100000000b
dw 0000010000011001b, 0110010100000000b
dw 0001110100011010b, 0111011000010000b
dw 0010011000011001b, 1101111001110100b
dw 0001110100000110b, 0110010010011000b
dw 0111010000000110b, 1001000001110100b
dw 0110110100011110b, 0101000111010000b
dw 1001101001111010b, 1001011010100000b
dw 0010010101111001b, 0110011001000000b
dw 0000000001101101b, 1101010110000000b
dw 0000000000010101b, 0101100000000000b
MycelurkSprite:
db 0x14
dw 0000000000000000b, 0000000000000000b
dw 0000000010101010b, 1010100000000000b
dw 0000101011111111b, 1111111010000000b
dw 0010101111111111b, 1111111110100000b
dw 0010101111111111b, 1111111110101000b
dw 0010101011111111b, 1111111010100100b
dw 0001101010101010b, 1111101010010100b
dw 0000010101101001b, 1001100101010000b
dw 0000000001010111b, 0111010100000000b
dw 0000001011010101b, 0101011010000000b
dw 0000101111100101b, 0101101111100000b
dw 0000101110100110b, 1001101110100000b
dw 0000011010011011b, 1010011010010000b
dw 0000000101000110b, 1001110101000000b
dw 0000000000000001b, 0100000000000000b
dw 0000000000000000b, 0000000000000000b
VenomireSprite:
db 0x09
dw 0000000001010101b, 0000000000000000b
dw 0000001010101010b, 1000000000000000b
dw 0000101010011001b, 1001000000000000b
dw 0000101001100110b, 0101000000000000b
dw 0000011010010101b, 0101000000000000b
dw 0000000101011010b, 1010000000000000b
dw 0000000001101001b, 0101010000000000b
dw 0000001001101011b, 0111100110100000b
dw 0000101001101011b, 1011100101101000b
dw 0000100101011010b, 1010010001011000b
dw 0010010100011010b, 0110010000010100b
dw 0001010000000101b, 0001010000000100b
dw 0001000000101000b, 0000101000001000b
dw 0010000000100100b, 0000011000000000b
dw 0000000000010000b, 0000000100000000b
dw 0000000000010000b, 0000000100000000b
WhirlygigSprite:
db 0x09
dw 0000000000000000b, 0000000000000000b
dw 0000001100110000b, 0000110011000000b
dw 0000110011001110b, 0111001100110000b
dw 0011001100100111b, 1101110011001100b
dw 0000110011001101b, 1101111100110000b
dw 0011001100111101b, 1010101111001100b
dw 0000110011111010b, 1010101011110000b
dw 0000001100101010b, 1110111011000000b
dw 0000000010101010b, 1010101000000000b
dw 0000001010101010b, 1010101000000000b
dw 0000101001100101b, 0110100100000000b
dw 0000101001010110b, 1010010000000000b
dw 0010010100000010b, 0101000000000000b
dw 0010010000000000b, 0000000000000000b
dw 0001000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b

OgorSprite:
db 0x05
dw 0000000000000000b, 0101010100000000b
dw 0000000000000101b, 1111111101000000b
dw 0000000000011111b, 1010101111010000b
dw 0000000101111110b, 1011111111010000b
dw 0000011111101111b, 1111111111010000b
dw 0001111110111111b, 1111111111010000b
dw 0001111111111111b, 1101111101000000b
dw 0111111011111101b, 1101010100000000b
dw 0111101111111101b, 0101000000000000b
dw 0111111111110101b, 0100001010110000b
dw 0101101011010101b, 0000101101011100b
dw 0110111111110101b, 0011110100000100b
dw 0111110110110101b, 0011110100000000b
dw 0001111010111101b, 1111010000000000b
dw 0000010111111111b, 1101010101010100b
dw 0000000101010101b, 0101010101000000b

TrainHorizontalMotor:
db 0x0A
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000010101010101b, 0101010101000000b
dw 0001101010101010b, 1010101001010000b
dw 0001111111111111b, 1111111001010100b
dw 0001011111110101b, 0111111001110100b
dw 0001010101011010b, 1001011001111101b
dw 1011011111111111b, 1111111001111101b
dw 1101101010101010b, 1010101001111101b
dw 0110010101010101b, 0101010101011101b
dw 0001011010101010b, 0101101101010101b
dw 0001011010101010b, 0101101111010101b
dw 0001011110101010b, 1001011011010101b
dw 0001010111111011b, 1010010110010100b
dw 0000010101010101b, 0101010101010000b

TrainVerticalMotor:
db 0x0A
dw 0000000101010101b, 0101010101000000b
dw 0000011010111111b, 1111111010010000b
dw 0000011010111101b, 1111111010010000b
dw 0000011010111101b, 1111111010010000b
dw 0000011010111101b, 1111111010010000b
dw 0000011110110110b, 1011111011010000b
dw 0000011010110110b, 1011111010010000b
dw 0000011110111101b, 1111111011010000b
dw 0000011010101010b, 1010101010010000b
dw 0000010101010101b, 0101010101010000b
dw 0000010111111111b, 1111111101010000b
dw 0000010111111111b, 1111111101010000b
dw 0000010101010101b, 0101010101010000b
dw 0000010101010101b, 0101010101010000b
dw 0000010101110101b, 0101110101010000b
dw 0000000101010101b, 0101010101000000b

TrainVertical2Motor:
db 0x0A
dw 0000000000000000b, 0000000000000000b
dw 0000000101010101b, 0101010101000000b
dw 0000011010101010b, 1010101010010000b
dw 0000011110111101b, 1111111011010000b
dw 0000011010110110b, 1011111010010000b
dw 0000011110110110b, 1011111011010000b
dw 0000011010111101b, 1111111010010000b
dw 0000011010111101b, 1111111010010000b
dw 0000011010111101b, 1111111010010000b
dw 0000011010111111b, 1111111010010000b
dw 0000011010111111b, 1111111010010000b
dw 0000011010111111b, 1111111010010000b
dw 0000010101010101b, 0101010101010000b
dw 0000010101010101b, 0101010101010000b
dw 0000010110011001b, 0110011001010000b
dw 0000000101011011b, 1010010101000000b

TrainVerticalEmpty:
db 0x0A
dw 0000000101010101b, 0101010101000000b
dw 0000010111111010b, 1010101001010000b
dw 0000011110101010b, 1010101010010000b
dw 0000011110010101b, 0101011010010000b
dw 0000011101101010b, 1010100110010000b
dw 0000011101010101b, 0101010111010000b
dw 0000011001010101b, 0101010110010000b
dw 0000011101010101b, 0101010110010000b
dw 0000011001010101b, 0101010111010000b
dw 0000011001010101b, 0101010111010000b
dw 0000011101010101b, 0101010111010000b
dw 0000010111111111b, 1111111101010000b
dw 0000011001010101b, 0101010110010000b
dw 0000011010101010b, 1010101010010000b
dw 0000000110101001b, 0110101001000000b
dw 0000000001010111b, 1001010100000000b

TrainHorizontalEmpty:
db 0x0A
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000111111111110b, 1110101010100000b
dw 0011010101010101b, 0101010101011000b
dw 0011011010101010b, 1010101010011000b
dw 1011100101010101b, 0101010101101110b
dw 1111100101010101b, 0101010101101011b
dw 0111010101010101b, 0101010101011001b
dw 0110010101010101b, 0101010101011101b
dw 0001101010101011b, 1011111111110100b
dw 0001010101010101b, 0101010101010100b
dw 0001011111101110b, 1010101010010100b
dw 0000010101010101b, 0101010101010000b

Railroads5Sprite:
db 0x9
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000101000001010b, 0000101000001010b
dw 1111111111111111b, 1111111111111111b
dw 0101010101010101b, 0101010101010101b
dw 0000101000001010b, 0000101000001010b
dw 0000101000001010b, 0000101000001010b
dw 0000101000001010b, 0000101000001010b
dw 0000101000001010b, 0000101000001010b
dw 0000101000001010b, 0000101000001010b
dw 1111111111111111b, 1111111111111111b
dw 0101010101010101b, 0101010101010101b
dw 0000101000001010b, 0000101000001010b
dw 0000101000001010b, 0000101000001010b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b

Railroads10Sprite:
db 0x09
dw 0000000111000000b, 0000000011010000b
dw 0000000111000000b, 0000000011010000b
dw 0010100111101010b, 1010101011011010b
dw 0010100111101010b, 1010101011011000b
dw 0000000111000000b, 0000000011010000b
dw 0000000111000000b, 0000000011010000b
dw 0010100111101010b, 1010101011011010b
dw 0010100111101010b, 1010101011011010b
dw 0000000111000000b, 0000000011010000b
dw 0000000111000000b, 0000000011010000b
dw 0010100111101010b, 1010101011011010b
dw 0010100111101010b, 1010101011011010b
dw 0000000111000000b, 0000000011010000b
dw 0000000111000000b, 0000000011010000b
dw 0010100111101010b, 1010101011011010b
dw 0010100111101010b, 1010101011011010b

Railroads15Sprite:
db 0x09
dw 0000000111000000b, 0000000011010000b
dw 0000000111000010b, 1010000011010000b
dw 0010100111101010b, 1010101011011000b
dw 1111111111101111b, 1111111011111111b
dw 0101010101000101b, 0101010001010101b
dw 0000101011000010b, 1010000011001010b
dw 0010100111101010b, 1010101011011010b
dw 0010100111101010b, 1010101011011010b
dw 0010100111101010b, 1010101011011010b
dw 0000101000000010b, 1010000000001010b
dw 1111111111001111b, 1111110011111111b
dw 0101010111000101b, 0101010011010101b
dw 0000100111000010b, 1010000011011010b
dw 0000100111000000b, 0000000011011010b
dw 0010100111101010b, 1010101011011010b
dw 0010100111101010b, 1010101011011010b

Railroads6Sprite:
db 0x09
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000001010b, 0000000000001010b
dw 0000000000101010b, 1000111111111111b
dw 0000000000101010b, 1011010101010101b
dw 0000000000001010b, 1101100000001010b
dw 0000000000000011b, 0110101000001010b
dw 0000000000001101b, 1010101010001010b
dw 0000000000110100b, 0010101010101010b
dw 0000000011010000b, 0000101010101010b
dw 0010100111101010b, 1010101010101111b
dw 0010100111101010b, 1010101010110101b
dw 0000000111000000b, 0000000011011010b
dw 0000000111000000b, 0000000111000000b
dw 0010100111101010b, 1010100111101000b
dw 0010100111101010b, 1010100111101000b

Railroads3Sprite:
db 0x09
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000101000000000b, 0010100000000000b
dw 1111111111111100b, 1010101000000000b
dw 0101010101010111b, 1010101000000000b
dw 0000101000001001b, 1110100000000000b
dw 0000101000101010b, 0111000000000000b
dw 0000101010101010b, 1001110000000000b
dw 0000101010101010b, 0000011100000000b
dw 0000101010101000b, 0000000111000000b
dw 1111111010101010b, 1010101011011010b
dw 0101011110101010b, 1010101011011010b
dw 0000100111000000b, 0000000011010000b
dw 0000000011010000b, 0000000011010000b
dw 0000101011011010b, 1010101011011010b
dw 0000101011011010b, 1010101011011010b

Railroads12Sprite:
db 0x09
dw 0000000111000000b, 0000000111000000b
dw 0000000111000000b, 0000000111000000b
dw 0010100111101010b, 1010101001111010b
dw 0010100111101010b, 1010101010011111b
dw 0000000111000000b, 0000101010100101b
dw 0000000001110000b, 0010101010101010b
dw 0000000000011100b, 1010101010001010b
dw 0000000000000111b, 1010101000001010b
dw 0000000000001001b, 1110100000001010b
dw 0000000000101010b, 0111000000001010b
dw 0000000000101010b, 1001111111111111b
dw 0000000000001010b, 0000010101010101b
dw 0000000000000000b, 0000000000001010b
dw 0000000000000000b, 0000000000001010b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b

Railroads9Sprite:
db 0x9
dw 0000000011010000b, 0000000011010000b
dw 0000000011010000b, 0000000011010000b
dw 0010101101101010b, 1010101011011010b
dw 1111110110101010b, 1010101011011010b
dw 0101011010101000b, 0000000011010000b
dw 0010101010101010b, 0000001101000000b
dw 0010100010101010b, 1000110100000000b
dw 0010100000101010b, 1011010000000000b
dw 0010100000001010b, 1101100000000000b
dw 0010100000000011b, 0110101000000000b
dw 1111111111111101b, 1010101000000000b
dw 0101010101010100b, 0010100000000000b
dw 0010100000000000b, 0000000000000000b
dw 0010100000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b

Railroads13Sprite:
db 0x9
dw 0000001111000000b, 0000000011110000b
dw 0000110111000000b, 0000000011011100b
dw 0011010111101010b, 1010101011010111b
dw 1101011101111111b, 1111111101111101b
dw 0101010101011101b, 0101110101010101b
dw 0000101000000111b, 0011011000001010b
dw 0000101000001001b, 1101101000001010b
dw 0000101000001011b, 0111101000001010b
dw 0000101000001101b, 0001111000001010b
dw 0000101000110110b, 0000011100001010b
dw 1111111111011111b, 1111110111111111b
dw 0101010101010101b, 0101010101010101b
dw 0000101000001010b, 0000101000001010b
dw 0000101000001010b, 0000101000001010b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b

Railroads14Sprite:
db 0x9
dw 0000000111000000b, 0000000001110000b
dw 0000000111000000b, 0000000011011100b
dw 0010100111101010b, 1010101011010111b
dw 0010100101111010b, 1010101011111101b
dw 0000000111011100b, 0000001101010100b
dw 0000000111000111b, 0000110111010000b
dw 0010100111101001b, 1111011011011010b
dw 0010100111101010b, 1111011011011010b
dw 0000000111000011b, 0101110011010000b
dw 0000000111001101b, 0000011101010000b
dw 0010100101110110b, 1010100111111101b
dw 0010100111011010b, 1010101011010111b
dw 0000000111000000b, 0000000011011101b
dw 0000000111000000b, 0000000001110100b
dw 0010100111101010b, 1010101011011010b
dw 0010100111101010b, 1010101011011010b

Railroads7Sprite:
db 0x09
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000101000001010b, 0000101000001010b
dw 1111111111011111b, 1111110111111111b
dw 0101010101110101b, 0101011101010101b
dw 0000101000011110b, 0000110100001010b
dw 0000101000000111b, 0011011000001010b
dw 0000101000001001b, 1101101000001010b
dw 0000101000001011b, 0111101000001010b
dw 0000101000001101b, 0001111000001010b
dw 1101111101111111b, 1111111101111101b
dw 0111010111010101b, 0101010111010111b
dw 0001111011001010b, 0000101011001101b
dw 0000011101001010b, 0000101001110110b
dw 0010100111101010b, 1010101011011010b
dw 0010100111101010b, 1010101011011010b

Railroads11Sprite:
db 0x9
dw 0000001101000000b, 0000000011010000b
dw 0000110111000000b, 0000000011010000b
dw 0011100111101010b, 1010101011011010b
dw 1101111111101010b, 1010101101011010b
dw 0101010101110000b, 0000110111010000b
dw 0000000111011100b, 0011010011010000b
dw 0010100111100111b, 1101101011011010b
dw 0010100111100111b, 1101101011011010b
dw 0000000111001101b, 0111000011010000b
dw 0000000101110100b, 0001110011010000b
dw 1101111111011010b, 1010011101011010b
dw 0111100111101010b, 1010100111011010b
dw 0001110111000000b, 0000000011010000b
dw 0000011101000000b, 0000000011010000b
dw 0010100111101010b, 1010101011011010b
dw 0010100111101010b, 1010101011011010b

PlatformSprite:
db 0x03
dw 0101010101010101b, 0101010101010101b
dw 0111111111111111b, 1111111111110101b
dw 1111011110111010b, 1011101101111101b
dw 1101101111111111b, 1111111110011100b
dw 1111111101010101b, 0101011111111100b
dw 1110110111111111b, 1111110111101100b
dw 1111111111111111b, 1111111111111100b
dw 1110111011111111b, 1111111011101100b
dw 1110111011111111b, 1111111011101100b
dw 1111111111111111b, 1111111111111100b
dw 1110110111111111b, 1111110111101100b
dw 1111111101010101b, 0101011111111100b
dw 1101101111111111b, 1111111110011100b
dw 1111011110111010b, 1011101101111100b
dw 1011111111111111b, 1111111111111000b
dw 0100000000000000b, 0000000000000001b

House1Sprite:
db 0x15 ; sprite
dw 0000000001010101b, 0101000000000000b
dw 0000010111101110b, 1110010100000000b
dw 0001011101111111b, 1001100101000000b
dw 0001111101101110b, 1101111001000000b
dw 0001111101111111b, 1001111001000000b
dw 0001111101101110b, 1101111001010100b
dw 0101111101111111b, 1001111010111101b
dw 0101101101101110b, 1101111001111101b
dw 0101101111010101b, 0111111001101001b
dw 0101100111111111b, 1010011001100101b
dw 0101011110101010b, 1010100110111101b
dw 0101101010101010b, 0101101001111101b
dw 0101101010101001b, 1011011001101001b
dw 0101101111111001b, 1111011001100101b
dw 0001010101010101b, 0101010101100101b
dw 0000010101010101b, 0101010101010100b

House2Sprite:
db 0x15 ; sprite
dw 0000000000000000b, 0000000000000000b
dw 0000000000000101b, 0101000000000000b
dw 0000000000011111b, 1111010000000000b
dw 0000001001011111b, 1110010110000000b
dw 0000101011011111b, 1110011110100000b
dw 0000011111011111b, 1110011110010000b
dw 0001101111011111b, 1010011110100100b
dw 0001101111100101b, 0101100110100100b
dw 0001101101111110b, 1010110110100100b
dw 0001101101111010b, 1010110110010100b
dw 0001011001111010b, 1010100101100100b
dw 0001100101101001b, 0110100110010100b
dw 0000011001100110b, 1101100101010100b
dw 0000010101100111b, 1101100101010000b
dw 0000000101010101b, 0101010101000000b
dw 0000000001010101b, 0101010100000000b

House3Sprite:
db 0x15 ; sprite
dw 0000000000000101b, 0100000000000000b
dw 0000000000011010b, 1010010011010000b
dw 0000000000011011b, 1111101101010000b
dw 0000000000011011b, 1010110101000000b
dw 0000000000000110b, 1011010101000000b
dw 0000000000001001b, 1010011010010000b
dw 0000000000010110b, 0110101010100100b
dw 0000000001100101b, 1001101010110100b
dw 0000101110100101b, 0110011010110100b
dw 0010111010101001b, 0001010111110100b
dw 0010111010101001b, 0100000101010000b
dw 0001010101011001b, 0101010000000000b
dw 0111111010100101b, 0101010101010000b
dw 0110101001010101b, 1111111110010100b
dw 0101010101010101b, 1010101010010100b
dw 0001010101010101b, 0101010101010000b

ResourceBlueSprite:
db 0x11 ; sprite
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 1010000000000000b
dw 0000000000000001b, 1101000101000000b
dw 0000000000000101b, 1001100111100000b
dw 0000000000101110b, 0111011111100000b
dw 0000000000101110b, 0110011110100000b
dw 0000000001011110b, 1001011110010000b
dw 0000000001010111b, 1001011010010000b
dw 0000000110011010b, 1001011001010000b
dw 0000000111100101b, 1010111001010000b
dw 0000000111101001b, 1011101001000000b
dw 0000000110100101b, 0110100101000000b
dw 0000000110010101b, 0110010101000000b
dw 0000000001010000b, 0101010100000000b
dw 0000000000000000b, 0000000000000000b

ResourceBlueVerticalSprite:
db 0x11 ; sprite
dw 0000000000000101b, 1001000000000000b
dw 0000000000101110b, 0111000000000000b
dw 0000000000101110b, 0101010000000000b
dw 0000000001100110b, 1001111000000000b
dw 0000000001111011b, 1011111000000000b
dw 0000000001111001b, 0110011000000000b
dw 0000000001101001b, 0110010100000000b
dw 0000000001101010b, 1110010100000000b
dw 0000000010011011b, 1010010100000000b
dw 0000000000010110b, 1001010000000000b
dw 0000000000010110b, 0101000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b

ResourceBlueHorizontalSprite:
db 0x11 ; sprite
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000010b, 1000000000000000b
dw 0000000000000111b, 0100010100000000b
dw 0000000000010110b, 0110011110000000b
dw 0000000010111001b, 1101111110000000b
dw 0000000010111001b, 1001111010000000b
dw 0000000101111010b, 0101111001000000b
dw 0000000101011110b, 0101101001000000b
dw 0000011001101010b, 0101100101000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b

ResourceOrangeSprite:
db 0x10 ; sprite
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0010100000000000b
dw 0000000000000000b, 1011110100000000b
dw 0000000000001000b, 1011100100000000b
dw 0000001001101110b, 0111010100000000b
dw 0000101111101110b, 0110010100000000b
dw 0000101110011101b, 0111010100000000b
dw 0000101101011001b, 0110100110010000b
dw 0000011001101101b, 1010011011110100b
dw 0000000110101111b, 1010011011100100b
dw 0000000111101110b, 1111101111010100b
dw 0000011110110110b, 1101111010010100b
dw 0000011101100110b, 1101100110010000b
dw 0000000101010110b, 1001010101000000b
dw 0000000000000001b, 0101000000000000b
dw 0000000000000000b, 0000000000000000b

ResourceOrangeVerticalSprite:
db 0x10 ; sprite
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0010100000000000b
dw 0000000000000000b, 1011110100000000b
dw 0000000000001000b, 1011100100000000b
dw 0000000000101110b, 0111100000000000b
dw 0000000001101110b, 1110100000000000b
dw 0000000001101111b, 1101010100000000b
dw 0000000001011011b, 1011100100000000b
dw 0000000010111101b, 1110100100000000b
dw 0000000010111101b, 1010100000000000b
dw 0000000001111010b, 1111100100000000b
dw 0000000001010000b, 0000010100000000b
dw 0000000000000000b, 0000000000000000b

ResourceOrangeHorizontalSprite:
db 0x10 ; sprite
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0010100000000000b
dw 0000000000000000b, 1011110100000000b
dw 0000000000001000b, 1011100100000000b
dw 0000001001101110b, 0111100100000000b
dw 0000101111101110b, 0110010100000000b
dw 0000101110011101b, 1110100100000000b
dw 0000101101011001b, 1110100110010000b
dw 0000011001101101b, 1010011011110000b
dw 0000000110101111b, 1010011011100000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b

ResourceRedSprite:
db 0x0B ; sprite
dw 0000000000000000b, 0000000000000000b
dw 0000000000000010b, 0000000000000000b
dw 0000101001011011b, 1000001010100000b
dw 0010101111010111b, 1110011111111000b
dw 0010111111010101b, 1101111111111110b
dw 0001111011110111b, 1011011110101101b
dw 0001011010101101b, 1101111010101001b
dw 0000010110100111b, 1011011001010100b
dw 0000001001101101b, 0111110111111001b
dw 0000101111111010b, 1110111111111110b
dw 0010111111101001b, 1110011010110101b
dw 0001111110100101b, 1011010110100100b
dw 0001111010010111b, 1111100101010000b
dw 0000010101000001b, 1110010000000000b
dw 0000000000000000b, 0101000000000000b
dw 0000000000000000b, 0000000000000000b

ResourceRedVerticalSprite:
db 0x0B ; sprite
dw 0000000000000000b, 1010100000000000b
dw 0000000000000001b, 1111111000000000b
dw 0000000000000011b, 1110111110000000b
dw 0000000010100101b, 1011101101000000b
dw 0000001010111101b, 0111101001000000b
dw 0000001011111101b, 0101010100000000b
dw 0000000111101111b, 0110010101000000b
dw 0000000101101010b, 1101111110010000b
dw 0000000001011010b, 1111111111100000b
dw 0000001011111110b, 1010101101010000b
dw 0000101111111010b, 0101101001000000b
dw 0000011111101001b, 0101010100000000b
dw 0000011110100101b, 0000000000000000b
dw 0000000101010000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b

ResourceRedHorizontalSprite:
db 0x0B ; sprite
dw 0000000000001000b, 0000000000000000b
dw 0010100101101110b, 0000101010000000b
dw 1010111101011111b, 1001111111100000b
dw 1011111101010111b, 0111111111111000b
dw 0111101111011110b, 1101111010110100b
dw 0101101010110111b, 0111101010100100b
dw 0001011010011110b, 1101100101010000b
dw 0000100110110101b, 1111011111100100b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b

CursorSprite:
db 0x10
dw 0011111111111111b, 1111111111111100b
dw 1111000000000000b, 0000000000001111b
dw 1100000000000000b, 0000000000000011b
dw 1100000000000000b, 0000000000000011b
dw 1100000000000000b, 0000000000000011b
dw 1100000000000000b, 0000000000000011b
dw 1100000000000000b, 0000000000000011b
dw 1100000000000000b, 0000000000000011b
dw 1100000000000000b, 0000000000000011b
dw 1100000000000000b, 0000000000000011b
dw 1100000000000000b, 0000000000000011b
dw 1100000000000000b, 0000000000000011b
dw 1100000000000000b, 0000000000000011b
dw 1100000000000000b, 0000000000000011b
dw 1100000000000000b, 0000000000001111b
dw 0011111111111111b, 1111111111111100b


; =========================================== THE END ==========================
; Thanks for reading the source code!
; Visit http://smol.p1x.in/assembly/ for more.

Logo:
db "P1X"    ; Use HEX viewer to see P1X at the end of binary