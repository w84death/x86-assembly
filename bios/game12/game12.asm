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
_CUR_X_        equ _BASE_ + 0x05    ; 2 bytes
_CUR_Y_        equ _BASE_ + 0x07    ; 2 bytes
_TOOL_         equ _BASE_ + 0x09    ; 1 byte
_VIEWPORT_X_   equ _BASE_ + 0x0A    ; 2 bytes
_VIEWPORT_Y_   equ _BASE_ + 0x0C    ; 2 bytes
_TUNE_POS_     equ _BASE_ + 0x0E    ; 1 byte
_TRAIN_X_      equ _BASE_ + 0x10    ; 2 byte
_TRAIN_Y_      equ _BASE_ + 0x11    ; 2 byte
_TRAIN_DIR_    equ _BASE_ + 0x12    ; 1 byte

_TILES_           equ _BASE_ + 0x20
_ENTITIES_        equ 0x3000  ; Entities data
_MAP_             equ 0x4000  ; Map data 64x64

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
STATE_GENERATE_MAP      equ 12

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

TILE_DEEP_WATER   equ 0x0
TILE_WATER        equ 0x1
TILE_SAND         equ 0x2
TILE_GRASS        equ 0x3
TILE_BUSH         equ 0x4
TILE_FOREST       equ 0x5
TILE_MOUNTAIN     equ 0x6

META_DIRTY_TILE   equ 0x80

; =========================================== MISC SETTINGS ====================

SCREEN_WIDTH         equ 320
SCREEN_HEIGHT        equ 200
MAP_SIZE             equ 128      ; Map size in cells DO NOT CHANGE
VIEWPORT_WIDTH       equ 20      ; Full screen 320
VIEWPORT_HEIGHT      equ 12      ; by 192 pixels
VIEWPORT_GRID_SIZE   equ 16      ; Individual cell size DO NOT CHANGE
SPRITE_SIZE          equ 16      ; Sprite size 16x16

; =========================================== COLORS / ARNE 16 =================

COLOR_BLACK          equ 0x0
COLOR_LIGHT_GRAY     equ 0x1
COLOR_WHITE          equ 0x2
COLOR_RED            equ 0x3
COLOR_PINK           equ 0x4
COLOR_BROWN          equ 0x5
COLOR_ORANGE_BROWN   equ 0x6
COLOR_ORANGE         equ 0x7
COLOR_YELLOW         equ 0x8
COLOR_DARK_TEAL      equ 0x9
COLOR_GREEN          equ 0xA
COLOR_LIME           equ 0xB
COLOR_DARK_BLUE      equ 0xC
COLOR_BLUE           equ 0xD
COLOR_LIGHT_BLUE     equ 0xE
COLOR_SKY_BLUE       equ 0xF

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

   cmp ah, KB_UP
   je .move_up
   cmp ah, KB_DOWN
   je .move_down
   cmp ah, KB_LEFT
   je .move_left
   cmp ah, KB_RIGHT
   je .move_right
   jmp .done

   .move_up:
      cmp word [_VIEWPORT_Y_], 0
      je .done
      dec word [_VIEWPORT_Y_]
      jmp .redraw_terrain
   .move_down:
      cmp word [_VIEWPORT_Y_], MAP_SIZE-VIEWPORT_HEIGHT
      jae .done
      inc word [_VIEWPORT_Y_]
      jmp .redraw_terrain
   .move_left:
      cmp word [_VIEWPORT_X_], 0
      je .done
      dec word [_VIEWPORT_X_]
      jmp .redraw_terrain
   .move_right:
      cmp word [_VIEWPORT_X_], MAP_SIZE-VIEWPORT_WIDTH
      jae .done
      inc word [_VIEWPORT_X_]
      jmp .redraw_terrain

   .redraw_terrain:
      call draw_terrain
      call draw_entities

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

inc word [_GAME_TICK_]  ; Increment game tick

; =========================================== ESC OR LOOP ======================

jmp main_loop

; =========================================== EXIT TO DOS ======================

exit:
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

