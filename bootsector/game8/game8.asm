org 0x100
use16

VGA_MEMORY_ADR equ 0xA000                   ; VGA memory address
DBUFFER_MEMORY_ADR equ 0x8000               ; Doublebuffer memory address
SCREEN_BUFFER_SIZE equ 0xFa00               ; Size of the VGA buffer size


start:
    mov ax,0x13                             ; Init VGA 320x200x256
    int 0x10                                ; Video BIOS interrupt

    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop es                                  ; as target


mov cx,SCREEN_BUFFER_SIZE/2
mov ax, 0x2b2c
rep stosw

field:
    mov di, 128
    mov ax, 0x5c5c
    mov cx, 200
    .loop:
        push cx
        mov cx, 32
        rep stosw
        pop cx
        add di, 320-64
        loop .loop

read_level:
    mov di, 320*8+128
    mov si, level_blueprints
    mov cx, 0x18
    .line:
    push cx
    push si
    rdtsc
    and ax,0x05
    add si, ax
    mov byte bl, [si]
    rdtsc
    and ax, 0x0f
    mov cl,al
    rol bx,cl
    mov cx, 0x8
    .draw_blueprint:
        shl bl,1                        ; Shift left to get the pixel out
        jnc .skip_block                 ; If carry flag is 0,skip
            mov al,0x2a
            push cx
            mov cx,0x8
            rep stosb
            pop cx
            loop .draw_blueprint
        .skip_block:
            add di,8
            loop .draw_blueprint

      add di, 320*8-64
      pop si
      pop cx
      loop .line


game_loop:


shifter:
;    mov cx, 199
;    mov si, 320*198
;    mov di, 320*199
;    .l:
;    push cx
;    mov cx, 160
;    rep movsw
;    pop cx

; sub si, 320
; sub di, 320
; loop .l

; =========================================== VGA BLIT PROCEDURE ===============

vga_blit:
    push es
    push ds

    push VGA_MEMORY_ADR                     ; Set VGA memory
    pop es                                  ; as target
    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop ds                                  ; as source
    mov cx,0x7D00                           ; Half of 320x200 pixels
    xor si,si                               ; Clear SI
    xor di,di                               ; Clear DI
    rep movsw                               ; Push words (2x pixels)

    pop ds
    pop es

; =========================================== DELAY CYCLE ======================

delay:
    mov dx, 0x3da
    .wait:
    in al, dx
    test al, 0x8
    jz .wait

; =========================================== ESC OR LOOP =====================

    in al,0x60                           ; Read keyboard
    dec al
    jnz game_loop

; =========================================== TERMINATE PROGRAM ================

    mov ax, 0x0003
    int 0x10
    ret


level_blueprints:
db 00000000b
db 10000000b
db 10001000b
db 11001100b
db 11110000b
db 01111110b


db "P1X"
