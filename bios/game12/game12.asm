; GAME12 - 2D Game Engine for DOS
;
; Created by Krzysztof Krystian Jankowski
; MIT License
; 01/2025
;
; Idea 1:
; - build railroads from center to any of the 4 sides
; - removing tree from map will move the train forward
; - tran can't move on mountains, infrastructure
; - if train reaches the end of railroads, game over
; - if train reaches the edge destination, game won
; - balance between removing trees and building longer railroads
;

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

; =========================================== GAME STATES ======================

STATE_INTRO equ 0
STATE_MENU equ 2
STATE_PREPARE equ 4
STATE_GAME equ 8
STATE_OVER equ 16
STATE_MAP equ 32
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

TOOLS equ 0x6
TOOL_EMPTY equ 0x40
TOOL_RAILROAD equ 0x0
TOOL_HOUSE equ 0x1
TOOL_STATION equ 0x2
TOOL_FOREST equ 0x3
TOOL_FOREST2 equ 0x4
TOOL_MOUNTAINS equ 0x5
TOOL_TRAIN equ 0x6
TOOL_POS equ 320*180+16

MAP_WIDTH equ 64
MAP_HEIGHT equ 64
VIEWPORT_POS equ 320*16+16

SCALE equ 1 ; 1 - 2 zoom level
VIEWPORT_WIDTH equ 18 / SCALE
VIEWPORT_HEIGHT equ 10 / SCALE
VIEWPORT_GRID_SCALE equ 4 + (SCALE - 1)
VIEWPORT_GRID_SIZE equ 16 * SCALE
VIEWPORT_VECTORS_SCALE equ 0 + (SCALE - 1)
VIEWPORT_TEMP equ (2 - (SCALE - 1))

COLOR_BACKGROUND equ 0xC7
COLOR_GRID equ 0xC6
COLOR_TEXT equ 0x33
COLOR_CURSOR equ 0x1E
COLOR_CURSOR_ERR equ 0x6F
COLOR_CURSOR_OK equ 0x49
COLOR_GRADIENT_START equ 0x1414
COLOR_GRADIENT_END equ 0x1010
COLOR_METAL equ 0xA3
COLOR_STEEL equ 0x67
COLOR_RAILS equ 0xD3
COLOR_GREEN equ 0x76
COLOR_EVERGREEN equ 0xC0
COLOR_MOUNTAIN equ 0xAC
COLOR_HOUSE equ 0xA0
COLOR_STATION equ 0x41
COLOR_TOOLS_SELECTOR equ 0x1e1e
COLOR_TRAIN equ 0x5C
COLOR_MAP equ 0xC4C4

NOTE_C4   equ 1193182/261
NOTE_D4   equ 1193182/294
NOTE_E4   equ 1193182/330
NOTE_F4   equ 1193182/349
NOTE_G4   equ 1193182/392
NOTE_A4   equ 1193182/440
NOTE_B4   equ 1193182/494
NOTE_C5   equ 1193182/523
NOTE_PAUSE equ 1

; =========================================== INITIALIZATION ===================

mov ax, 0x13        ; Init 320x200, 256 colors mode
int 0x10            ; Video BIOS interrupt
mov ax, 0xA000
mov es, ax
xor di, di          ; Set DI to 0

