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
_VECTOR_COLOR_ equ _BASE_ + 0x08    ; 1 byte

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

; =========================================== INITIALIZATION ===================

mov ax, 0x13        ; Init 320x200, 256 colors mode
int 0x10            ; Video BIOS interrupt
mov ax, 0xA000
mov es, ax
xor di, di          ; Set DI to 0

mov byte [_GAME_TICK_], 0
mov byte [_SCORE_], 0
mov byte [_GAME_STATE_], STATE_INTRO
call prepare_intro

; =========================================== GAME LOOP ========================

game_loop:

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
      jmp .done
   .go_intro:
      mov byte [_GAME_STATE_], STATE_INTRO
      call prepare_intro
      jmp .done
   .go_game:
      mov byte [_GAME_STATE_], STATE_GAME
      call prepare_game
      jmp .done
   .pressed_up:
      dec word [_CUR_Y_]
      jmp .done
   .pressed_down:
      inc word [_CUR_Y_]
      jmp .done
   .pressed_left:
      dec word [_CUR_X_]
      jmp .done
   .pressed_right:
      inc word [_CUR_X_]
      jmp .done

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
   jmp wait_for_tick

draw_game:
   call draw_cursor
   
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

jmp game_loop

; =========================================== EXIT TO DOS ======================

exit:
   mov ax, 0x4c00      ; Exit to DOS
   int 0x21            ; Call DOS
   ret                 ; Return to DOS
















; =========================================== PROCEDURES =======================

prepare_intro:
   xor di, di
   mov ax, 0x9c9c             ; Set starting color
   mov dl, 0x0a               ; 10 bars to draw
   .draw_gradient:
      mov cx, 320*10          ; Each bar 10 pixels high
      rep stosw               ; Write to the VGA memory
      inc ax                  ; Increment color index for next bar
      xchg al, ah             ; Swap colors
      dec dl
      jnz .draw_gradient
      
   mov ax, 20
   mov bx, 300
   mov dl, 80
   mov dh, 80
   mov cl, 0x14
   call draw_line
   add dl, 40
   add dh, 40
   call draw_line

   mov byte [_VECTOR_COLOR_], 0xf
   mov bp, 320*81+150
   mov si, P1XVector
   call draw_vector
ret

prepare_game:
   xor di, di
   mov ax, 0x1414
   mov cx, 320*200/2
   rep stosw
   mov word [_CUR_X_], 160
   mov word [_CUR_Y_], 100
ret

draw_cursor:
   mov ax, [_CUR_Y_]
   imul ax, 320
   add ax, [_CUR_X_]
   mov di, ax

   mov al, 0xf
   stosb
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