StateTransitionTable:
    db STATE_TITLE_SCREEN, KB_ESC,   STATE_QUIT
    db STATE_TITLE_SCREEN, KB_ENTER, STATE_MENU_INIT
    db STATE_MENU,         KB_ESC,   STATE_QUIT
    db STATE_MENU,         KB_F1,    STATE_GAME_NEW
    db STATE_MENU,         KB_F2,    STATE_GAME_INIT
    db STATE_GAME,         KB_ESC,   STATE_MENU_INIT
    db STATE_GAME,         KB_TAB,   STATE_MAP_VIEW_INIT
    db STATE_MAP_VIEW,     KB_ESC,   STATE_GAME_INIT
    db STATE_MAP_VIEW,     KB_TAB,   STATE_GAME_INIT
StateTransitionTableEnd:

init_engine:
   mov byte [_GAME_TICK_], 0x0
   mov word [_RNG_], 0x42

   mov word [_VIEWPORT_X_], MAP_SIZE/2-VIEWPORT_WIDTH/2
   mov word [_VIEWPORT_Y_], MAP_SIZE/2-VIEWPORT_HEIGHT/2
   
   mov byte [_TOOL_], 0x0
   mov word [_CUR_X_], VIEWPORT_WIDTH/2
   mov word [_CUR_Y_], VIEWPORT_HEIGHT/2

   call decompress_tiles
   call generate_map
   call init_entities

   mov byte [_GAME_STATE_], STATE_TITLE_SCREEN_INIT

jmp game_state_satisfied

init_title_screen:
   mov al, COLOR_BLACK
   call clear_screen
   
   mov di, SCREEN_WIDTH*48
   mov al, COLOR_DARK_BLUE
   call draw_gradient

   mov si, WelcomeText
   mov dh, 0x2          ; Y position
   mov dl, 0x3          ; X position
   mov bl, COLOR_LIGHT_BLUE
   call draw_text

   mov si, TitleText
   mov dh, 0xC       ; Y position
   mov dl, 0x5       ; X position
   mov bl, COLOR_WHITE
   call draw_text

   mov byte [_GAME_STATE_], STATE_TITLE_SCREEN

jmp game_state_satisfied


live_title_screen:
   mov si, PressEnterText
   mov dh, 0x16      ; Y position
   mov dl, 0x5       ; X position
   mov bl, COLOR_LIGHT_BLUE
   test word [_GAME_TICK_], 0x4
   je .blink
      mov bl, COLOR_BLACK
   .blink:
   call draw_text
   
jmp game_state_satisfied

init_menu:
   mov al, COLOR_BLACK
   call clear_screen

   mov di, SCREEN_WIDTH*48
   mov al, COLOR_YELLOW
   call draw_gradient

   mov si, MainMenuText
   mov dx, 0x0904          ; Y/X position
   mov bl, COLOR_YELLOW
   call draw_text

   mov si, MainMenu
   add dh, 2            ; Skip 2 lines
   mov bl, COLOR_LIME

   mov cx, (MainMenuEnd - MainMenu)/2
   .next_menu_entry:
      lodsw     
      push si
      mov si, ax
      call draw_text
      inc dh
      pop si
   loop .next_menu_entry

   mov byte [_GAME_STATE_], STATE_MENU
jmp game_state_satisfied

live_menu:
   nop
jmp game_state_satisfied

new_game:
   call generate_map
   call init_entities
   mov byte [_VIEWPORT_X_], MAP_SIZE/2-VIEWPORT_WIDTH/2
   mov byte [_VIEWPORT_Y_], MAP_SIZE/2-VIEWPORT_HEIGHT/2

init_game:
   mov al, COLOR_DARK_TEAL
   call clear_screen
   call draw_terrain
   call draw_entities
   mov byte [_GAME_STATE_], STATE_GAME
jmp game_state_satisfied

live_game:
   nop
jmp game_state_satisfied