mov ax, 0x9000
mov ss, ax
mov sp, 0xFFFF

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
call init_map
mov byte [_GAME_STATE_], STATE_INTRO
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
      cmp byte [_GAME_STATE_], STATE_MAP
      jz .go_game
      cmp byte [_GAME_STATE_], STATE_GAME
      jz .go_intro
      mov byte [_GAME_STATE_], STATE_QUIT
      jmp .done
   .process_enter:
      mov dx, NOTE_C5
      call play_note
      cmp byte [_GAME_STATE_], STATE_INTRO
      jz .go_game
      cmp byte [_GAME_STATE_], STATE_GAME
      jz .go_game_enter
      jmp .done
   .process_m:
      mov dx, NOTE_C5
      call play_note
      cmp byte [_GAME_STATE_], STATE_MAP
      jz .go_game  
      mov byte [_GAME_STATE_], STATE_MAP
      mov word [_GAME_TICK_], 0x0
      call prepare_map
      jmp .done
   .process_space:
      cmp byte [_GAME_STATE_], STATE_GAME
      jz .go_game_space
      jmp .done
   .process_del:
      mov dx, NOTE_A4
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
      call draw_cursor_ok
      jmp .done
   .process_q:
      mov dx, NOTE_C5
      call play_note
      dec byte [_TOOL_]
      call verify_change_tool
      jmp .done
   .process_w:
      mov dx, NOTE_C5
      call play_note
      inc byte [_TOOL_]
      call verify_change_tool
      jmp .done
   .go_intro:
      mov byte [_GAME_STATE_], STATE_INTRO
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
      mov dx, NOTE_C4
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

      call draw_cursor_ok
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
      mov dx, NOTE_F4
      call play_note
      call move_cursor
      call draw_train
   .done:

; =========================================== GAME STATES ======================

cmp byte [_GAME_STATE_], STATE_QUIT
je exit

cmp byte [_GAME_STATE_], STATE_INTRO
je draw_intro

cmp byte [_GAME_STATE_], STATE_GAME
je draw_game

cmp byte [_GAME_STATE_], STATE_MAP
je draw_map

jmp wait_for_tick

draw_intro:
   call play_tune
   jmp wait_for_tick

draw_game:
   call train_ai
   call draw_train
   jmp wait_for_tick

draw_map:
   mov dx, 0x1010
   call draw_train_on_map
   call move_train
   mov dx, 0x1f1f
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
   ; mov dx, [_NOTE_TIMER_]
   ; cmp dx, NOTE_A4/2
   ; jl .note_ended
   ; call play_raw_note
   ; shr word [_NOTE_TIMER_], 1
   ; jmp .done
   ; .note_ended:
   call stop_note
   .done:

; =========================================== ESC OR LOOP ======================

jmp main_loop

; =========================================== EXIT TO DOS ======================

exit:
   call stop_note

   mov ax, 0x0003      ; Set video mode to 80x25 text mode
   int 0x10            ; Call BIOS interrupt
   mov si, QuitText
   xor dx,dx
   call draw_text
   
   mov ax, 0x4c00      ; Exit to DOS
   int 0x21            ; Call DOS
   ret                 ; Return to DOS
















; =========================================== PROCEDURES =======================

prepare_intro:
   xor di, di
   mov ax, COLOR_GRADIENT_START             ; Set starting color
   mov dl, 0x10              ; 10 bars to draw
   .draw_gradient:
      mov cx, 320*4          ; Each bar 10 pixels high
      rep stosw               ; Write to the VGA memory
      cmp dl, 0x04
      jg .draw_top
      jl .draw_bottom
      mov ax, COLOR_GRADIENT_END
      mov cx, 320*36
      rep stosw
      
      .draw_bottom:
      inc ax
      jmp .cont

      .draw_top:
      dec ax
      cmp ax, 0x01010
      jg .skip_zero
         xor ax, ax
      .skip_zero:

      .cont:
      xchg al, ah             ; Swap colors
      dec dl
      jnz .draw_gradient

   mov byte [_VECTOR_SCALE_], 0x1
   mov bp, 320*8+130
   mov si, P1XVector
   call draw_vector

   mov si, WelcomeText
   mov dh, 0xC
   mov dl, 0x2
   mov bl, COLOR_TEXT
   call draw_text

   mov si, TitleText
   mov dh, 0xE
   mov dl, 0x8
   inc bl
   call draw_text

   mov si, PressEnterText
   mov dh, 0x14
   mov dl, 0x6
   inc bl
   call draw_text

ret   

