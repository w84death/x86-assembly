; GAME12 - 2D Game Engine for DOS
;
; "Lord of Freight"
; 
; http://smol.p1x.in/assembly/#game12
; Created by Krzysztof Krystian Jankowski
; MIT License
; 01/2025
;
; TODO:
; - ability to lay trucks next to each other
; - add entities system
; - move train to entities
; - render entities loop
; - more trains
; - trains collision detection
; - buy new trains
; - cash concept / economy
; - cleaning land  using cash
; - trains stops at stations generating cash
; - train uses cash for each move

org 0x100
use16

_BASE_ equ 0x2000
_GAME_TICK_ equ _BASE_ + 0x00       ; 2 bytes
_GAME_STATE_ equ _BASE_ + 0x02      ; 1 byte
_SCORE_ equ _BASE_ + 0x03           ; 1 byte
_CUR_X_  equ _BASE_ + 0x04          ; 2 bytes
_CUR_Y_  equ _BASE_ + 0x06          ; 2 bytes
_CUR_TEST_X_  equ _BASE_ + 0x08       ; 2 bytes
_CUR_TEST_Y_  equ _BASE_ + 0x0A       ; 2 bytes
_VECTOR_COLOR_ equ _BASE_ + 0x0C    ; 1 byte
_TOOL_ equ _BASE_ + 0x0D            ; 1 byte
_VECTOR_SCALE_ equ _BASE_ + 0x0E    ; 1 byte
_VIEWPORT_X_ equ _BASE_ + 0x0F      ; 2 bytes
_VIEWPORT_Y_ equ _BASE_ + 0x11      ; 2 bytes
_RNG_ equ _BASE_ + 0x13             ; 2 bytes
_BRUSH_ equ _BASE_ + 0x15           ; 1 byte

_TRAIN_X_ equ _BASE_ + 0x16           ; 2 byte
_TRAIN_Y_ equ _BASE_ + 0x18           ; 2 byte
_TRAIN_DIR_MASK_ equ _BASE_ + 0x1A   ; 1 byte

_TUNE_POS_ equ _BASE_ + 0x1B         ; 1 byte

_TRAINS_ equ 0x2000                 ; Trains aka entities
_MAP_ equ 0x3000                    ; Map data 64x64
_MAP_METADATA_ equ 0x4000           ; Map metadata 64x64

; =========================================== GAME STATES ======================

STATE_TITLE_SCREEN equ 0
STATE_MENU equ 1
STATE_GAME equ 2
STATE_MAP_SCREEN equ 3
STATE_STATS equ 4
; ...
STATE_QUIT equ 255

KB_ESC equ 0x01
KB_UP equ 0x48
KB_DOWN equ 0x50
KB_LEFT equ 0x4B
KB_RIGHT equ 0x4D
KB_ENTER equ 0x1C
KB_SPACE equ 0x39
KB_DEL equ 0x53
KB_BACK equ 0x0E
KB_Q equ 0x10
KB_W equ 0x11
KB_M equ 0x32

TOOL_EMPTY equ 0x40
TOOL_RAILROAD equ 0x0
TOOL_HOUSE equ 0x1
TOOL_FIELD equ 0x2
TOOL_CITY equ 0x3
TOOL_STATION equ 0x4
TOOL_FACTORY equ 0x5
TOOL_FOREST equ 0x6
TOOL_FOREST2 equ 0x7
TOOL_MOUNTAINS equ 0x8
TOOL_TRAIN equ 0x9
TOOLS equ 0x9
TOOL_POS equ 320*180+16

METADATA_EMPTY equ 0x0
METADATA_MOVABLE equ 0x1
METADATA_NON_DESTRUCTIBLE equ 0x2
METADATA_FOREST equ 0x4
METADATA_BUILDING equ 0x8
METADATA_TRACKS equ 0x10
METADATA_OPEN_TRACKS equ 0x20
METADATA_STATION equ 0x40 
METADATA_A equ 0x80
METADATA_C equ 0xFF

MAP_WIDTH equ 64
MAP_HEIGHT equ 64
MAP_SIZE equ MAP_WIDTH*MAP_HEIGHT
METADATA equ MAP_SIZE

VIEWPORT_POS equ 320*16+16
VIEWPORT_WIDTH equ 18
VIEWPORT_HEIGHT equ 10
VIEWPORT_GRID_SIZE equ 16

COLOR_BACKGROUND equ 0xC
COLOR_GRID equ 0x9
COLOR_TEXT equ 0xE
COLOR_TITLE equ 0x2
COLOR_CURSOR equ 0x2
COLOR_CURSOR_ON_MAP equ 0x0404
COLOR_GRADIENT_START equ 0x0C0C
COLOR_GRADIENT_END equ 0x0C0C
COLOR_TRACKS equ 0x1
COLOR_TRAIN equ 0x7
COLOR_TREE equ 0xB
COLOR_EVERGREEN equ 0xA
COLOR_MOUNTAIN equ 0x2
COLOR_HOUSE equ 0x4
COLOR_STATION equ 0x8
COLOR_TOOLS_SELECTOR equ 0x0202
COLOR_MAP equ 0x0505
COLOR_WHITE equ 0x01
COLOR_BLACK equ 0x00

COLOR_0 equ 0x0
COLOR_1 equ 0x1
COLOR_2 equ 0x2
COLOR_3 equ 0x3
COLOR_4 equ 0x4
COLOR_5 equ 0x5
COLOR_6 equ 0x6
COLOR_7 equ 0x7
COLOR_8 equ 0x8
COLOR_9 equ 0x9
COLOR_10 equ 0xA
COLOR_11 equ 0xB
COLOR_12 equ 0xC
COLOR_13 equ 0xD
COLOR_14 equ 0xE
COLOR_15 equ 0xF

NOTE_PAUSE  equ 1

