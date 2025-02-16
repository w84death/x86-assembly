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

_TRAINS_          equ 0x2000  ; Trains aka entities
_MAP_             equ 0x3000  ; Map data 64x64
_MAP_METADATA_    equ 0x4000  ; Map metadata 64x64

; =========================================== GAME STATES ======================

STATE_INIT_ENGINE       equ 0
STATE_QUIT              equ 1
STATE_TITLE_SCREEN_INIT equ 2
STATE_TITLE_SCREEN      equ 3
STATE_TEST_INIT         equ 4
STATE_TEST              equ 5

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

; =========================================== TILES NAMES ======================

TILE_EMPTY     equ 0x40
TILE_RAILROAD  equ 0x0
TILE_HOUSE     equ 0x1
TILE_FIELD     equ 0x2
TILE_CITY      equ 0x3
TILE_STATION   equ 0x4
TILE_FACTORY   equ 0x5
TILE_FOREST    equ 0x6
TILE_FOREST2   equ 0x7
TILE_MOUNTAINS equ 0x8
TILE_TRAIN     equ 0x9
TILES          equ 0x9

TOOLBOX_POS    equ 320*180+16

; =========================================== METADATA =========================

METADATA_EMPTY             equ 0x0
METADATA_MOVABLE           equ 0x1
METADATA_NON_DESTRUCTIBLE  equ 0x2
METADATA_FOREST            equ 0x4
METADATA_BUILDING          equ 0x8
METADATA_TRACKS            equ 0x10
METADATA_OPEN_TRACKS       equ 0x20
METADATA_STATION           equ 0x40 
METADATA_A                 equ 0x80
METADATA_B                 equ 0xFF

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

   movzx bx, byte [_GAME_STATE_]  ; Load state into BX
   shl bx, 1                     ; Multiply by 2 (word size)
   jmp word [state_jump_table + bx]   ; Jump to handle

game_state_satisfied:

; =========================================== KEYBOARD INPUT ===================

check_keyboard:
   mov ah, 01h         ; BIOS keyboard status function
   int 16h             ; Call BIOS interrupt
   jz .done

   mov ah, 00h         ; BIOS keyboard read function
   int 16h             ; Call BIOS interrupt

   cmp ah, KB_ESC
   je .process_esc
   cmp ah, KB_ENTER
   je .process_enter

   .process_esc:
      mov al, [_GAME_STATE_]
      
      cmp byte al, STATE_TITLE_SCREEN
      je .set_quit
      mov byte [_GAME_STATE_], STATE_TITLE_SCREEN_INIT
      jmp .done
      .set_quit:      
      mov byte [_GAME_STATE_], STATE_QUIT
      jmp .done
   
   .process_enter:
      mov byte [_GAME_STATE_], STATE_TEST_INIT
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













; =========================================== DRAW GAME STATES =================

init_engine:
   mov byte [_GAME_TICK_], 0x0
   mov word [_RNG_], 0x42

   mov word [_VIEWPORT_X_], MAP_SIZE/2-VIEWPORT_WIDTH/2
   mov word [_VIEWPORT_Y_], MAP_SIZE/2-VIEWPORT_HEIGHT/2
   
   mov byte [_TOOL_], 0x0
   mov word [_CUR_X_], VIEWPORT_WIDTH/2
   mov word [_CUR_Y_], VIEWPORT_HEIGHT/2
   
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

init_test_state:
   mov al, COLOR_BLACK
   call clear_screen

   mov si, TestText
   mov dh, 0x0A          ; Y position
   mov dl, 0x10          ; X position
   mov bl, COLOR_WHITE
   call draw_text
   mov byte [_GAME_STATE_], STATE_TEST
jmp game_state_satisfied

test_state:
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


; =========================================== CLEAR SCREEN =====================
clear_screen:
   mov ah, al
   mov cx, 320*200/2    ; Number of pixels
   xor di, di           ; Start at 0
   rep stosw            ; Write to the VGA memory
ret

; ; Calculate screen position for a tile at (X, Y) in a grid:
; mov  bx, [x_pos]      ; BX = X coordinate
; mov  si, [y_pos]      ; SI = Y coordinate
; lea  di, [bx + si*16] ; DI = X + Y*16 (for 16-pixel tiles)
; add  di, VIEWPORT_POS ; Add base offset



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

state_jump_table:
   dw init_engine
   dw exit
   dw init_title_screen
   dw live_title_screen
   dw init_test_state
   dw test_state
   

; =========================================== TEXT DATA ========================
TestText:
db 'TEST STATE', 0x0
ScoreText:
db 'SCORE: 0000', 0x0
CashText:
db 'CASH: $10000', 0x0
WelcomeText:
db 'KKJ^P1X PRESENTS A 2025 PRODUCTION', 0x0
TitleText:
db '12-TH ASSEMBLY GAME ENGINE', 0x0
PressEnterText:
db 'Press [ENTER] to start engine!', 0x
QuitText:
db 'Good bye!',0x0D, 0x0A,'Visit http://smol.p1x.in/assembly/ for more games :)', 0x0A, 0x0

; =========================================== THE END ==========================
; Thanks for reading the source code!
; Visit http://smol.p1x.in/assembly/ for more.

Logo:
db "P1X"    ; Use HEX viewer to see P1X at the end of binary