prepare_game:
   mov byte [_VECTOR_SCALE_], VIEWPORT_VECTORS_SCALE
   
   xor di, di
   mov al, COLOR_BACKGROUND
   mov ah, al
   mov cx, 320*200/2
   rep stosw

   call draw_grid

   mov byte [_TOOL_], 0
   mov byte [_VECTOR_SCALE_], 0
   call draw_tools
   mov byte [_VECTOR_SCALE_], VIEWPORT_VECTORS_SCALE
   mov dl, 0
   call update_tools_selector

   call load_map

   call draw_cursor_ok

   call draw_train

   mov si, HeaderText
   mov dh, 0x0
   mov dl, 0x0
   mov bl, COLOR_TEXT
   call draw_text
ret

prepare_map:
   xor si, si
   mov al, COLOR_BACKGROUND
   mov ah, al
   mov cx, 320*(200-16)
   rep stosw

   mov dl, 0x6              ; 10 bars to draw
   .draw_gradient:
      mov cx, 320*4          ; Each bar 10 pixels high
      rep stosw               ; Write to the VGA memory
      dec al
      xchg al, ah             ; Swap colors
      dec dl
      jnz .draw_gradient

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
         mov al, [si]

         test al, 0x80
         jnz .set_railroads

         and al, 0x7F

         mov bx, COLOR_MAP
         
         cmp al, TOOL_FOREST
         jz .set_green
         cmp al, TOOL_FOREST2
         jz .set_green
         cmp al, TOOL_HOUSE
         jz .set_infra
         cmp al, TOOL_STATION
         jz .set_infra
         cmp al, TOOL_MOUNTAINS
         jz .set_mountains
         jmp .push_pixel

         .set_green:
         mov bl, COLOR_GREEN
         jmp .push_pixel

         .set_infra:
         mov bl, COLOR_HOUSE
         jmp .push_pixel

         .set_mountains:
         mov bl, COLOR_MOUNTAIN
         jmp .push_pixel

         .set_railroads:
         mov bx, 0x10       

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

draw_cursor_on_map:
   mov ax, [_CUR_Y_]
   add ax, [_VIEWPORT_Y_]
   mov bx, [_CUR_X_]
   add bx, [_VIEWPORT_X_]
   mov dx, 0x0404
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
   pusha
   xor bx, bx

   test byte [si], 128
   jz .done

   test byte [si-MAP_WIDTH], 128 ; up
   jz .next1
      add bl, 8
   .next1:

   test byte [si+1], 128 ; right
   jz .next2
      add bl, 4
   .next2:

   test byte [si+MAP_WIDTH], 128 ; down
   jz .next3
      add bl, 2
   .next3:

   test byte [si-1], 128 ; left
   jz .next4
      add bl, 1
   .next4:

   cmp bl, 12
   jle .skip_clip
      mov bl, 0
   .skip_clip:

   .save_to_map:
   add bl, TOOLS  ; move over tools list
   add bl, 128    ; set railroad bit
   mov byte [si], bl

   .done:
   popa
ret

save_tile_to_map:
   call convert_xy_pos_to_map
   mov al, [_TOOL_]
   cmp al, 0
   jnz .skip_railroads_bit
      add al, 128
   .skip_railroads_bit:
   mov byte [si], al
ret

convert_xy_pos_to_map:
   push ax
   mov si, _MAP_
   imul ax, MAP_WIDTH
   add ax, bx
   add si, ax
   pop ax
ret