; =========================================== INITIALIZATION ===================
start:
   mov ax, 0x13        ; Init 320x200, 256 colors mode
   int 0x10            ; Video BIOS interrupt

   mov ax, 0xA000       ; VGA memory segment
   mov es, ax           ; Set ES to VGA memory segment
   xor di, di           ; Set DI to 0

   mov ax, 0x9000       
   mov ss, ax           ; Set stack segment to 0x9000
   mov sp, 0xFFFF       ; Set stack pointer to 0xFFFF

reset:
   mov byte [_GAME_TICK_], 0x0
   mov word [_RNG_], 0x42
   mov byte [_VECTOR_SCALE_], 0x0
   mov word [_VIEWPORT_X_], MAP_WIDTH/2-VIEWPORT_WIDTH/2
   mov word [_VIEWPORT_Y_], MAP_HEIGHT/2-VIEWPORT_HEIGHT/2
   mov byte [_TOOL_], 0x0
   mov word [_CUR_X_], VIEWPORT_WIDTH/2
   mov word [_CUR_Y_], VIEWPORT_HEIGHT/2
   mov word [_CUR_TEST_X_], VIEWPORT_WIDTH/2
   mov word [_CUR_TEST_Y_], VIEWPORT_HEIGHT/2
   mov byte [_TUNE_POS_], 0x0

   call setup_palette
   call init_map

   mov byte [_GAME_STATE_], STATE_TITLE_SCREEN
   call prepare_intro

; =========================================== GAME LOOP ========================

main_loop:

; =========================================== KEYBOARD INPUT ===================

check_keyboard:
   mov ah, 01h         ; BIOS keyboard status function
   int 16h             ; Call BIOS interrupt
   jz .done            ; Jump if Zero Flag is set (no key pressed)

   mov ah, 00h         ; BIOS keyboard read function
   int 16h             ; Call BIOS interrupt

   cmp ah, KB_ESC
   je .process_esc
   cmp ah, KB_ENTER
   je .process_enter

   cmp ah, KB_M
   je .process_m

   cmp byte [_GAME_STATE_], STATE_GAME
   jnz .done

   cmp ah, KB_SPACE
   je .process_space
   cmp ah, KB_DEL
   je .process_del
   cmp ah, KB_BACK
   je .process_del
   cmp ah, KB_Q
   je .process_q
   cmp ah, KB_W
   je .process_w
   cmp ah, KB_UP
   je .pressed_up
   cmp ah, KB_DOWN
   je .pressed_down
   cmp ah, KB_LEFT
   je .pressed_left
   cmp ah, KB_RIGHT
   je .pressed_right
   jmp .done

   .process_esc:
      cmp byte [_GAME_STATE_], STATE_MAP_SCREEN
      jz .go_game
      cmp byte [_GAME_STATE_], STATE_GAME
      jz .go_intro
      mov byte [_GAME_STATE_], STATE_QUIT
      jmp .done
   .process_enter:
      mov dx, 1750
      call play_note
      cmp byte [_GAME_STATE_], STATE_TITLE_SCREEN
      jz .go_game
      cmp byte [_GAME_STATE_], STATE_GAME
      jz .go_game_enter
      jmp .done
   .process_m:
      mov dx, 1750
      call play_note
      cmp byte [_GAME_STATE_], STATE_MAP_SCREEN
      jz .go_game  
      mov byte [_GAME_STATE_], STATE_MAP_SCREEN
      mov word [_GAME_TICK_], 0x0
      call prepare_map
      jmp .done
   .process_space:
      cmp byte [_GAME_STATE_], STATE_GAME
      jz .go_game_space
      jmp .done
   .process_del:
      mov dx, 2500
      call play_note
      call set_pos_to_cursor
      call convert_xy_to_screen
      call clear_tile_on_screen
      mov al, [_TOOL_]
      push ax
      mov byte [_TOOL_], TOOL_EMPTY
      call set_pos_to_cursor_w_offset
      call save_tile_to_map
      call convert_xy_pos_to_map
      call recalculate_neighbors_railroads
      pop ax
      mov byte [_TOOL_], al
      call draw_normal_cursor
      jmp .done
   .process_q:
      mov dx, 1750
      call play_note
      dec byte [_TOOL_]
      call verify_change_tool
      jmp .done
   .process_w:
      mov dx, 1750
      call play_note
      inc byte [_TOOL_]
      call verify_change_tool
      jmp .done
   .go_intro:
      mov byte [_GAME_STATE_], STATE_TITLE_SCREEN
      mov word [_GAME_TICK_], 0x0
      call prepare_intro
      jmp .done
   .go_game:
      mov byte [_GAME_STATE_], STATE_GAME
      mov word [_GAME_TICK_], 0x0
      call prepare_game
      jmp .done
   .go_game_enter:
      jmp .done
   .go_game_space:
   
      ; check if empty
      call set_pos_to_cursor_w_offset
      call convert_xy_pos_to_map
      call check_if_map_tile_empty
      jc .err_stamping

      mov dx, 9000
      call play_note
      call set_pos_to_cursor_w_offset
      call save_tile_to_map
      call set_pos_to_cursor
      call convert_xy_to_screen
      call clear_tile_on_screen

      cmp byte [_TOOL_], 0
      jz .recalculate_railroad
      
      mov al, [_TOOL_]
      mov byte [_BRUSH_], al
      call stamp_tile  
      jmp .skip_recalculate

      .recalculate_railroad:
      call set_pos_to_cursor_w_offset
      call convert_xy_pos_to_map
      call recalculate_railroad_at_pos
      call load_tile_from_map
      call recalculate_neighbors_railroads
      .skip_recalculate:

      call draw_normal_cursor
      jmp .done

      .err_stamping:
      mov dx, 1000
      call play_note
      jmp .done
   .pressed_up:
      dec word [_CUR_TEST_Y_]
      jmp .done_processed
   .pressed_down:
      inc word [_CUR_TEST_Y_]
      jmp .done_processed
   .pressed_left:
      dec word [_CUR_TEST_X_]
      jmp .done_processed
   .pressed_right:
      inc word [_CUR_TEST_X_]
      jmp .done_processed
   .done_processed:
      mov dx, 5500
      call play_note
      call move_cursor
      call draw_train
      
      mov si, _MAP_
      call set_pos_to_cursor_w_offset
      call convert_xy_pos_to_map

      mov al, [si+METADATA]
      call debug
   .done:

; =========================================== GAME STATES ======================

cmp byte [_GAME_STATE_], STATE_QUIT
je exit

cmp byte [_GAME_STATE_], STATE_TITLE_SCREEN
je draw_intro

cmp byte [_GAME_STATE_], STATE_GAME
je draw_game

cmp byte [_GAME_STATE_], STATE_MAP_SCREEN
je draw_map

jmp wait_for_tick

draw_intro:
   mov si, TitleTune
   call play_tune
   jmp wait_for_tick

draw_game:
   call train_ai
   call draw_train
   jmp wait_for_tick

draw_map:
   mov si, MapTune
   call play_tune
   mov dx, COLOR_BLACK
   mov dh, dl
   call draw_train_on_map
   call move_train
   mov dx, COLOR_WHITE
   mov dh, dl
   call draw_train_on_map
   call draw_cursor_on_map
   jmp wait_for_tick

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

sound:
   call stop_note
   .done:

; =========================================== ESC OR LOOP ======================

jmp main_loop

; =========================================== EXIT TO DOS ======================

exit:
   call stop_note

   mov ax, 0x0003       ; Set video mode to 80x25 text mode
   int 0x10             ; Call BIOS interrupt
   mov si, QuitText     ; Draw message after exit
   xor dx, dx           ; At 0/0 position
   call draw_text
   
   mov ax, 0x4c00      ; Exit to DOS
   int 0x21            ; Call DOS
   ret                 ; Return to DOS
















; =========================================== PROCEDURES =======================

setup_palette:

   mov si, Palette     ; Palette data pointer
   mov dx, 03C8h    ; DAC Write Port (start at index 0)
   xor al, al       ; Start with color index 0
   out dx, al

   mov dx, 03C9h    ; DAC Data Port
   mov cx, 16*3     ; 16 colors × 3 bytes (R, G, B)
   rep outsb        ; Send all RGB values
ret

prepare_intro:
   call clear_screen
   mov di, 320*88
   mov al, COLOR_BACKGROUND
   mov ah, al
   mov dl, 0xC                ; Number of bars to draw
   .draw_gradient:
      mov cx, 320*4           ; Number of pixels high for each bar
      rep stosw               ; Write to the VGA memory
      
      cmp dl, 0x7             ; Check if we are in the middle
      jl .down                ; If not, decrease 
      inc al                  ; Increase color in right pixel
      jmp .up
      .down:
      dec al                  ; Decrease color in left pixel
      .up:
      
      xchg al, ah             ; Swap colors (left/right pixel)
      dec dl                  ; Decrease number of bars to draw
      jg .draw_gradient       ; Loop until all bars are drawn

   mov byte [_VECTOR_SCALE_], 0x1   ; Zoom level 2
   mov bp, 320*8+130    ; Position for the vector
   mov si, P1XVector
   call draw_vector

   mov si, WelcomeText
   mov dh, 0xB          ; Y position
   mov dl, 0x2          ; X position
   mov bl, COLOR_TEXT
   call draw_text

   mov si, TitleText
   mov dh, 0x11      ; Y position
   mov dl, 0x8       ; X position
   mov bl, COLOR_TITLE
   call draw_text

   mov si, PressEnterText
   mov dh, 0x17      ; Y position
   mov dl, 0x6       ; X position
   mov bl, COLOR_TEXT
   call draw_text

ret   

prepare_game:
   call clear_screen
   call draw_grid

   mov byte [_TOOL_], 0
   mov byte [_VECTOR_SCALE_], 0
   call draw_tools
   mov dl, 0
   call update_tools_selector
   call load_map
   call draw_normal_cursor
   call draw_train

   call draw_header
ret

prepare_map:
   call clear_screen
   
   mov di, 320*(200-44)
   mov dl, 0x6                ; No bars to draw
   .draw_gradient:
      mov cx, 320*4           ; Each bar 4 pixels high
      rep stosw               ; Write to the VGA memory
      dec al                  ; Decrease color in left pixel
      xchg al, ah             ; Swap colors (left/right pixel)
      dec dl                  ; Decrease number of bars to draw
      jnz .draw_gradient      ; Loop until all bars are drawn

   mov byte [_VECTOR_SCALE_], 3
   mov bp, 320*40+8
   mov si, ForestVector
   call draw_vector

   mov bp, 320*40+196
   mov si, StationVector
   call draw_vector

   mov di, 320*30+90
   mov ax, COLOR_MAP
   mov cx, 140
   .draw_line:
      push cx
      mov cx, 70
      rep stosw
      pop cx
      add di, 320-140
   loop .draw_line

   mov si, _MAP_
   mov di, 320*36+96
   mov cx, MAP_HEIGHT
   .draw_row:
      push cx
      mov cx, MAP_WIDTH
      .draw_col:
         mov al, [si+METADATA]
         test al, METADATA_TRACKS
         jnz .set_railroads
         test al, METADATA_FOREST
         jnz .set_green
         test al, METADATA_BUILDING
         jnz .set_infra
         test al, METADATA_STATION
         jnz .set_infra
         test al, METADATA_NON_DESTRUCTIBLE
         jnz .set_mountains

         mov bx, COLOR_MAP
         jmp .push_pixel

         .set_green:
         mov bl, COLOR_TREE
         jmp .push_pixel

         .set_infra:
         mov bl, COLOR_HOUSE
         jmp .push_pixel

         .set_mountains:
         mov bl, COLOR_MOUNTAIN
         jmp .push_pixel

         .set_railroads:
         mov bl, COLOR_BLACK      

         .push_pixel:
         mov ax, bx
         mov ah, al
         mov [es:di], ax
         mov [es:di+320], ax
         inc di
         inc di
         inc si
      loop .draw_col
      pop cx
      add di, 320+320-MAP_WIDTH*2      
   loop .draw_row
