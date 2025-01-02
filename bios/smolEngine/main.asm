; smolEngine - 2D Game Engine for DOS
;
; Created by Krzysztof Krystian Jankowski
; MIT License
; 01/2025
;


org 0x100
use16


_DBUFFER_MEMORY_ equ 0x3000         ; 64k bytes
_VGA_MEMORY_ equ 0xA000             ; 64k bytes
_TICK_ equ 1Ah                      ; BIOS tick

_BASE_ equ 0x2000
_GAME_TICK_ equ _BASE_ + 0x00       ; 2 bytes
_GAME_STATE_ equ _BASE_ + 0x02      ; 1 byte
_SCORE_ equ _BASE_ + 0x03           ; 1 byte
_LIFE_ equ _BASE_ + 0x04            ; 1 byte
_LIFE_MAX_ equ _BASE_ + 0x05        ; 1 byte
_POS_  equ _BASE_ + 0x06            ; 2 bytes
_DIR_ equ _BASE_ + 0x08            ; 1 byte

; =========================================== GAME STATES ======================

STATE_INTRO equ 0
STATE_MENU equ 2
STATE_PREPARE equ 4
STATE_GAME equ 8
STATE_OVER equ 16
; 32
; 64
; 128
STATE_QUIT equ 256

; =========================================== INITIALIZATION ===================

mov ax, 0x13        ; Init 320x200, 256 colors mode
int 0x10            ; Video BIOS interrupt

;push cs             
;pop ss              ; Set stack segment to the same as code segment
;mov sp, 0xFFFE      ; Stack grows downward from near the top of memory

push _DBUFFER_MEMORY_
pop es              ; Set ES to the double buffer memory
xor di, di          ; Set DI to 0

; =========================================== GAME LOOP ========================

mov word [_POS_], 320*100+160
mov word [_DIR_], 0

game_loop:



; =========================================== KEYBOARD INPUT ==================

check_keyboard:
mov ah, 01h         ; BIOS keyboard status function
int 16h             ; Call BIOS interrupt
jz .no_key_press           ; Jump if Zero Flag is set (no key pressed)

mov ah, 00h         ; BIOS keyboard read function
int 16h             ; Call BIOS interrupt

xor cx, cx

.check_up:
cmp ah, 48h         ; Compare scan code with up arrow
jne .check_down
mov cx, -320
jmp .check_move

.check_down:
cmp ah, 50h         ; Compare scan code with down arrow
jne .check_left
mov cx, 320
jmp .check_move

.check_left:
cmp ah, 4Bh         ; Compare scan code with left arrow
jne .check_right
mov cx, -1
jmp .check_move


.check_right:
cmp ah, 4Dh         ; Compare scan code with right arrow
jne .no_key_press
mov cx, 1
;jmp .check_move

.check_move:
mov [_DIR_], cx

.no_key_press:

mov word ax, [_DIR_]
add word [_POS_], ax   
mov word di, [_POS_]


mov al, 0x0f            ; White color
mov byte [es:di], al    ; Draw a pixel







; =========================================== VGA BLIT PROCEDURE ===============

vga_blit:
    push es
    push ds

    push _VGA_MEMORY_           ; Set VGA memory
    pop es                      ; as target
    push _DBUFFER_MEMORY_       ; Set doublebuffer memory
    pop ds                      ; as source
    xor si,si                   ; Clear SI
    xor di,di                   ; Clear DI
    
    mov cx,0x7D00               ; Half of 320x200 pixels
    rep movsw                   ; Push words (2x pixels)

    pop ds
    pop es

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

in al, 0x60         ; Read keyboard
dec al              ; Decrement AL (esc is 1, after decrement is 0)
jnz game_loop       ; If not zero, loop again

; =========================================== EXIT TO DOS ======================

mov ax, 0x4c00      ; Exit to DOS
int 0x21            ; Call DOS
ret                 ; Return to DOS
















; =========================================== PROCEDURES =======================

; draw_gradient_background
; draw_glyph
; draw_text
; draw_sprite
; draw_line
; draw_hline
; draw_vline
