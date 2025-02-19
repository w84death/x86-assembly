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

_ENTITIES_        equ 0x2000  ; Entities data
_MAP_             equ 0x3000  ; Map data 64x64
_MAP_METADATA_    equ 0x4000  ; Map metadata 64x64

; =========================================== GAME STATES ======================

STATE_INIT_ENGINE       equ 0
STATE_QUIT              equ 1
STATE_TITLE_SCREEN_INIT equ 2
STATE_TITLE_SCREEN      equ 3
STATE_MENU_INIT         equ 4
STATE_MENU              equ 5
STATE_GAME_INIT         equ 6
STATE_GAME              equ 7
STATE_MAP_VIEW_INIT     equ 8
STATE_MAP_VIEW          equ 9

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

; =========================================== TILES NAMES ======================

TILE_DEEP_WATER   equ 0x0
TILE_WATER        equ 0x1
TILE_SAND         equ 0x2
TILE_GRASS        equ 0x3
TILE_BUSH         equ 0x4
TILE_FOREST       equ 0x5
TILE_MOUNTAIN     equ 0x6

; =========================================== MISC SETTINGS ====================

MAP_SIZE             equ 64      ; Map size in cells DO NOT CHANGE
VIEWPORT_WIDTH       equ 20      ; Full screen 320
VIEWPORT_HEIGHT      equ 10      ; by 160
VIEWPORT_GRID_SIZE   equ 16      ; Individual cell size DO NOT CHANGE

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
   .check_transitions:
      cmp byte [si], 0xFF ; Check for end of table
      je .transitions_done
      
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
      jmp .check_transitions

   .transitions_done:

   cmp ah, KB_SPACE
   jne .not_space
      call generate_map
      mov byte [_GAME_STATE_], STATE_MAP_VIEW_INIT
   .not_space:

   ; ========================================= GAME LOGIC INPUT ================

   ; todo: handle game logic inputs

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
   dw init_game
   dw live_game
   dw init_map_view
   dw live_map_view

StateTransitionTable:
    db STATE_TITLE_SCREEN, KB_ESC,   STATE_QUIT
    db STATE_TITLE_SCREEN, KB_ENTER, STATE_MENU_INIT
    db STATE_MENU,         KB_ESC,   STATE_QUIT
    db STATE_MENU,         KB_ENTER, STATE_GAME_INIT
    db STATE_GAME,         KB_ESC,   STATE_MENU_INIT
    db STATE_GAME,         KB_TAB,   STATE_MAP_VIEW_INIT
    db STATE_MAP_VIEW,     KB_ESC,   STATE_GAME_INIT
    db STATE_MAP_VIEW,     KB_TAB,   STATE_GAME_INIT
    db 0xFF

init_engine:
   mov byte [_GAME_TICK_], 0x0
   mov word [_RNG_], 0x42

   mov word [_VIEWPORT_X_], MAP_SIZE/2-VIEWPORT_WIDTH/2
   mov word [_VIEWPORT_Y_], MAP_SIZE/2-VIEWPORT_HEIGHT/2
   
   mov byte [_TOOL_], 0x0
   mov word [_CUR_X_], VIEWPORT_WIDTH/2
   mov word [_CUR_Y_], VIEWPORT_HEIGHT/2

   call generate_map

   mov byte [_GAME_STATE_], STATE_TITLE_SCREEN_INIT

jmp game_state_satisfied

init_title_screen:
   mov al, COLOR_BLACK
   call clear_screen
   
   mov di, 320*48
   mov al, COLOR_DARK_BLUE
   mov ah, al
   mov dl, 0xD                ; Number of bars to draw
   .draw_gradient:
      mov cx, 320*4           ; Number of pixels high for each bar
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


   mov si, WelcomeText
   mov dh, 0x2          ; Y position
   mov dl, 0x3          ; X position
   mov bl, COLOR_LIGHT_BLUE
   call draw_text

   mov si, TitleText
   mov dh, 0xC      ; Y position
   mov dl, 0x7       ; X position
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

   mov si, MainMenuText
   xor dx,dx
   mov bl, COLOR_WHITE
   call draw_text
   mov byte [_GAME_STATE_], STATE_MENU
jmp game_state_satisfied

live_menu:
   nop
jmp game_state_satisfied

init_game:
   mov al, COLOR_DARK_TEAL
   call clear_screen
   mov byte [_GAME_STATE_], STATE_GAME
jmp game_state_satisfied

live_game:
   nop
jmp game_state_satisfied

