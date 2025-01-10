; GAME12 - 2D Game Engine for DOS
;
; Created by Krzysztof Krystian Jankowski
; MIT License
; 01/2025
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

_TRAINS_ equ 0x2000                 ; Trains aka entities
_MAP_ equ 0x3000                    ; Map data 64x64

; =========================================== GAME STATES ======================

STATE_INTRO equ 0
STATE_MENU equ 2
STATE_PREPARE equ 4
STATE_GAME equ 8
STATE_OVER equ 16
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

TOOLS equ 0x4
TOOL_EMPTY equ 0x40
TOOL_RAILROAD equ 0x0
TOOL_INFRA equ 0x1
TOOL_FOREST equ 0x2
TOOL_MOUNTAINS equ 0x3
TOOL_TRAIN equ 0x4

MAP_WIDTH equ 64
MAP_HEIGHT equ 64
VIEWPORT_WIDTH equ 18
VIEWPORT_HEIGHT equ 10

COLOR_BACKGROUND equ 0xC7
COLOR_GRID equ 0xC6
COLOR_TEXT equ 0x4E
COLOR_CURSOR equ 0x1E
COLOR_CURSOR_ERR equ 0x6F
COLOR_CURSOR_OK equ 0x49
COLOR_GRADIENT_START equ 0x1414
COLOR_GRADIENT_END equ 0x1010
COLOR_METAL equ 0xA3
COLOR_STEEL equ 0x67
COLOR_RAILS equ 0xD3
COLOR_GREEN equ 0x74
COLOR_MOUNTAIN equ 0xAD
COLOR_INFRA equ 0xA0
COLOR_TOOLS_SELECTOR equ 0x1e1e
COLOR_TRAIN equ 0x1F

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
mov word [_VIEWPORT_X_], 20
mov word [_VIEWPORT_Y_], 27
mov byte [_TOOL_], 0x0
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
      cmp byte [_GAME_STATE_], STATE_GAME
      jz .go_intro
      mov byte [_GAME_STATE_], STATE_QUIT
      jmp .done
   .process_enter:
      cmp byte [_GAME_STATE_], STATE_INTRO
      jz .go_game
      cmp byte [_GAME_STATE_], STATE_GAME
      jz .go_game_enter
      jmp .done
   .process_space:
      cmp byte [_GAME_STATE_], STATE_GAME
      jz .go_game_space
      jmp .done
   .process_del:
      call get_cursor_pos
      mov al, [_TOOL_]
      push ax
      mov byte [_TOOL_], TOOL_EMPTY
      call save_tile
      pop ax
      mov byte [_TOOL_], al
      call clear_tile
      mov cl, COLOR_CURSOR_OK
      call draw_cursor
      jmp .done
   .process_q:
      dec byte [_TOOL_]
      call verify_change_tool
      jmp .done
   .process_w:
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
      call get_cursor_pos
      call save_tile
      call clear_tile

      cmp byte [_TOOL_], 0
      jz .recalculate_railroads
      
      mov al, [_TOOL_]
      mov byte [_BRUSH_], al
      call stamp_tile  
      jmp .skip_recalculate

      .recalculate_railroads:
      call recalculate_railroads
      call load_tile
      .skip_recalculate:

      mov cl, COLOR_CURSOR_OK
      call draw_cursor
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

jmp wait_for_tick

draw_intro:
   mov ax, [_GAME_TICK_]
   test ax, 0x10
   jnz .done

   mov al, [_VECTOR_COLOR_]
   cmp al, 0x1f
   jge .done
   inc al

   mov byte [_VECTOR_COLOR_], al
   call draw_vector
   .done:
   jmp wait_for_tick

draw_game:
   
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

; =========================================== ESC OR LOOP ======================

jmp main_loop

; =========================================== EXIT TO DOS ======================

exit:
   mov ax, 0x4c00      ; Exit to DOS
   int 0x21            ; Call DOS
   ret                 ; Return to DOS
















; =========================================== PROCEDURES =======================