ret

clear_screen:
   xor di, di
   xor si, si
   mov di, 0
   mov cx, 320*200
   mov ax, COLOR_BACKGROUND
   mov ah, al
   rep stosw
ret

draw_header:
   ; Player 1
   mov si, Player1Text
   mov dx, 0x0002
   mov bl, COLOR_TEXT
   call draw_text
   ; Score
   
   mov si, ScoreText
   mov dx, 0x000C
   mov bl, COLOR_2
   call draw_text

   ; Cash
   mov si, CashText
   mov dx, 0x001A
   mov bl, COLOR_11
   call draw_text
ret

draw_cursor_on_map:
   mov ax, [_CUR_Y_]
   add ax, [_VIEWPORT_Y_]
   mov bx, [_CUR_X_]
   add bx, [_VIEWPORT_X_]
   mov dx, COLOR_CURSOR_ON_MAP
   call draw_pixel_on_map
ret

draw_train_on_map:
   mov ax, [_TRAIN_Y_]
   mov bx, [_TRAIN_X_]
   call draw_pixel_on_map
ret

draw_pixel_on_map:
   mov di, 320*36+96
   imul ax, 320*2
   shl bx, 1
   add ax, bx
   add di, ax
   mov ax, dx
   mov [es:di], ax
   mov [es:di+320], ax
ret

draw_grid:
   pusha
   mov di, VIEWPORT_POS
   push di    
   mov al, COLOR_GRID
   mov ah, al
   .draw_horizontal_lines:
      mov cx, VIEWPORT_HEIGHT+1
      .h_line_loop:
         push cx
         mov cx, VIEWPORT_WIDTH*VIEWPORT_GRID_SIZE/2
         rep stosw
         pop cx
         add di, 320*VIEWPORT_GRID_SIZE-VIEWPORT_WIDTH*VIEWPORT_GRID_SIZE
      loop .h_line_loop
   .draw_vertical_lines:
      pop di
      mov cx, VIEWPORT_WIDTH+1
      .v_line_loop:
         push cx
         mov cx, VIEWPORT_HEIGHT*VIEWPORT_GRID_SIZE
         .draw_v:
            stosb
            inc di
            add di, 318
         loop .draw_v
         pop cx
         add di, 320*45-(VIEWPORT_GRID_SIZE*3)
      loop .v_line_loop
   popa
ret

draw_tools:
   mov bp, TOOL_POS
   mov byte [_BRUSH_], 0
   mov cx, TOOLS
   .tools_loop:
      push cx
      call stamp_tile
      inc byte [_BRUSH_]
      add bp, 24
      pop cx
   loop .tools_loop
ret


validate_xy_onscreen:
   cmp bx, 0
   jl .err
   cmp bx, VIEWPORT_WIDTH
   jge .err
   cmp ax, 0
   jl .err
   cmp ax, VIEWPORT_HEIGHT
   jge .err
   jmp .done
   .err:
      stc
      ret
   .done:
   clc
ret

; =========================================== DRAW TEXT ========================
; STACK:
; SI - Pointer to text
; DL - X position
; DH - Y position
; BX - Color
draw_text:
   mov bh, 0x0
   mov ah, 0x02
   int 0x10                ; Set cursor position
   mov ah, 0x0E            ; BIOS teletype
   .next_char:
      lodsb                    ; Load byte at SI into AL, increment SI
      cmp al, 0            ; Check for terminator
      jz .done               ; If terminator, exit
      int 0x10              ; Print character
      jmp .next_char             ; Continue loop
   .done:
ret

convert_cur_pos_to_screen:
   mov ax, [_CUR_Y_]
   shl ax, 4
   imul ax, 320
   mov bx, [_CUR_X_]
   shl bx, 4
   add ax, bx
   add ax, VIEWPORT_POS
   mov bp, ax
ret

set_pos_to_cursor_w_offset:
   mov ax, [_CUR_Y_]
   add ax, [_VIEWPORT_Y_]
   mov bx, [_CUR_X_]
   add bx, [_VIEWPORT_X_]
ret

set_pos_to_cursor:
   mov ax, [_CUR_Y_]
   mov bx, [_CUR_X_]
ret

convert_xy_pos_to_map:
   push ax
   mov si, _MAP_
   imul ax, MAP_WIDTH
   add ax, bx
   add si, ax
   pop ax
ret

convert_xy_to_screen:
   push ax
   push bx
   ; imul ax, VIEWPORT_GRID_SIZE
   shl ax, 4
   imul ax, 320
   ; imul bx, VIEWPORT_GRID_SIZE
   shl bx, 4
   add ax, bx
   add ax, VIEWPORT_POS
   mov bp, ax   

   pop bx
   pop ax
ret

clear_tile_on_screen:
   pusha
   mov di, bp
   add di, 320+1
   mov ax, COLOR_BACKGROUND
   mov ah, al

   mov cx, VIEWPORT_GRID_SIZE-1
   .v_line_loop:
      push cx
      mov cx, VIEWPORT_GRID_SIZE-1
      rep stosb
      pop cx
      add di, 320-VIEWPORT_GRID_SIZE+1
   loop .v_line_loop
   popa
ret

stamp_tile:
   pusha

   xor bx, bx
   mov byte bl, [_BRUSH_]

   shl bx, 1
   mov si, ToolsList   
   add si, bx
   lodsw
   mov si, ax
   
   call draw_vector

   popa
ret