init_map_view:
   mov al, COLOR_DARK_BLUE
   call clear_screen

   mov di, 320*30+90
   mov ax, COLOR_BROWN
   mov cx, 140
   .draw_line:
      push cx
      mov cx, 70
      rep stosw
      pop cx
      add di, 320-140
   loop .draw_line

   mov si, _MAP_              ; Map data
   mov di, 320*36+96          ; Map position on screen
   mov bx, TerrainColors      ; Terrain colors array
   mov cx, MAP_SIZE           ; Columns
   .draw_loop:
      push cx
      mov cx, MAP_SIZE        ; Rows
      .draw_row:
         lodsb                ; Load map cell
         xlatb                ; Translate to color
         mov ah, al           ; Copy color for second pixel
         mov [es:di], ax      ; Draw 2 pixels
         mov [es:di+320], ax  ; And another 2 pixels below
         add di, 2            ; Move to next column
      loop .draw_row
      pop cx
      add di, 320+320-MAP_SIZE*2    ; Move to next row
   loop .draw_loop

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
   xor bh, bh           ; Page 0
   mov ah, 0x2          ; Position cursor DL:DH
   int 0x10             ; Call BIOS interrupt
   mov ah, 0x0E         ; BIOS teletype
   .next_char:
      lodsb             ; Load byte at SI into AL, increment SI
      cmp al, 0         ; Check for terminator
      jz .done          ; If terminator, exit
      int 0x10          ; Print character
      jmp .next_char    ; Continue loop
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
   mov cx, 320*200/2    ; Number of pixels
   xor di, di           ; Start at 0
   rep stosw            ; Write to the VGA memory
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



; Calculate screen position for a tile at (X, Y) in a grid:
; mov  bx, [x_pos]      ; BX = X coordinate
; mov  si, [y_pos]      ; SI = Y coordinate
; lea  di, [bx + si*320] ; DI = X + Y*320 (for 16-pixel tiles)
; add  di, VIEWPORT_POS ; Add base offset
; MOV AX, YCoordinate          ; Y coordinate
; SHL AX, 6                     ; Y * 64
; LEA SI, [AX + XCoordinate]   ; SI = Y * 320 + X (offset in video memory)

; ; Load a far pointer stored in memory
; les  di, [video_ptr]  ; ES = segment, DI = offset


; mov  bx, PaletteTable  ; BX = address of palette data
; mov  al, [ColorIndex]  ; AL = index (0–255)
; xlatb                  ; AL = palette entry for ColorIndex
; mov  [es:di], al       ; Write to VGA memory


; mov  bx, TileTable     ; BX = tile graphic offsets
; mov  al, [TileID]      ; AL = tile index
; xlatb                  ; AL = offset of tile graphic
; mov  si, ax            ; SI now points to tile data















; =========================================== DATA =============================




; =========================================== TEXT DATA ========================
MainMenuText:
db 'Main Menu', 0x0D, 0x0A
db '- [ENTER] Start New Game', 0x0D, 0x0A
db '- [TAB] Toggle Map View', 0x0D, 0x0A
db '- [SPACE] Generate new map', 0x0D, 0x0A
db '- [ESC] Quit',0x0
WelcomeText:
db 'KKJ^P1X PRESENTS A 2025 PRODUCTION', 0x0
TitleText:
db '12-TH ASSEMBLY GAME ENGINE', 0x0
PressEnterText:
db 'Press [ENTER] to start engine!', 0x
QuitText:
db 'Good bye!',0x0D, 0x0A,'Visit http://smol.p1x.in/assembly/ for more games :)', 0x0A, 0x0


; =========================================== TERRAIN GEN RULES ================

TerrainRules:
db 0, 0, 0, 1  ; Deep water
db 0, 1, 1, 2  ; Water
db 1, 2, 2, 3  ; Sand
db 2, 3, 3, 4  ; Grass
db 3, 4, 4, 5  ; Bush
db 4, 5, 5, 6  ; Forest
db 5, 5, 6, 6  ; Mountain

TerrainColors:
db COLOR_BLUE        ; Deep water
db COLOR_SKY_BLUE    ; Water
db COLOR_YELLOW      ; Sand
db COLOR_LIME        ; Grass
db COLOR_GREEN       ; Bush
db COLOR_GREEN       ; Forest
db COLOR_WHITE       ; Mountain

; =========================================== THE END ==========================
; Thanks for reading the source code!
; Visit http://smol.p1x.in/assembly/ for more.

Logo:
db "P1X"    ; Use HEX viewer to see P1X at the end of binary