prepare_intro:
   xor di, di
   mov ax, COLOR_GRADIENT_START             ; Set starting color
   mov dl, 0x10               ; 10 bars to draw
   .draw_gradient:
      mov cx, 320*4          ; Each bar 10 pixels high
      rep stosw               ; Write to the VGA memory
      cmp dl, 0x09
      jg .draw_top
      jl .draw_bottom
      mov ax, COLOR_GRADIENT_END
      mov cx, 320*36
      rep stosw
      .draw_bottom:
      inc ax
      jmp .cont
      .draw_top:
      dec ax                  ; Increment color index for next bar
      .cont:
      xchg al, ah             ; Swap colors
      dec dl
      jnz .draw_gradient

   mov byte [_VECTOR_COLOR_], COLOR_TEXT
   mov bp, 320*170+85
   mov si, PressEnterVector
   call draw_vector

   mov byte [_VECTOR_SCALE_], 0x2
   mov byte [_VECTOR_COLOR_], 0x10
   mov bp, 320*20+110
   mov si, P1XVector
   call draw_vector
ret

prepare_game:
   mov byte [_VECTOR_SCALE_], 0

   xor di, di
   mov al, COLOR_BACKGROUND
   mov ah, al
   mov cx, 320*200/2
   rep stosw

   call draw_grid
   mov byte [_TOOL_], 0
   call draw_tools

   call load_map

   mov word [_CUR_X_], 9
   mov word [_CUR_Y_], 5
   mov word [_CUR_TEST_X_], 9
   mov word [_CUR_TEST_Y_], 5

   mov cl, COLOR_CURSOR
   call draw_cursor

   call draw_train
ret

draw_grid:
   pusha
   mov di, 320*8+8
   push di    
   mov al, COLOR_GRID
   mov ah, al
   .draw_horizontal_lines:
      mov cx, VIEWPORT_HEIGHT+1
      .h_line_loop:
         push cx
         mov cx, VIEWPORT_WIDTH*16/2
         rep stosw
         pop cx
         add di, 320*16-VIEWPORT_WIDTH*16
      loop .h_line_loop
   .draw_vertical_lines:
      pop di
      mov cx, VIEWPORT_WIDTH+1
      .v_line_loop:
         push cx
         mov cx, VIEWPORT_HEIGHT*16
         .draw_v:
            stosb
            inc di
            add di, 318
         loop .draw_v
         pop cx
         add di, 320*45-48
      loop .v_line_loop
   popa
ret

draw_tools:
   mov bp, 320*177+16
   mov byte [_BRUSH_], 0
   mov cx, TOOLS
   .tools_loop:
      push cx
      call stamp_tile
      inc byte [_BRUSH_]
      add bp, 24
      pop cx
   loop .tools_loop
   call update_tools_selector
ret

get_cursor_pos:
   mov ax, [_CUR_Y_]
   shl ax, 4
   imul ax, 320
   mov bx, [_CUR_X_]
   shl bx, 4
   add ax, bx
   add ax, 320*8+8
   mov bp, ax
ret

clear_tile:
   pusha
   mov di, bp
   add di, 321
   mov ax, COLOR_BACKGROUND
   mov ah, al
   mov cx, 15
   .v_line_loop:
      push cx
      mov cx, 15
      rep stosb
      pop cx
      add di, 320-15
   loop .v_line_loop
   popa
ret

stamp_tile:
   pusha
   
   xor bx, bx
   mov byte bl, [_BRUSH_]

   mov byte [_VECTOR_COLOR_], COLOR_RAILS

   cmp bl, TOOLS-3
   jl .skip2
      rdtsc
      and ax, 0x3
      mov byte [_VECTOR_COLOR_], COLOR_INFRA
      add byte [_VECTOR_COLOR_], al
   .skip2:

   cmp bl, TOOLS-2
   jl .skip3
      rdtsc
      and ax, 0x7
      mov byte [_VECTOR_COLOR_], COLOR_GREEN
      add byte [_VECTOR_COLOR_], al
   .skip3:

   cmp bl, TOOLS-1
   jl .skip4
      mov byte [_VECTOR_COLOR_], COLOR_MOUNTAIN
   .skip4:
   
   shl bx, 1
   mov si, ToolsList   
   add si, bx
   lodsw
   mov si, ax
   
   call draw_vector

   .done:
   popa
ret