recalculate_neighbors_railroads:
   call set_pos_to_cursor
   inc ax
   call validate_xy_onscreen
   jc .skip1
   call set_pos_to_cursor
   inc ax
   call convert_xy_to_screen
   call clear_tile_on_screen
   .skip1:
   call set_pos_to_cursor_w_offset
   inc ax
   call convert_xy_pos_to_map
   call recalculate_railroad_at_pos
   call set_pos_to_cursor
   inc ax
   call validate_xy_onscreen
   jc .skip2
   call load_tile_from_map
   
   .skip2:

   call set_pos_to_cursor
   dec ax
   call validate_xy_onscreen
   jc .skip3
   call convert_xy_to_screen
   call clear_tile_on_screen
   .skip3:
   call set_pos_to_cursor_w_offset
   dec ax
   call convert_xy_pos_to_map
   call recalculate_railroad_at_pos
   call set_pos_to_cursor
   dec ax
   call validate_xy_onscreen
   jc .skip4
   call load_tile_from_map
   .skip4:
      
   call set_pos_to_cursor
   dec bx
   call validate_xy_onscreen
   jc .skip5
   call convert_xy_to_screen
   call clear_tile_on_screen
   .skip5:
   call set_pos_to_cursor_w_offset
   dec bx
   call convert_xy_pos_to_map
   call recalculate_railroad_at_pos
   call set_pos_to_cursor
   dec bx
   call validate_xy_onscreen
   jc .skip6
   call load_tile_from_map
   .skip6:

   call set_pos_to_cursor
   inc bx
   call validate_xy_onscreen
   jc .skip7
   call convert_xy_to_screen
   call clear_tile_on_screen
   .skip7:
   call set_pos_to_cursor_w_offset
   inc bx
   call convert_xy_pos_to_map
   call recalculate_railroad_at_pos
   call set_pos_to_cursor
   inc bx
   call validate_xy_onscreen
   jc .skip8
   call load_tile_from_map
   .skip8:
ret

recalculate_railroad_at_pos:
   xor bx, bx

   test byte [si+METADATA], METADATA_TRACKS
   jz .done

   test byte [si+METADATA-MAP_WIDTH], METADATA_TRACKS ; up
   jz .next1
      add bl, 8
   .next1:

   test byte [si+METADATA+1], METADATA_TRACKS ; right
   jz .next2
      add bl, 4
   .next2:

   test byte [si+METADATA+MAP_WIDTH], METADATA_TRACKS ; down
   jz .next3
      add bl, 2
   .next3:

   test byte [si+METADATA-1], METADATA_TRACKS ; left
   jz .next4
      add bl, 1
   .next4:

   cmp bl, 0xC
   jle .skip_crossing
      mov bl, 0xF ; Crossing
   .skip_crossing:

   .save_to_map:
   add bl, TOOLS  ; move over tools list
   mov byte [si], bl

   .done:
ret

save_tile_to_map:
   call convert_xy_pos_to_map
   mov al, [_TOOL_]
   mov byte [si], al
   call set_metadata_values
   mov byte [si+METADATA], ah
ret

init_map:
   mov di, _MAP_
   mov cx, MAP_WIDTH*MAP_HEIGHT
   .init_loop:
      call get_random
      and ax, 0xF
      cmp ax, 0x7
      jl .set_empty
      cmp ax, 0x9
      jl .set_forest
      cmp ax, 0x9
      jz .set_mountains

      .set_evergreen:
         mov al, TOOL_FOREST2
         jmp .done
      .set_forest:
         mov al, TOOL_FOREST
         jmp .done
      
      .set_mountains:
         mov al, TOOL_MOUNTAINS
         jmp .done
      .set_empty:
         mov al, TOOL_EMPTY 
      .done:
      mov [di], al
      call set_metadata_values
      mov [di+METADATA], ah
      inc di
   loop .init_loop

   mov di, _MAP_
   add di, MAP_WIDTH*31+32
   mov byte [di], TOOL_RAILROAD
   mov byte [di+METADATA], METADATA_TRACKS
   mov word [_TRAIN_X_], 32
   mov word [_TRAIN_Y_], 31
   mov byte [_TRAIN_DIR_MASK_], 0
ret

set_metadata_values:
   .set_railroads:
      cmp al, TOOL_RAILROAD
      jnz .set_forest
      mov ah, METADATA_TRACKS
      jmp .done
   .set_forest:
      cmp al, TOOL_FOREST
      jnz .set_evergreen
      mov ah, METADATA_FOREST
      jmp .done
   .set_evergreen:
      cmp al, TOOL_FOREST2
      jnz .set_mountains
      mov ah, METADATA_FOREST
      jmp .done
   .set_mountains:
      cmp al, TOOL_MOUNTAINS
      jnz .set_empty
      mov ah, METADATA_NON_DESTRUCTIBLE
      jmp .done
   .set_empty:
      mov al, TOOL_EMPTY 
      mov ah, METADATA_MOVABLE 
   .done:
ret

load_map:
   xor ax, ax
   mov al, [_TOOL_]
   push ax
   mov si, _MAP_
   mov bp, VIEWPORT_POS

   mov ax, [_VIEWPORT_Y_]
   imul ax, MAP_WIDTH
   add ax, [_VIEWPORT_X_]
   add si, ax

   mov cx, VIEWPORT_HEIGHT
   .v_loop:
      push cx

      mov cx, VIEWPORT_WIDTH
      .h_line_loop:
         call clear_tile_on_screen
         mov al, [si]

         cmp al, TOOL_EMPTY
         jz .done
         mov byte [_BRUSH_], al
         call stamp_tile
   
         .done:
         add bp, VIEWPORT_GRID_SIZE
         inc si
      loop .h_line_loop
      add si, MAP_WIDTH-VIEWPORT_WIDTH
      pop cx
      add bp, 320*(VIEWPORT_GRID_SIZE-1)+VIEWPORT_GRID_SIZE*2
   loop .v_loop

   pop ax
   mov byte [_TOOL_], al