init_map_view:
   mov al, COLOR_DARK_BLUE
   call clear_screen

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
            xlatb                ; Translate to color
            mov ah, al           ; Copy color for second pixel
            mov [es:di], al      ; Draw 1 pixels
            ; mov [es:di+320], ax  ; And another 2 pixels below
            add di, 1            ; Move to next column
         loop .draw_row
         pop cx
         add di, 320-MAP_SIZE;*2    ; Move to next row
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
      mov byte [es:di], COLOR_RED
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

   mov byte [_GAME_STATE_], STATE_MAP_VIEW
jmp game_state_satisfied

live_map_view:
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
; Arne 16 color palette
; http://androidarts.com/palette/16pal.htm
; Converted from 8-bit to 6-bit for VGA
db  0,   0,   0    ; 0  Black
db 39,  39,  39    ; 1  Light gray  
db 63,  63,  63    ; 2  White
db 47,   9,  12    ; 3  Red
db 56,  27,  34    ; 4  Pink
db 18,  15,  10    ; 5  Brown
db 41,  25,   8    ; 6  Orange brown
db 58,  34,  12    ; 7  Orange  
db 61,  56,  26    ; 8  Yellow
db 11,  18,  19    ; 9  Dark teal
db 17,  34,   6    ; 10 Green
db 40,  51,   9    ; 11 Lime
db  6,   9,  12    ; 12 Dark blue
db  0,  21,  33    ; 13 Blue
db 12,  40,  60    ; 14 Light blue
db 44,  55,  59    ; 15 Sky blue

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
            and ax, 0x6
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
         mov [di], al

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
         mov [di], bl
         .skip_first_row:       

         inc di
         dec dx
      jnz .next_cell
   loop .next_row
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
         call draw_tile
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
      mov cx, SPRITE_SIZE/2
      rep movsw      ; Move 2px at a time
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
         mov al, [si]
         cmp al, COLOR_BLACK
         jz .skip_transparent_pixel
            mov byte [es:di], al
         .skip_transparent_pixel:
         inc di
         inc si
      loop .draw_next_pixel
      add di, SCREEN_WIDTH-SPRITE_SIZE ; Next line
      dec bx
   jnz .draw_tile_line
   popa
ret

; =========================================== INIT ENTITIES ====================
init_entities:
    mov di, _ENTITIES_
    mov cx, 0xFF
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

        loop .next_entity

    mov word [di], 0x0      ; Terminator
    ret

; =========================================== DRAW ENTITIES ====================
; OUT: Entities drawn on the screen
draw_entities:
   xor ax, ax
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
         shl cx, 4
         imul bx, SCREEN_WIDTH
         add bx, cx               ; AX = Y * 16 * 320 + X * 16
         mov di, bx               ; Move result to DI

      .draw_on_screen:
         lodsb
         add ax, 0x7
         call draw_sprite
         jmp .next_entity
      .skip_entity:
         add si, 1
         jmp .next_entity
   .done:
ret


; mov  bx, TileTable     ; BX = tile graphic offsets
; mov  al, [TileID]      ; AL = tile index
; xlatb                  ; AL = offset of tile graphic
; mov  si, ax            ; SI now points to tile data















; =========================================== DATA =============================




; =========================================== TEXT DATA ========================

WelcomeText db 'KKJ^P1X PRESENTS A 2025 PRODUCTION', 0x0
TitleText db '* 12-TH ASSEMBLY GAME ENGINE *', 0x0
PressEnterText db 'Press [ENTER] to start engine!', 0x0
QuitText db 'Good bye!',0x0D,0x0A,'Visit http://smol.p1x.in/assembly/ for more games :)', 0x0
MainMenuText         db '"Mycelium Overlords"',0x0
MenuStartNewGameText db ' [F1] Start new game',0x0
MenuGenerateMapText  db ' [F2] Continue game',0x0
MenuQuitText         db '[ESC] Quit game',0x0
MenuSpaceText        db '',0x0
MenuInstructionText  db '[TAB] Toggle map / [ARROWS] Pan',0x0
MainMenu:
dw MenuStartNewGameText
dw MenuGenerateMapText
dw MenuInstructionText
dw MenuSpaceText
dw MenuQuitText
MainMenuEnd:

; =========================================== TERRAIN GEN RULES ================