recalculate_railroads:
   pusha
   call get_map_pos
   xor bx, bx

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

   add bl, TOOLS  ; move over tools list
   add bl, 128   ; set railroad bit
   mov byte [si], bl
   popa
ret

save_tile:
   call get_map_pos
   mov al, [_TOOL_]
   cmp al, 0
   jnz .skip_railroads_bit
      add al, 128
   .skip_railroads_bit:
   mov byte [si], al
ret

get_map_pos:
   mov si, _MAP_
   mov ax, [_CUR_Y_]
   add ax, [_VIEWPORT_Y_]
   imul ax, MAP_WIDTH
   add ax, [_CUR_X_]
   add ax, [_VIEWPORT_X_]
   add si, ax
ret

init_map:
   mov di, _MAP_
   mov cx, MAP_WIDTH*MAP_HEIGHT
   .init_loop:
      call get_random
      and ax, 0xf
      cmp ax, 0x7
      jl .set_empty
      cmp ax, 0x7
      jz .set_mountains
      .set_forest:
         mov ax, TOOL_FOREST
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

   ; insert railroads and train
   mov di, _MAP_
   add di, MAP_WIDTH*31+31
   mov byte [di], TOOL_RAILROAD+128
   mov word [_TRAIN_X_], 31
   mov word [_TRAIN_Y_], 31
ret

load_map:
   xor ax, ax
   mov al, [_TOOL_]
   push ax
   mov si, _MAP_
   mov bp, 320*8+8

   mov ax, [_VIEWPORT_Y_]
   imul ax, MAP_WIDTH
   add ax, [_VIEWPORT_X_]
   add si, ax

   mov cx, VIEWPORT_HEIGHT
   .v_loop:
      push cx

      mov cx, VIEWPORT_WIDTH
      .h_line_loop:
         call clear_tile
         mov al, [si]
         and al, 0x7f         ; clear railroad bit
         cmp al, TOOL_EMPTY
         jz .done
         mov byte [_BRUSH_], al
         call stamp_tile
         .done:
         add bp, 16
         inc si
      loop .h_line_loop
      add si, MAP_WIDTH-VIEWPORT_WIDTH
      pop cx
      add bp, 320*15+32
   loop .v_loop

   pop ax
   mov byte [_TOOL_], al
ret

load_tile:
   pusha
   call get_map_pos
   mov al, [si]
   and al, 0x7f         ; clear railroad bit
   mov byte [_BRUSH_], al
   call stamp_tile
   popa
ret

move_cursor:
   mov cl, COLOR_GRID
   call draw_cursor
   mov cl, COLOR_CURSOR
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
      je .err
      dec word [_VIEWPORT_Y_]
      jmp .done_end
   .bottom_end:
      cmp word [_VIEWPORT_Y_], MAP_HEIGHT-VIEWPORT_HEIGHT-1
      je .err
      inc word [_VIEWPORT_Y_]
      jmp .done_end
   .left_end:
      cmp word [_VIEWPORT_X_], 0
      je .err
      dec word [_VIEWPORT_X_]
      jmp .done_end
   .right_end:
      cmp word [_VIEWPORT_X_], MAP_WIDTH-VIEWPORT_WIDTH-1
      je .err
      inc word [_VIEWPORT_X_]
      jmp .done_end
   .err:
      mov cl, COLOR_CURSOR_ERR
      mov ax, [_CUR_X_]
      mov [_CUR_TEST_X_], ax
      mov ax, [_CUR_Y_]
      mov [_CUR_TEST_Y_], ax
      jmp .done
   .done_end:
      mov ax, [_CUR_X_]
      mov [_CUR_TEST_X_], ax
      mov ax, [_CUR_Y_]
      mov [_CUR_TEST_Y_], ax
      call load_map 
      mov cl, COLOR_CURSOR  
   .done:
   call draw_cursor
ret

draw_cursor:
   mov ax, [_CUR_Y_]
   mov bx, [_CUR_X_]
   mov byte [_VECTOR_COLOR_], cl
   mov si, CursorVector
   call pos2bp
   call draw_vector
ret
 