ret

load_tile_from_map:
   pusha
   mov al, [si]
   cmp al, TOOL_EMPTY
   jz .done
      mov byte [_BRUSH_], al
      call stamp_tile
   .done:
   popa
ret

check_if_map_tile_empty:
   mov al, [si+METADATA]
   test al, METADATA_MOVABLE
   jz .movable
      clc
ret
   .movable:
      stc
ret

move_cursor:
   call draw_erase_cursor
   mov ax, [_CUR_TEST_X_]
   cmp ax, 0
   jl .left_end
   cmp ax, VIEWPORT_WIDTH-1
   jg .right_end
   mov [_CUR_X_], ax

   mov ax, [_CUR_TEST_Y_]
   cmp ax, 0
   jl .top_end
   cmp ax, VIEWPORT_HEIGHT-1
   jg .bottom_end
   mov [_CUR_Y_], ax
   jmp .done
   
   .top_end:
      cmp word [_VIEWPORT_Y_], 0
      je .done
      dec word [_VIEWPORT_Y_]
      jmp .pan_map
   .bottom_end:
      cmp word [_VIEWPORT_Y_], MAP_HEIGHT-VIEWPORT_HEIGHT-1
      je .done
      inc word [_VIEWPORT_Y_]
      jmp .pan_map
   .left_end:
      cmp word [_VIEWPORT_X_], 0
      je .done
      dec word [_VIEWPORT_X_]
      jmp .pan_map
   .right_end:
      cmp word [_VIEWPORT_X_], MAP_WIDTH-VIEWPORT_WIDTH-1
      je .done
      inc word [_VIEWPORT_X_]
      jmp .pan_map
   .pan_map:
      mov ax, [_CUR_X_]
      mov [_CUR_TEST_X_], ax
      mov ax, [_CUR_Y_]
      mov [_CUR_TEST_Y_], ax
      call load_map 
   .done:
      mov ax, [_CUR_X_]
      mov [_CUR_TEST_X_], ax
      mov ax, [_CUR_Y_]
      mov [_CUR_TEST_Y_], ax
   
   call draw_normal_cursor
ret

draw_normal_cursor:
   mov si, CursorVector
   call draw_cursor
ret

draw_erase_cursor:
   mov si, CursorEraseVector
   call draw_cursor
ret

draw_cursor:
   mov ax, [_CUR_Y_]
   mov bx, [_CUR_X_]
   call convert_xy_to_screen
   call draw_vector
ret
 
verify_change_tool:
   mov dl, [_TOOL_]
   cmp dl, TOOLS
   jl .ok
      xor dl, dl
   .ok:
   cmp dl, 0
   jge .ok2
      mov dl, TOOLS-1
   .ok2:
   mov byte [_TOOL_], dl
   call update_tools_selector
ret

update_tools_selector:
   mov di, TOOL_POS+320*17
   mov cx, 180
   mov ax, COLOR_BACKGROUND
   mov ah, al
   rep stosw

   mov di, TOOL_POS+320*17
   xor bx, bx
   mov bl, dl
   imul bx, 24
   add di, bx
   mov cx, 8
   mov ax, COLOR_TOOLS_SELECTOR
   rep stosw
ret

train_ai:
   mov ax, [_TRAIN_Y_]
   sub ax, [_VIEWPORT_Y_]
   mov bx, [_TRAIN_X_]
   sub bx, [_VIEWPORT_X_]
   
   cmp bx, 0
   jl .outside_viewport
   cmp bx, VIEWPORT_WIDTH
   jge .outside_viewport
   cmp ax, 0
   jl .outside_viewport
   cmp ax, VIEWPORT_HEIGHT
   jge .outside_viewport


   call convert_xy_to_screen
   call clear_tile_on_screen
   
   mov si, _MAP_
   mov ax, [_TRAIN_Y_]
   mov bx, [_TRAIN_X_]
   imul ax, MAP_WIDTH
   add ax, bx
   add si, ax
   call load_tile_from_map

   .outside_viewport:
   call move_train
ret

draw_train:
   mov ax, [_TRAIN_Y_]
   sub ax, [_VIEWPORT_Y_]
   mov bx, [_TRAIN_X_]
   sub bx, [_VIEWPORT_X_]
   
   cmp bx, 0                     ; Check if train is on screen
   jl .do_not_draw_train         ; left side
   cmp bx, VIEWPORT_WIDTH        ; right side
   jge .do_not_draw_train
   cmp ax, 0                     ; top side
   jl .do_not_draw_train
   cmp ax, VIEWPORT_HEIGHT       ; bottom side
   jge .do_not_draw_train

   call convert_xy_to_screen

   mov si, TrainVector
   call draw_vector

   .do_not_draw_train:
ret


move_train:
   mov si, _MAP_
   mov ax, [_TRAIN_Y_]
   mov bx, [_TRAIN_X_]
   imul ax, MAP_WIDTH
   add ax, bx
   add si, ax
   mov al, [si]
   sub al, TOOLS  ; move over tools list
   mov bl, [_TRAIN_DIR_MASK_] ; remove the direction the train came from
   
  
   cmp al, 0xf    ; Check if it's a crossing
   jnz .not_crossing

   cmp bl, 8
   jz .move_down
   cmp bl, 4
   jz .move_left
   cmp bl, 2
   jz .move_up
   cmp bl, 1
   jz .move_right
   jmp .done

   jmp .train_moved
   .not_crossing:
   sub al, bl

   .test_up:
   test al, 8
   jz .test_right
   test byte [si+METADATA-MAP_WIDTH], METADATA_TRACKS
   jz .test_right
   jmp .move_up
   .test_right:
   test al, 4
   jz .test_down
   test byte [si+METADATA+1], METADATA_TRACKS
   jz .test_down
   jmp .move_right
   .test_down:
   test al, 2
   jz .test_left
   test byte [si+METADATA+MAP_WIDTH], METADATA_TRACKS
   jz .test_left
   jmp .move_down
   .test_left:
   test al, 1
   jz .no_move
   test byte [si+METADATA-1], METADATA_TRACKS
   jz .no_move
   jmp .move_left
  

  .move_up:
   dec word [_TRAIN_Y_]
   mov bl, 2
   jmp .train_moved

   .move_right:
   inc word [_TRAIN_X_]
   mov bl, 1
   jmp .train_moved

   .move_down:
   inc word [_TRAIN_Y_]
   mov bl, 8
   jmp .train_moved

   .move_left:
   dec word [_TRAIN_X_]
   mov bl, 4
   jmp .train_moved

   .no_move:
   mov bl, al
   .train_moved:
   mov byte [_TRAIN_DIR_MASK_], bl

   .done:
ret

; =========================================== DRAW VECTOR ======================
; SI - Vector data
; BP - Position in VGA memory

draw_vector:   
   pusha 
   .read_color:
   mov cl, [si]
   mov [_VECTOR_COLOR_], cl
   inc si
   .read_group:
      xor cx, cx
      mov cl, [si]
      cmp cl, 0x0
      jz .done

      inc si

      .read_line:
      push cx

      xor cx, cx
      mov cl, [_VECTOR_SCALE_]

      xor ax, ax
      mov al, [si]
      shl ax, cl
      add ax, bp
      xor bx, bx
      mov bl, [si+2]
      shl bx, cl
      add bx, bp          ; Move to position
      mov dl, [si+1]
      shl dl, cl
      mov dh, [si+3]     
      shl dh, cl  
      mov cl, [_VECTOR_COLOR_]
      mov ch, cl
      
      call draw_line

      add si, 2
      pop cx
      loop .read_line
      add si, 2
      jmp .read_group
   .done:
   popa
ret

get_random:
   mov ax, [_RNG_]
   inc ax
   rol ax, 1
   xor ax, 0x1337
   mov [_RNG_], ax
ret

debug:
   ; AL - value to show
   xor dx,dx
   mov bh, 0x0
   mov ah, 0x02
   int 0x10 
   mov ah, 0x0E  
   add al, 0x30
   int 0x10
ret

; =========================================== DRAWING LINE ====================
; X0 - AX, Y0 - DL
; X1 - BX, Y1 - DH
; COLOR - CL
; Spektre @ https://stackoverflow.com/questions/71390507/line-drawing-algorithm-in-assembly#71391899
draw_line:
   push si 
   push bp

   push ax
   mov si,bx
   sub si,ax
   sub ah,ah
   mov al,dl
   mov bx,ax
   mov al,dh
   sub ax,bx
   mov di,ax
   mov ax,320
   sub dh,dh
   mul dx
   pop bx
   add ax,bx
   mov bp,ax
   mov ax,1
   mov bx,320
   cmp si,32768
   jb  .r0
   neg si
   neg ax
.r0:    cmp di,32768
   jb  .r1
   neg di
   neg bx
.r1:    cmp si,di
   ja  .r2
   xchg    ax,bx
   xchg    si,di
.r2:    mov [.ct],si
.l0:    mov byte [es:bp], cl
   add bp,ax
   sub dx,di
   jnc .r3
   add dx,si
   add bp,bx
.r3:    dec word [.ct]
   jnz .l0
   pop bp
   pop si
ret
 .ct:    dw  0


play_tune:
   xor ax, ax
   xor bx, bx
   mov al, [_TUNE_POS_] ; Get current position
   add si, ax      ; Move to the position
   mov bl, [si]      ; Get the note
   
   cmp bl, 0xFF   ; Check if it's the end of the tune
   jz .restart_tune
   cmp bl, 0x0    ; Check if it's a pause
   jz .pause_note

   mov di, Notes  ; Move to the notes table
   add di, bx    ; Move to the note
   mov dx, [di]  ; Get the frequency
   call play_note

   .pause_note:
   inc byte [_TUNE_POS_] ; Move to the next note
ret
   .restart_tune:
   mov byte [_TUNE_POS_], 0 ; Move to first note (restart)
ret

play_note:
   mov al, 0xB6          ; Control word: channel 2, low/high byte, mode 3
   out 0x43, al
   out 0x42, al          ; Low byte of frequency
   mov al, dh            ; High byte of frequency
   out 0x42, al
   in  al, 0x61         ; Read current speaker port
   or  al, 0x3            ; Set bits 0 and 1 to enable channel 2 output
   out 0x61, al
ret

stop_note:
   in  al, 0x61
   and al, 0xFC         ; Clear bits 0 and 1
   out 0x61, al
ret


; =========================================== DATA =============================
Player1Text:                                 ;
db 'PLAYER 1', 0x0
ScoreText:
db 'SCORE: 0000', 0x0
CashText:
db 'CASH: $10000', 0x0
WelcomeText:
db 'KRZYSZTOF KRYSTIAN JANKOWSKI PRESENTS', 0x0
TitleText:
db '12-TH ASSEMBLY PRODUCTION', 0x0
PressEnterText:
db 'Press ENTER to start the game', 0x0
QuitText:
db 'Good bye!',0x0D, 0x0A,'Visit http://smol.p1x.in/assembly/ for more games :)', 0x0A, 0x0

P1XVector:
db 0x1f
db 4
db 2, 35, 2, 2, 10, 2, 10, 20, 2, 20
db 1
db 11, 5, 14, 5
db 1
db 14, 35, 14, 2
db 3
db 18, 35, 18, 19, 24, 11, 24, 2
db 3
db 24, 35, 24, 19, 18, 11, 18, 2
db 0

CursorVector:
db COLOR_CURSOR
db 4
db 0, 0, 16, 0, 16, 16, 0, 16, 0, 0
db 0