TerrainRules:
db 0, 0, 0, 1  ; Swamp
db 0, 1, 1, 2  ; Mud
db 1, 2, 2, 3  ; Some Grass
db 2, 3, 3, 4  ; Dense Grass
db 3, 4, 4, 5  ; Bush
db 4, 5, 5, 6  ; Tree
db 5, 5, 6, 6  ; Mountain

TerrainColors:
db COLOR_DARK_BLUE      ; Swamp
db COLOR_ORANGE_BROWN   ; Mud
db COLOR_GREEN          ; Some Grass
db COLOR_GREEN          ; Dense Grass
db COLOR_GREEN          ; Bush
db COLOR_DARK_TEAL      ; Forest
db COLOR_YELLOW         ; Mountain

; =========================================== TILES ============================

TilesCompressed:
dw SwampTile, MudTile, SomeGrassTile, DenseGrassTile, BushTile, TreeTile, MountainTile
SpritesCompressed:
dw NectocyteSprite, GloopendraSprite, MycelurkSprite, VenomireSprite, WhirlygigSprite, NectocyteSprite, NectocyteSprite, BushCoverTile
TilesCompressedEnd:

Palettes:
db COLOR_GREEN, COLOR_ORANGE_BROWN, COLOR_DARK_TEAL, COLOR_BLUE   ; Swamp, Mud
db COLOR_GREEN, COLOR_ORANGE_BROWN, COLOR_LIME, 0x0   ; Some Grass
db COLOR_GREEN, COLOR_LIME, COLOR_DARK_TEAL, COLOR_LIME  ; Dense Grass, Bush
db COLOR_GREEN, COLOR_LIME, COLOR_WHITE, COLOR_YELLOW ; Mountain
db COLOR_BLACK, COLOR_LIME, COLOR_DARK_TEAL, COLOR_GREEN ; Bush cover
db COLOR_BLACK, COLOR_WHITE, COLOR_SKY_BLUE, COLOR_LIGHT_BLUE ; Egg
db COLOR_BLACK, COLOR_PINK, COLOR_RED, COLOR_LIGHT_BLUE ; Worm
db COLOR_BLACK, COLOR_ORANGE_BROWN,COLOR_ORANGE, COLOR_BROWN ; Beetle
db COLOR_BLACK, COLOR_DARK_BLUE, COLOR_BROWN, COLOR_WHITE ; Spider
db COLOR_BLACK, COLOR_YELLOW, COLOR_RED, COLOR_ORANGE ; Insect

