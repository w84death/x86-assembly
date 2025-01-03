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


_VGA_MEMORY_ equ 0xA000             ; 64k bytes
_TICK_ equ 1Ah                      ; BIOS tick

_BASE_ equ 0x2000
_GAME_TICK_ equ _BASE_ + 0x00       ; 2 bytes
_GAME_STATE_ equ _BASE_ + 0x02      ; 1 byte
_SCORE_ equ _BASE_ + 0x03           ; 1 byte
_X_  equ _BASE_ + 0x04            ; 2 bytes
_Y_  equ _BASE_ + 0x06            ; 2 bytes

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

mov ax, _VGA_MEMORY_
mov es, ax

mov ax, _VGA_MEMORY_
mov es, ax

; push cs             
; pop ss              ; Set stack segment to the same as code segment
mov sp, 0xFFFE      ; Stack grows downward from near the top of memory
xor di, di          ; Set DI to 0
xor si, si          ; Set SI to 0

; =========================================== GAME LOOP ========================

mov word [_X_], 160
mov word [_Y_], 100

draw_bg:
  mov ax, 0x9c9c               ; Set starting sky color
  mov dl, 0x0a                  ; 10 bars to draw
  .draw_gradient:
    mov cx, 320*10           ; 2 pixels high
    rep stosw               ; Write to the VGA memory
    inc ax                  ; Increment color index for next bar
    xchg al, ah             ; Swap colors
    dec dl
    jnz .draw_gradient

mov byte [_GAME_STATE_], STATE_GAME

game_loop:

; =========================================== GAME STATES ======================
cmp byte [_GAME_STATE_], STATE_QUIT
je exit

cmp byte [_GAME_STATE_], STATE_GAME
je the_game



; =========================================== GAME LOGIC =======================

the_game:

; =========================================== KEYBOARD INPUT ===================

check_keyboard:
   mov ah, 01h         ; BIOS keyboard status function
   int 16h             ; Call BIOS interrupt
   jz .done           ; Jump if Zero Flag is set (no key pressed)

   mov ah, 00h         ; BIOS keyboard read function
   int 16h             ; Call BIOS interrupt

   cmp ah, KB_ESC
   jne .check_arrows
   mov byte [_GAME_STATE_], STATE_QUIT
   jmp .done

   .check_arrows:
   cmp ah, KB_UP
   je .pressed_up
   cmp ah, KB_DOWN
   je .pressed_down
   cmp ah, KB_LEFT
   je .pressed_left
   cmp ah, KB_RIGHT
   je .pressed_right

   .pressed_up:
      dec word [_Y_]
      jmp .done
   .pressed_down:
      inc word [_Y_]
      jmp .done
   .pressed_left:
      dec word [_X_]
      jmp .done
   .pressed_right:
      inc word [_X_]
      jmp .done

   .done:


; =========================================== DRAWING ==========================    


mov ax, [_Y_]
imul ax, 320
add ax, [_X_]
mov di, ax

mov al, 0xf
stosb


; =========================================== GAME TICK ========================

wait_for_tick:
   xor ax, ax          ; Function 00h: Read system timer counter
   int _TICK_          ; Returns tick count in CX:DX
   mov bx, dx          ; Store the current tick count
   .wait_loop:
      int _TICK_          ; Read the tick count again
      cmp dx, bx
      je .wait_loop       ; Loop until the tick count changes

inc word [_GAME_TICK_]  ; Increment game tick

; =========================================== ESC OR LOOP ======================

jmp game_loop

; =========================================== EXIT TO DOS ======================

exit:
   mov ax, 0x4c00      ; Exit to DOS
   int 0x21            ; Call DOS
   ret                 ; Return to DOS
















; =========================================== PROCEDURES =======================

; =========================================== DRAWING LINE ====================
; ax=x0
; bx=x1
; dl=y0,
; dh=y1,
; cl=col
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