CursorEraseVector:
db COLOR_GRID
db 4
db 0, 0, 16, 0, 16, 16, 0, 16, 0, 0
db 0

DebugVector:
db COLOR_CURSOR
db 3
db 1, 1, 7, 1, 15, 15, 1, 1
db 0

ToolsList:
dw RailroadTracksHRailVector, HouseVector, FieldVector, CityVector, StationVector, FactoryVector, ForestVector, EvergreenVector, MountainVector
RailroadsList:
dw RailroadTracksHRailVector,RailroadTracksHRailVector,RailroadTracksVRailVector,RailroadTracksTurn3Vector,RailroadTracksHRailVector,RailroadTracksHRailVector,RailroadTracksTurn6Vector,RailroadTracksVRailVector,RailroadTracksVRailVector,RailroadTracksTurn9Vector,RailroadTracksVRailVector,RailroadTracksVRailVector,RailroadTracksTurn12Vector,0,0,RailroadTracksCrossVector

RailroadTracksHRailVector:
db COLOR_TRACKS
db 1
db 1, 6, 16, 6
db 1
db 1, 10, 16, 10
db 0

RailroadTracksVRailVector:
db COLOR_TRACKS
db 1
db 6, 1, 6, 16
db 1
db 10, 1, 10, 16
db 0

RailroadTracksTurn3Vector:
db COLOR_TRACKS
db 1
db 1, 6, 10, 16
db 1
db 1, 10, 6, 16
db 0

RailroadTracksTurn6Vector:
db COLOR_TRACKS
db 1
db 6, 15, 15, 5
db 1
db 10, 15, 15, 9
db 0

RailroadTracksTurn9Vector:
db COLOR_TRACKS
db 1
db 1, 5, 6, 1
db 1
db 1, 9, 10, 1
db 0

RailroadTracksTurn12Vector:
db COLOR_TRACKS
db 1
db 6, 1, 16, 10
db 1
db 10, 1, 16, 6
db 0


RailroadTracksCrossVector:
db COLOR_TRACKS
db 1
db 1, 6, 16, 6
db 1
db 1, 10, 16, 10
db 1
db 6, 1, 6, 16
db 1
db 10, 1, 10, 16
db 0

FieldVector:
db COLOR_5
db 1
db 1, 2, 15, 2
db 1
db 1, 5, 15, 5
db 1
db 1, 8, 15, 8
db 1
db 1, 11, 15, 11
db 1
db 1, 14, 15, 14
db 0

HouseVector:
db COLOR_HOUSE
db 4
db 2, 14, 2, 8, 14, 8, 14, 14, 1, 14
db 3
db 6, 14, 6, 10, 8, 10, 8, 14
db 3
db 2, 8, 4, 4, 12, 4, 14, 8
db 3
db 8, 4, 8, 2, 10, 2, 10, 4
db 0

CityVector:
db COLOR_15
db 3
db 2, 15, 2, 6, 5, 6, 5, 15
db 3
db 5, 15, 5, 2, 10, 2, 10, 15
db 3
db 10, 15, 10, 5, 15, 5, 15, 16
db 0

FactoryVector:
db COLOR_6
db 11
db 2, 15, 2, 1, 4, 1, 4, 9, 7, 7, 7, 9, 10, 7, 10, 9, 13, 7, 13, 9, 15, 15, 2, 15 
db 1
db 4, 11, 14, 11
db 0

StationVector:
db COLOR_STATION
db 6
db 3, 15, 1, 9, 5, 7, 11, 7, 15, 9, 13, 15, 3, 15
db 4
db 5, 15, 5, 7, 8, 1, 11, 7, 11, 15
db 4
db 7, 15, 7, 11, 8, 9, 9, 11, 9, 15
db 0

MountainVector:
db COLOR_MOUNTAIN
db 2
db 1, 11, 7, 3, 11, 11
db 2
db 9, 8, 12, 4, 15, 10
db 0

ForestVector:
db COLOR_TREE
db 3
db 7, 11, 7, 14, 8, 14, 8, 10
db 3
db 8, 10, 3, 12, 1, 9, 3, 7
db 5
db 4, 8, 1, 4, 4, 1, 8, 1, 9, 6, 4, 8
db 4
db 8, 3, 12, 3, 14, 9, 8, 10, 6, 7
db 0

EvergreenVector:
db COLOR_EVERGREEN
db 18
db 6,  15, 5, 13,1,15,4,11,2,12,5, 8, 3, 8,  6, 5,  4, 5,  7,  1, 9, 5,  7,  5,   10,  8,  8,  8, 11, 11, 8, 11, 12, 15, 13, 13, 6, 15
db 0

TrainVector:
db COLOR_TRAIN
db 4
db 4, 4, 12, 4, 12, 12, 4, 12, 4, 4
db 0

Notes:
dw 1          ; PAUSE
dw 1193182/261 ; C4
dw 1193182/294 ; D4
dw 1193182/330 ; E4
dw 1193182/349 ; F4
dw 1193182/392 ; G4
dw 1193182/440 ; A4
dw 1193182/494 ; B4
dw 1193182/523 ; C5
dw 1193182/587 ; D5
dw 1193182/659 ; E5
dw 1193182/698 ; F5

TitleTune:
db 2,6,10,16,10,6,2,0,0,0,6,2,0,0,0,10,16,0,6,0,4,8,12,0,0,0,6,2,0,0,0,0xFF

MapTune:
db 2,4,6,8,10,12,14,16,0,4,6,22,0,10,12,0,16,18,0,20,22,10,0,12,14,16,0,4,0,0,0,0xFF

Palette:
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

; =========================================== THE END ==========================
; Thanks for reading the source code!
; Visit http://smol.p1x.in/assembly/ for more.

Logo:
db "P1X"    ; Use HEX viewer to see P1X at the end of binary