SwampTile:
db 0x00
dw 0000010101000000b, 0000000000000000b
dw 0001010101010100b, 0000010101010100b
dw 0101010101010101b, 0110101010010101b
dw 0101010101101001b, 1010111010010101b
dw 0101010110101010b, 1110101010100101b
dw 0101011010111111b, 1111111010100101b
dw 0001101010111111b, 1111111110100100b
dw 0101010110111111b, 1111111111100100b
dw 0101010110101111b, 1111111111101001b
dw 1001011010111111b, 1111111111101010b
dw 1010101011111111b, 1111111110101010b
dw 1010101111111111b, 1111101010010101b
dw 1110011111111011b, 1010101001010100b
dw 0100010101101010b, 1000101001000000b
dw 0000000110101110b, 1000010000000000b
dw 0000000101001010b, 0000000000000000b
MudTile:
db 0x00
dw 0000000101010000b, 0000000000000000b
dw 0000010101010100b, 0000000100000001b
dw 0101010101010101b, 0101010100000000b
dw 0101010101010101b, 0101010000000001b
dw 0101010101000101b, 0101010000010001b
dw 0101010000000000b, 0001010101010101b
dw 0001010000000000b, 0001010101010101b
dw 0001010000000001b, 0101010101010000b
dw 0000010000010101b, 0101010101000000b
dw 0101000000010101b, 0101000001000000b
dw 0101010101010101b, 0000000000010000b
dw 0101010101010101b, 0000000001010001b
dw 0001000101010101b, 0101010101010101b
dw 0001000000000101b, 0101000001010100b
dw 0000000000010101b, 0000000000010100b
dw 0000000001000000b, 0000000000010000b
SomeGrassTile:
db 0x01
dw 0000010101000010b, 1010000000000000b
dw 0001000000000010b, 1000000000100100b
dw 0101010101000000b, 0000000000000001b
dw 0100000001010000b, 0000000100000101b
dw 0000000000010000b, 0001000101000100b
dw 0010100000010101b, 0101010101010100b
dw 0010100000010100b, 0000010100010100b
dw 0000000001010100b, 0001010101000000b
dw 0000000001010010b, 1000000100101000b
dw 0001010100010000b, 0000000100100000b
dw 0101000101000000b, 0101010101000001b
dw 0100100001010101b, 0101010100000101b
dw 0010100001010100b, 0001010101010100b
dw 0010000101000010b, 0000000101010000b
dw 0000000100001010b, 1010000001010000b
dw 1000000100000010b, 1010000001001010b
DenseGrassTile:
db 0x2
dw 0000000001010000b, 0000000000010100b
dw 0100000000010000b, 0000000000000000b
dw 0101000000000001b, 0000010000010000b
dw 0000000000000101b, 0001010000000100b
dw 0001010000000000b, 0001010001010000b
dw 0001000001010000b, 0000000001000001b
dw 0000000101010000b, 0100000000000001b
dw 0000000000000001b, 0100000001010000b
dw 0101000000000000b, 0000000101000000b
dw 0100000001010000b, 0000000000000000b
dw 0000000101010001b, 0100000100000000b
dw 0100000000000001b, 0100010100000101b
dw 0000010100000101b, 0000010100000100b
dw 0000000101000000b, 0000000000000000b
dw 0001000001000000b, 0100000000010100b
dw 0001010000000000b, 0001000000000000b
BushTile:
db 0x02
dw 0000000001010100b, 0000000000010100b
dw 0100000100010101b, 0000010000000000b
dw 0101010101001010b, 0001011001010000b
dw 0000010101010000b, 0101010001010100b
dw 0001010101101000b, 0101100010010100b
dw 0001101010000100b, 0010100101101001b
dw 0000010000010101b, 0000010101010001b
dw 0000010001010101b, 1001010101100000b
dw 0101011001010101b, 1000011010100000b
dw 0100101000000101b, 1000001000000000b
dw 0000100101001010b, 0000000000010100b
dw 0100010101010000b, 0001010001010101b
dw 0000010101011001b, 0101011010010100b
dw 0000001001101001b, 0101011000010000b
dw 0001000001000000b, 0100000000000100b
dw 0001010000000000b, 0001000000000000b
BushCoverTile:
db 0x04
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000100b, 0000000101000000b
dw 0000000000010101b, 0000010101010000b
dw 0000010001010101b, 0001010101100000b
dw 0001011001010101b, 1011011010100000b
dw 0000101011110101b, 1011111011111100b
dw 0011100101111010b, 1111111111011100b
dw 0111010101011111b, 1101011101011111b
dw 0011111101011001b, 0101011010010100b
dw 1111111101101001b, 0101011011011111b
dw 1101111111111111b, 0111111111110111b
dw 1101011111111111b, 1101111111111111b
TreeTile:
db 0x02
dw 0000000001010000b, 0000000000010100b
dw 0100000010101010b, 0000101000000001b
dw 0101001000010001b, 1111010010100000b
dw 0000100011111101b, 1111111100100000b
dw 0000101111111111b, 0111110101101000b
dw 0010000101110101b, 1111010101101001b
dw 0100100100011100b, 0101010100101000b
dw 0100100001000001b, 0111000100100000b
dw 0000101000010101b, 0000010010100000b
dw 0100001010100101b, 0101001010000000b
dw 0000000000101000b, 1010101000000100b
dw 0000000001100110b, 0110100100000001b
dw 0000010110011010b, 0010100001000100b
dw 0000001000001000b, 0001101010000000b
dw 0001100001101010b, 0000000010010100b
dw 0001010000000000b, 0001000000000000b
MountainTile:
db 0x03
dw 0000000101000000b, 0000000001010000b
dw 0100000000000000b, 0000000000000000b
dw 0100000010000000b, 0101001000010000b
dw 0000000010100000b, 0100001000000000b
dw 0000001010101100b, 0000111000100000b
dw 0100001010101000b, 0000101111100001b
dw 0000101011101011b, 0011111110110000b
dw 0000101111111111b, 0011111010111000b
dw 0000101111111011b, 1100111011101100b
dw 0000111111111110b, 1100111111111111b
dw 0011110011111100b, 1100001111001111b
dw 0011110000111100b, 0011000011011101b
dw 0011110000111100b, 0000110011000101b
dw 0011000011110011b, 0000111101010100b
dw 0100000100000001b, 0001011101010001b
dw 0101000000000000b, 0100000001000100b
NectocyteSprite:
db 0x05
dw 0000000000000000b, 0000000000000000b
dw 0000000000000101b, 0100000000000000b
dw 0000000000010101b, 0101000000000000b
dw 0000000001010110b, 0101110000000000b 
dw 0000000101011101b, 0111011100000000b
dw 0000000101111010b, 0110011000000000b
dw 0000010110011010b, 1101110110000000b
dw 0000110101010111b, 1010111110000000b
dw 0000110111101011b, 1010111010000000b
dw 0000110101111011b, 1111111010000000b
dw 0000100110111111b, 1010110110000000b
dw 0000001001111011b, 1011011000000000b
dw 0000000010011111b, 1101100000000000b
dw 0000000000101010b, 1010000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
GloopendraSprite:
db 0x06
dw 0000000000000101b, 0101000000000000b
dw 0000000000010101b, 0101010000000000b
dw 0000000000010110b, 1001100100000000b
dw 0000000010011011b, 1110111000000000b
dw 0000000010011011b, 1110111000000000b
dw 0000010000100110b, 1011101000000000b
dw 0001111000100101b, 1011100100010000b
dw 0001101000100110b, 1110010001111000b
dw 0010111000001001b, 1001100010101000b
dw 1001100000001001b, 0110000010111000b
dw 1001101000100101b, 1010001001100000b
dw 1010010110100101b, 0110100101100000b
dw 0010101010010110b, 1001100110000000b
dw 0000000010011110b, 1110101010000000b
dw 0000000000101010b, 1010100000000000b
dw 0000000000000000b, 0000000000000000b
MycelurkSprite:
db 0x07
dw 0000000000000000b, 0000000000000000b
dw 0000000000000101b, 0101000000000000b
dw 0000000000011010b, 1010010100000000b
dw 0000000001101010b, 1010100111000000b
dw 0000001110101010b, 1001100101110000b
dw 0000110101101010b, 1010011001011100b
dw 0000111001010101b, 0101010101101100b
dw 0000001110100101b, 0101011010110000b
dw 0000001111111010b, 1010101111110000b
dw 0000000011111111b, 1111111111000000b
dw 0000000011111010b, 0110101111000000b
dw 0000001101111011b, 0111101101110000b
dw 0000110111111101b, 1001111111010000b
dw 0000001110111111b, 1011111110110000b
dw 0000000011110011b, 1011001111000000b
dw 0000000000000000b, 1100000000000000b
VenomireSprite:
db 0x08
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
dw 0000000001000000b, 0000000100000000b
dw 0000000100010000b, 0100010001000000b
dw 0000010001000101b, 1001000100010000b
dw 0001000100011001b, 0110010001000100b
dw 0001010001000110b, 0110010100010100b
dw 0001000100010110b, 1111110001000100b
dw 0000010001011101b, 0101011100010000b
dw 0000000100110101b, 1001101101000000b
dw 0000000011010101b, 0101011100000000b
dw 0000001101010110b, 1101110000000000b
dw 0000110101101000b, 1001110000000000b
dw 0000001010000010b, 0111000000000000b
dw 0000000000000000b, 1000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b
dw 0000000000000000b, 0000000000000000b

; =========================================== THE END ==========================
; Thanks for reading the source code!
; Visit http://smol.p1x.in/assembly/ for more.

Logo:
db "P1X"    ; Use HEX viewer to see P1X at the end of binary