pos2bp:
   shl ax, 4
   imul ax, 320
   shl bx, 4
   add ax, bx
   add ax, 320*8+8
   mov bp, ax   
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
   mov di, 320*195+16
   mov cx, 180
   mov ax, COLOR_BACKGROUND
   mov ah, al
   rep stosw

   mov di, 320*195+16
   xor bx, bx
   mov bl, dl
   imul bx, 24
   add di, bx
   mov cx, 8
   mov ax, COLOR_TOOLS_SELECTOR
   rep stosw
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

   call pos2bp

   mov byte [_VECTOR_COLOR_], COLOR_TRAIN
   mov si, TrainVector
   call draw_vector

   .do_not_draw_train:
ret

; =========================================== DRAW VECTOR ======================
; SI - Vector data
; BP - Position in VGA memory

draw_vector:   
   pusha 
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


; =========================================== DATA =============================

P1XVector:
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

PressEnterVector:
db 6
db 3, 16, 15, 4, 20, 4, 21, 6, 18, 9, 15, 10, 10, 10
db 5
db 17, 16, 26, 4, 31, 4, 32, 7, 28, 10, 23, 10
db 1
db 27, 10, 28, 16
db 3
db 46, 4, 39, 4, 32, 15, 40, 16
db 1
db 37, 8, 43, 9
db 7
db 58, 4, 53, 4, 49, 8, 51, 10, 55, 10, 55, 14, 51, 16, 45, 15
db 7
db 70, 4, 64, 4, 62, 7, 64, 9, 68, 11, 68, 15, 63, 17, 59, 15
db 3
db 88, 4, 81, 4, 80, 16, 88, 16
db 1
db 82, 9, 87, 9
db 3
db 93, 16, 93, 4, 102, 15, 102, 4
db 1
db 106, 4, 115, 4
db 1
db 111, 4, 114, 17
db 3
db 126, 4, 119, 4, 122, 16, 130, 16
db 1
db 121, 9, 128, 9
db 5
db 136, 16, 130, 4, 135, 4, 137, 4, 139, 10, 134, 10
db 1
db 138, 10, 146, 16
db 0

CursorVector:
db 4
db 0, 0, 16, 0, 16, 16, 0, 16, 0, 0
db 0

ToolsList:
dw RailroadTracksHRailVector, Infra1Vector, ForestVector, MountainVector
RailroadsList:
dw RailroadTracksHRailVector,RailroadTracksHRailVector,RailroadTracksVRailVector,RailroadTracksTurn3Vector,RailroadTracksHRailVector,RailroadTracksHRailVector,RailroadTracksTurn6Vector,RailroadTracksVRailVector,RailroadTracksVRailVector,RailroadTracksTurn9Vector,RailroadTracksVRailVector,RailroadTracksVRailVector,RailroadTracksTurn12Vector

RailroadTracksHRailVector:
db 1
db 1, 6, 16, 6
db 1
db 1, 10, 16, 10
db 0

RailroadTracksVRailVector:
db 1
db 6, 1, 6, 16
db 1
db 10, 1, 10, 16
db 0

RailroadTracksTurn3Vector:
db 1
db 1, 5, 10, 16
db 1
db 1, 9, 6, 16
db 0

RailroadTracksTurn6Vector:
db 1
db 6, 16, 16, 5
db 1
db 10, 16, 16, 9
db 0

RailroadTracksTurn9Vector:
db 1
db 1, 6, 7, 1
db 1
db 1, 10, 11, 1
db 0

RailroadTracksTurn12Vector:
db 1
db 6, 1, 16, 9
db 1
db 10, 1, 16, 5
db 0

Infra1Vector:
db 4
db 3, 3, 13, 3, 13, 13, 3, 13, 3, 3
db 1
db 3, 3, 13, 13
db 1
db 13, 3, 3, 13
db 0

Infra2Vector:
db 0

MountainVector:
db 2
db 1, 11, 7, 3, 11, 11
db 2
db 9, 8, 12, 4, 15, 10
db 0

ForestVector:
db 8
db 7, 15, 7, 12, 12, 9, 12, 6, 9, 4, 5, 4, 3, 7, 5, 10, 7, 11
db 0

TrainVector:
db 4
db 4, 4, 12, 4, 12, 12, 4, 12, 4, 4
db 0