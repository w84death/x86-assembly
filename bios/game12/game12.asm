; GAME12 - 2D Game Engine for DOS
;
; Created by Krzysztof Krystian Jankowski
; MIT License
; 01/2025
;

; TODO:
; - extracting sprite data to memory
; - extracting level data to memory
; - drawing sprite
; - drawing level

org 0x100
use16

_BASE_ equ 0x2000
_GAME_TICK_ equ _BASE_ + 0x00       ; 2 bytes
_GAME_STATE_ equ _BASE_ + 0x02      ; 1 byte
_SCORE_ equ _BASE_ + 0x03           ; 1 byte
_CUR_X_  equ _BASE_ + 0x04          ; 2 bytes
_CUR_Y_  equ _BASE_ + 0x06          ; 2 bytes
_CUR_NEWX_  equ _BASE_ + 0x08       ; 2 bytes
_CUR_NEWY_  equ _BASE_ + 0x0A       ; 2 bytes
_VECTOR_COLOR_ equ _BASE_ + 0x0C    ; 1 byte

_SPRITES_ equ 0x3000
_LEVEL_ equ 0x4000

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

COLOR_BACKGROUND equ 0x14
COLOR_CURSOR equ 0x0f
COLOR_CURSOR_RED equ 0x04

; =========================================== INITIALIZATION ===================

mov ax, 0x13        ; Init 320x200, 256 colors mode
int 0x10            ; Video BIOS interrupt
mov ax, 0xA000
mov es, ax
xor di, di          ; Set DI to 0

mov byte [_GAME_TICK_], 0
mov byte [_GAME_STATE_], STATE_INTRO
call prepare_intro

; =========================================== GAME LOOP ========================

main_loop:

; =========================================== KEYBOARD INPUT ===================

check_keyboard:
   mov ah, 01h         ; BIOS keyboard status function
   int 16h             ; Call BIOS interrupt
   jz .done             ; Jump if Zero Flag is set (no key pressed)

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
      ; todo
      jmp .done
   .go_intro:
      mov byte [_GAME_STATE_], STATE_INTRO
      call prepare_intro
      jmp .done
   .go_game:
      mov byte [_GAME_STATE_], STATE_GAME
      call prepare_game
      jmp .done
   .go_game_enter:
      ; todo
      jmp .done
   .pressed_up:
      dec word [_CUR_NEWY_]
      jmp .done_processed
   .pressed_down:
      inc word [_CUR_NEWY_]
      jmp .done_processed
   .pressed_left:
      dec word [_CUR_NEWX_]
      jmp .done_processed
   .pressed_right:
      inc word [_CUR_NEWX_]
      jmp .done_processed
   .done_processed:
      call move_cursor
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
   ; animate "PRESS ENTER TO START"

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
   ; todo
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
   mov ax, 0x1414             ; Set starting color
   mov dl, 0x10               ; 10 bars to draw
   .draw_gradient:
      mov cx, 320*4          ; Each bar 10 pixels high
      rep stosw               ; Write to the VGA memory
      cmp dl, 0x09
      jg .draw_top
      jl .draw_bottom
      mov ax, 0x1010
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

   mov byte [_VECTOR_COLOR_], 0x10
   mov bp, 320*80+150
   mov si, P1XVector
   call draw_vector
ret

prepare_game:
   xor di, di
   mov al, COLOR_BACKGROUND
   mov ah, al
   mov cx, 320*200/2
   rep stosw
   mov word [_CUR_X_], 9
   mov word [_CUR_Y_], 5
   mov word [_CUR_NEWX_], 9
   mov word [_CUR_NEWY_], 5
   mov byte [_SCORE_], 0
   mov cl, COLOR_CURSOR
   call draw_cursor
ret

move_cursor:
   mov cl, COLOR_BACKGROUND
   call draw_cursor
   mov cl, COLOR_CURSOR
   mov ax, [_CUR_NEWX_]
   cmp ax, 0
   jl .err
   cmp ax, 320/16-1
   jge .err
   mov [_CUR_X_], ax
   ; jmp .done

   mov ax, [_CUR_NEWY_]
   cmp ax, 0
   jl .err
   cmp ax, 200/16-1
   jge .err
   mov [_CUR_Y_], ax
   jmp .done
   .err:
      mov cl, COLOR_CURSOR_RED
      mov ax, [_CUR_X_]
      mov [_CUR_NEWX_], ax
      mov ax, [_CUR_Y_]
      mov [_CUR_NEWY_], ax
   .done:
   call draw_cursor
ret

draw_cursor:
   mov ax, [_CUR_Y_]
   shl ax, 4
   imul ax, 320
   mov bx, [_CUR_X_]
   shl bx, 4
   add ax, bx
   add ax, 320*8+8
   mov bp, ax   
   mov byte [_VECTOR_COLOR_], cl
   mov si, TestVector
   call draw_vector
ret

; =========================================== DRAW VECTOR ======================
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

    xor ax, ax
    mov al, [si]
    add ax, bp
    
    xor bx, bx
    mov bl, [si+2]
    add bx, bp          ; Move to position
    mov dl, [si+1]
    mov dh, [si+3]        
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

; =========================================== DRAWING LINE ====================
; X0 - AX, Y0 - DL
; X1 - BX, Y1 - DH
; COLOR - CL
; Spektre @ https://stackoverflow.com/questions/71390507/line-drawing-algorithm-in-assembly#71391899
draw_line:
  pusha       
    push    ax
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
 .l0:    mov word [es:bp], cx
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
db 2, 35, 2, 3, 10, 3, 10, 20, 2, 20
db 1
db 11, 4, 14, 4
db 1
db 14, 35, 14, 2
db 3
db 18, 35, 18, 19, 24, 11, 24, 2
db 3
db 24, 35, 24, 19, 18, 11, 18, 2
db 0

TestVector:
db 4
db 0, 0, 16, 0, 16, 16, 0, 16, 0, 0
db 0