init_map:
   mov di, _MAP_
   mov cx, MAP_WIDTH*MAP_HEIGHT
   .init_loop:
      call get_random
      and ax, 0xf
      cmp ax, 0x7
      jl .set_empty
      cmp ax, 0x9
      jl .set_evergreen
      cmp ax, 0x9
      jz .set_mountains
      .set_forest:
         mov ax, TOOL_FOREST
         jmp .done
      .set_evergreen:
         mov ax, TOOL_FOREST2
         jmp .done
      .set_mountains:
         mov ax, TOOL_MOUNTAINS
         jmp .done
      .set_empty:
         mov ax, TOOL_EMPTY      
      .done:
      mov [di], al
      inc di
   loop .init_loop

   mov di, _MAP_
   add di, MAP_WIDTH*31+31
   mov byte [di], TOOL_RAILROAD+128
   mov word [_TRAIN_X_], 31
   mov word [_TRAIN_Y_], 31
   mov byte [_TRAIN_DIR_MASK_], 0
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
         and al, 0x7f         ; clear railroad bit
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
      add bp, 320*(VIEWPORT_GRID_SIZE-1)+VIEWPORT_GRID_SIZE*VIEWPORT_TEMP
   loop .v_loop

   pop ax
   mov byte [_TOOL_], al
ret

load_tile_from_map:
   pusha
   mov al, [si]
   and al, 0x7f         ; clear railroad bit
   cmp al, TOOL_EMPTY
   jz .done
      mov byte [_BRUSH_], al
      call stamp_tile
   .done:
   popa
ret

move_cursor:
   call erase_cursor
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
   call draw_cursor_ok
ret

draw_cursor:
   mov ax, [_CUR_Y_]
   mov bx, [_CUR_X_]
   call convert_xy_to_screen
   call draw_vector
ret

draw_cursor_ok:
   mov si, CursorVector
   call draw_cursor
ret

erase_cursor:
   mov si, CursorEraseVector
   call draw_cursor
ret
 
convert_xy_to_screen:
   push ax
   push bx
   imul ax, VIEWPORT_GRID_SIZE
   imul ax, 320
   imul bx, VIEWPORT_GRID_SIZE
   add ax, bx
   add ax, VIEWPORT_POS
   mov bp, ax   

   pop bx
   pop ax
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
   
   cmp bx, 0
   jl .do_not_draw_train
   cmp bx, VIEWPORT_WIDTH
   jge .do_not_draw_train
   cmp ax, 0
   jl .do_not_draw_train
   cmp ax, VIEWPORT_HEIGHT
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
   and al, 0x7f   ; clear railroad bit
   sub al, TOOLS  ; move over tools list
   sub al, [_TRAIN_DIR_MASK_]

   .test_up:
   test al, 8
   jz .test_right
   test byte [si-MAP_WIDTH], 128
   jz .test_right
   dec word [_TRAIN_Y_]
   mov bl, 2
   jmp .train_moved
   .test_right:
   test al, 4
   jz .test_down
   test byte [si+1], 128
   jz .test_down
   inc word [_TRAIN_X_]
   mov bl, 1
   jmp .train_moved
   .test_down:
   test al, 2
   jz .test_left
   test byte [si+MAP_WIDTH], 128
   jz .test_left
   inc word [_TRAIN_Y_]
   mov bl, 8
   jmp .train_moved
   .test_left:
   test al, 1
   jz .no_move
   test byte [si-1], 128
   jz .no_move
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
   ; xor dx,dx
   ; mov bh, 0x0
   ; mov ah, 0x02
   ; int 0x10 
   ; mov ah, 0x0E  
   ; add al, 0x30
   ; int 0x10
ret

; =========================================== DRAWING LINE ====================
; X0 - AX, Y0 - DL
; X1 - BX, Y1 - DH
; COLOR - CL
; Spektre @ https://stackoverflow.com/questions/71390507/line-drawing-algorithm-in-assembly#71391899
draw_line:
  pusha       
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
    popa
    ret
 .ct:    dw  0


play_tune:
   xor ax, ax
   mov al, [_TUNE_POS_]
   mov si, IntroTune
   add si, ax
   mov dx, [si]
   
   cmp dx, 0
   jz .restart_tune
   cmp dx, NOTE_PAUSE
   jz .pause_note

   call play_note
   .pause_note:
   add byte [_TUNE_POS_], 2
