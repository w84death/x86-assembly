; GAME8 - UNNAMED
; DOS VERSION
;
; Description:
;   Some shootemup
;
;
; Author: Krzysztof Krystian Jankowski
; Date: 2024-07/23
; License: MIT

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

    xor di,di                   ; Clear destination address
    xor si,si                   ; Clear source address

draw_bg:
    mov ax,0x1112               ; Set background color (2 bytes)
    mov cx,SCREEN_BUFFER_SIZE   ; Set buffer size to fullscreen
    rep stosw                   ; Fill the buffer with color


draw_sprites:
    xor ax,ax
    mov si, BoosterSpr
    mov di, 320*102+160-10
    call draw_msprite

    mov si, BoosterSpr
    mov di, 320*102+160+10
    call draw_msprite

    mov si, ShipSpr
    mov di, 320*96+160
    mov ax, 0x0C
    call draw_msprite
    xor ax,ax

    mov si, Bullet1Spr
    mov di, 320*80+160+11
    mov ax, 0x05
    call draw_sprite
    xor ax,ax

    mov si, Power1Spr
    mov di, 320*90+110
    call draw_msprite

    mov si, Power2Spr
    mov di, 320*90+210
    call draw_msprite

    mov si, Enemy1Spr
    mov di, 320*60+160
    call draw_msprite

    mov si, Enemy2Spr
    mov di, 320*60+140
    call draw_msprite

    mov si, Enemy3Spr
    mov di, 320*60+180
    call draw_msprite

    mov si, Enemy4Spr
    mov di, 320*60+200
    call draw_msprite

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
draw_msprite:
  push di               ; Save destination position
  xor dx,dx             ; Clear mirroring (left side)
  call draw_sprite
  inc dx                ; Enable mirroring (right side)
  pop di                ; Restore destination position
  add di, 15            ; Adjust mirrored position
  call draw_sprite
  ret

draw_sprite:
    pusha
    mov cx, [si]        ; Get the start color of the palette
    mov bp, cx          ; Save in bp
    inc si
    inc si              ; Mov si to the sprite data
    mov cx, 0x8         ; Set default sprite lines
    cmp ax, 0x0         ; Check if user set custom lines number
    jz .default         ; Keep default if not
    mov cx, ax          ; Update lines to custom
    .default:
    .plot_line:
        push cx           ; Save lines couter
        mov ax, [si]      ; Get sprite line
        mov cx, 0x08      ; 8 pixels in line
        .draw_pixel:
            xor bx,bx        ; Clear bx
            shl ax,1         ; Cut left bit
            adc bx,0         ; Get first bit
            shl bx,1         ; Mov to represent 2 or 0
            shl ax,1         ; Cut left bit
            adc bx,0         ; Get second bit (0,1)
            cmp bx, 0
            jz .skip_pixel
            imul bx, 0x04    ; Poors man palette
            add bx, bp       ; Palette colors shift by 12,16,1a,1e

            mov [es:di], bl  ; Write pixel color
            .skip_pixel:     ; Or skip this pixel - alpha color
            inc di           ; Move destination to next pixel (+1)
            cmp dx, 0        ; Check if mirroring enabled
            jz .rev          ; Jump if not
            dec di           ; Remove previous shift (now it's 0)
            dec di           ; Move destination 1px left (-1)
            .rev:
            loop .draw_pixel
        inc si               ; Move to the next
        inc si               ; Sprite line data
        add di, 312          ; And next line in destination
        cmp dx, 0            ; Mirror check
        jz .rev2
        add di, 16           ; If mirrored adjust next line position
        .rev2:
    pop cx                   ; Restore line counter
    loop .plot_line
    popa
    ret


; =========================================== SPRITE DATA ======================

ShipSpr:
dw 0x12
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
dw 0x10
dw 0000000000001010b
dw 0000000000101011b
dw 0000000010011010b
dw 0000000111011011b
dw 0000011110011101b
dw 0001111010100101b
dw 0001010000011001b
dw 0000000000000110b
Enemy1Spr:
dw 0x47
dw 0000001100000010b
dw 0000000111000001b
dw 0001000010100110b
dw 1000010101110110b
dw 0011100000101001b
dw 0000000011010111b
dw 0000001000000010b
dw 0000010000000000b
Enemy2Spr:
dw 0x20
dw 0111111101000000b
dw 0001101011110000b
dw 0000000110100010b
dw 0001010000101011b
dw 0000101110010110b
dw 0001010000011101b
dw 0000000110100110b
dw 0001101001000010b
Enemy3Spr:
dw 0x23
dw 1011111101000001b
dw 1101010110000110b
dw 1101101010011011b
dw 0110101011011011b
dw 0001010101100110b
dw 0000100100111101b
dw 0010001001010110b
dw 0010011000001000b
Enemy4Spr:
dw 0x55
dw 1100000000001100b
dw 0010000000001000b
dw 0000100000010101b
dw 0000000110101010b
dw 0010111001011101b
dw 1111101010100010b
dw 0110111111111111b
dw 0000000101101010b
Power1Spr:
dw 0x13
dw 1011000000000000b
dw 1100001111111001b
dw 0000111010100111b
dw 0000101111011111b
dw 0000110101010111b
dw 0000111001010101b
dw 1100001010111011b
dw 1011000000000000b
Power2Spr:
dw 0x13
dw 1011000000000011b
dw 1100001111100111b
dw 0000111010101101b
dw 0000101101110101b
dw 0000110101011101b
dw 0000110101010111b
dw 1100001010100111b
dw 1011000000000010b
Bullet1Spr:
dw 0x12
dw 0000001010000000b
dw 0000001111000000b
dw 0000011111010000b
dw 0001100101100100b
dw 0000010000010000b


Logo:
db "P1X"
