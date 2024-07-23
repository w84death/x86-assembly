
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



game_loop:

    inc bp

    xor di,di
    xor si,si

draw_bg:
    mov ax,0x1112                 ; Set background color (2 bytes)
    mov cx, 0xFA00               ; Set buffer size to fullscreen
    rep stosw                               ; Fill the buffer with color



draw_ship:

    mov si, ShipSpr         ; source -> sprite data
    mov di, 320*96+160   ; destination -> dbuffer position
    mov dx, 0
    mov cx, 0x0C        ; lines in sprite
    call draw_sprite
    mov di, 320*96+160+15   ; destination -> dbuffer position
    inc dx
    mov cx, 0x0C        ; lines in sprite
    call draw_sprite

    mov si, BoosterSpr
    mov di, 320*100+160-12
    mov dx, 0
    mov cx, 0x08
    call draw_sprite
    mov di, 320*100+160+15-12
    inc dx
    mov cx, 0x08
    call draw_sprite

    mov si, BoosterSpr
    mov di, 320*100+160+12
    mov dx, 0
    mov cx, 0x08
    call draw_sprite
    mov di, 320*100+160+15+12
    inc dx
    mov cx, 0x08
    call draw_sprite


    mov si, Enemy1Spr
    mov di, 320*60+160
    mov dx, 0
    mov cx, 0x08
    call draw_sprite
    mov di, 320*60+160+15
    inc dx
    mov cx, 0x08
    call draw_sprite

    mov si, Enemy2Spr
    mov di, 320*60+140
    mov dx, 0
    mov cx, 0x08
    call draw_sprite
    mov di, 320*60+140+15
    inc dx
    mov cx, 0x08
    call draw_sprite

    mov si, Enemy3Spr
    mov di, 320*60+180
    mov dx, 0
    mov cx, 0x08
    call draw_sprite
    mov di, 320*60+180+15
    inc dx
    mov cx, 0x08
    call draw_sprite

    mov si, Enemy4Spr
    mov di, 320*60+200
    mov dx, 0
    mov cx, 0x08
    call draw_sprite
    mov di, 320*60+200+15
    inc dx
    mov cx, 0x08
    call draw_sprite

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
    push es
    push 0x0040
    pop es
    mov bx, [es:0x006C]  ; Load the current tick count into BX
wait_for_tick:
    mov ax, [es:0x006C]  ; Load the current tick count
    sub ax, bx           ; Calculate elapsed ticks
    jz wait_for_tick     ; If not enough time has passed, keep waiting
    pop es


; =========================================== ESC OR LOOP =====================

    in al,0x60                           ; Read keyboard
    dec al
    jnz game_loop

; =========================================== TERMINATE PROGRAM ================

    mov ax, 0x0003
    int 0x10
    ret

; =========================================== DRAW SPRITE PROCEDURE ============

draw_sprite:
    pusha
    .plot_line:
        push cx
        mov ax, [si]    ; get word line
        mov cx, 0x08    ; 8 pixels in line
        .draw_pixel:
            xor bx,bx
            shl ax,1    ; cut left bit
            adc bx,0    ; get first bit
            shl bx,1    ; mov to represent 2 or 0
            shl ax,1    ; cut left bit
            adc bx,0    ; get second bit (0,1)
            cmp bx, 0
            jz .skip_pixel
            imul bx, 0x04 ; poors man palette
            add bx, 0x12  ; grays 12,16,1a,1e

            mov [es:di], bl
            .skip_pixel:
            inc di
            cmp dx, 0
            jz .rev
            dec di
            dec di
            .rev:
            loop .draw_pixel
        inc si
        inc si
        add di, 312
        cmp dx, 0
        jz .rev2
        add di, 16
        .rev2:
    pop cx
    loop .plot_line
    popa
    ret


; =========================================== SPRITE DATA ======================

ShipSpr:
dw 0000000000001011b
dw 0000010001111110b
dw 0100100011101011b
dw 0100100110011111b
dw 1001011110100101b
dw 0101111010010110b
dw 0111101001011011b
dw 1101110101111010b
dw 1011101011011001b
dw 0110010110100101b
dw 0001101010011001b
dw 0000000001010110b
BoosterSpr:
dw 0000000000001010b
dw 0000000000101011b
dw 0000000010011010b
dw 0000000111011011b
dw 0000011110011101b
dw 0001111010100101b
dw 0001010000011001b
dw 0000000000000110b
Enemy1Spr:
dw 0000001100000010b
dw 0000000111000001b
dw 0001000010100110b
dw 1000010101110110b
dw 0011100000101001b
dw 0000000011010111b
dw 0000001000000010b
dw 0000010000000000b
Enemy2Spr:
dw 0111111101000000b
dw 0001101011110000b
dw 0000000110100010b
dw 0001010000101011b
dw 0000101110010110b
dw 0001010000011101b
dw 0000000110100110b
dw 0001101001000010b
Enemy3Spr:
dw 1011111101000001b
dw 1101010110000110b
dw 1101101010011011b
dw 0110101011011011b
dw 0001010101100110b
dw 0000100100111101b
dw 0010001001010110b
dw 0010011000001000b
Enemy4Spr:
dw 1100000000001100b
dw 0010000000001000b
dw 0000100000010101b
dw 0000000110101010b
dw 0010111001011101b
dw 1111101010100010b
dw 0110111111111111b
dw 0000000101101010b
Power1Spr:
dw 1011000000000000b
dw 1100001111111001b
dw 0000111010100111b
dw 0000101111011111b
dw 0000110101010111b
dw 0000111001010101b
dw 1100001010111011b
dw 1011000000000000b
Power2Spr:
dw 1011000000000011b
dw 1100001111100111b
dw 0000111010101101b
dw 0000101101110101b
dw 0000110101011101b
dw 0000110101010111b
dw 1100001010100111b
dw 1011000000000010b

Logo:
db "P1X"