ret
   .restart_tune:
   mov byte [_TUNE_POS_], 0
ret

play_note:
   mov al, 0xB6          ; Control word: channel 2, low/high byte, mode 3
   out 0x43, al
   out 0x42, al          ; Low byte of frequency
   mov al, dh            ; High byte of frequency
   out 0x42, al
   in   al, 0x61         ; Read current speaker port
   or   al, 3            ; Set bits 0 and 1 to enable channel 2 output
   out  0x61, al
ret

stop_note:
   in   al, 0x61
   and  al, 0xFC         ; Clear bits 0 and 1
   out  0x61, al
ret


; =========================================== DATA =============================
HeaderText:                                 ;
db '-------- KKJ <<< GAME 12 >>> P1X -------', 0x0
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

ToolsList:
dw RailroadTracksHRailVector, HouseVector, StationVector, ForestVector, EvergreenVector, MountainVector
RailroadsList:
dw RailroadTracksHRailVector,RailroadTracksHRailVector,RailroadTracksVRailVector,RailroadTracksTurn3Vector,RailroadTracksHRailVector,RailroadTracksHRailVector,RailroadTracksTurn6Vector,RailroadTracksVRailVector,RailroadTracksVRailVector,RailroadTracksTurn9Vector,RailroadTracksVRailVector,RailroadTracksVRailVector,RailroadTracksTurn12Vector

RailroadTracksHRailVector:
db COLOR_RAILS
db 1
db 1, 6, 16, 6
db 1
db 1, 10, 16, 10
db 0

RailroadTracksVRailVector:
db COLOR_RAILS
db 1
db 6, 1, 6, 16
db 1
db 10, 1, 10, 16
db 0

RailroadTracksTurn3Vector:
db COLOR_RAILS
db 1
db 1, 6, 10, 16
db 1
db 1, 10, 6, 16
db 0

RailroadTracksTurn6Vector:
db COLOR_RAILS
db 1
db 6, 15, 15, 5
db 1
db 10, 15, 15, 9
db 0

RailroadTracksTurn9Vector:
db COLOR_RAILS
db 1
db 1, 5, 6, 1
db 1
db 1, 9, 10, 1
db 0

RailroadTracksTurn12Vector:
db COLOR_RAILS
db 1
db 6, 1, 16, 10
db 1
db 10, 1, 16, 6
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
db COLOR_GREEN
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
db 6,  15, 5, 13,1,15,4,11,2,12,5, 8, 3, 8,  6,   5,  4, 5,  7,  1, 9, 5,  7,  5,   10,  8,  8,  8, 11, 11, 8, 11, 12, 15, 13, 13, 6, 15
db 0

TrainVector:
db COLOR_TRAIN
db 4
db 4, 4, 12, 4, 12, 12, 4, 12, 4, 4
db 0

IntroTune:
dw NOTE_C4
dw NOTE_E4
dw NOTE_G4
dw NOTE_C5
dw NOTE_G4
dw NOTE_E4
dw NOTE_C4
dw NOTE_PAUSE
dw NOTE_PAUSE
dw NOTE_PAUSE
dw NOTE_E4
dw NOTE_C4
dw NOTE_PAUSE
dw NOTE_PAUSE
dw NOTE_PAUSE
dw NOTE_G4
dw NOTE_C5
dw NOTE_PAUSE
dw NOTE_E4
dw NOTE_PAUSE
dw NOTE_D4
dw NOTE_F4
dw NOTE_A4
dw NOTE_PAUSE
dw NOTE_PAUSE
dw NOTE_PAUSE
dw NOTE_E4
dw NOTE_C4
dw NOTE_PAUSE
dw NOTE_PAUSE
dw NOTE_PAUSE
dw 0x0

; =========================================== THE END ==========================
; Thanks for reading the source code!
; Visit http://smol.p1x.in for more.

Logo:
db "P1X"    ; Use HEX viewer to see P1X at the end of binary

