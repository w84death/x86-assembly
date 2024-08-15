; GAME9 - DINO?
; DOS VERSION
;
; Description:
;   Some shootemup
;
;
; Author: Krzysztof Krystian Jankowski
; Date: 2024-08/15
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
    mov ax,0xc6c6               ; Set background color (2 bytes)
    mov cx,SCREEN_BUFFER_SIZE   ; Set buffer size to fullscreen
    rep stosw                   ; Fill the buffer with color


draw_terrain:
  mov si, LevelData

  mov di, [si]  ; position
  inc si
  inc si

  mov cx, [si]  ; width

  inc si
  inc si

  mov bp, [si] ; size
  inc si
  ;inc si

  .draw_tile:
    push si

    mov ax, [si]
    xor bx,bx        ; Clear bx
    shl ax,1         ; Cut left bit
    adc bx,0         ; Get first bit
    jz .skip_tile

    xor bx,bx        ; Clear bx
    shl ax,1         ; Cut left bit
    adc bx,0         ; Get first bit
    shl bx,1

    shl ax,1         ; Cut left bit
    adc bx,0         ; Get second bit
    shl bx,1

    shl ax,1         ; Cut left bit
    adc bx,0         ; Get third bit

    mov si, bx
    mov bx, 0x14
    imul si, bx
    add si, TerrainSpr

    xor bx,bx        ; Clear bx
    shl ax,1         ; Cut left bit
    adc bx,0         ; Get first bit
    shl bx,1
    shl ax,1         ; Cut left bit
    adc bx,0         ; Get second bit
    mov dx, bx
    call draw_sprite



    ; spawn tree?
    xor bx,bx        ; Clear bx
    shl ax,1         ; Cut left bit
    adc bx,0         ; Get first bit
    jz .skip_tree

    mov si, PalmSpr
    call draw_sprite
    .skip_tree:
    .skip_tile:

    ; next tile
    add di,0x8

    pop si
    inc si

    mov ax, cx
    dec ax
    div bp
    cmp dx, 0
    jnz .noNewLine

    ;add di, 320*8-64

    mov ax, 0x140
    mov bx, 0x08
    mul bx
    add di, ax
    mov ax, 0x08
    mul bp
    sub di, ax

    .noNewLine:
  loop .draw_tile

draw_players:
  mov si, DinoASpr
  mov di, 320*100+160
  rdtsc
  and ax, 0x1
  mov bx, 320
  imul ax, bx
  sub di, ax
  xor dx, dx
  call draw_sprite

  mov si, SnakeSpr
  mov di, 320*108+146
  rdtsc
  and ax, 0x1
  mov bx, 320
  imul ax, bx
  sub di, ax
  xor dx, dx
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
    exit:
    mov ax, 0x0003
    int 0x10
    ret

; =========================================== DRAW SPRITE PROCEDURE ============
; DI - positon (linear)
; SI - sprite data addr
; DX - settings
;    - 00 - normal
;    - 01 - mirrored x
;    - 10 - mirrored y
;    - 11 - mirrored X&Y
draw_sprite:
    pusha
    mov cx, [si]        ; Get the sprite lines
    inc si
    inc si              ; Mov si to the color data
    mov bp, [si]        ; Get the start color of the palette
    inc si
    inc si              ; Mov si to the sprite data

    mov bx, dx
    and bx, 1
    jz .revX3
    add di, 0x7
    .revX3:
    ; check DX, go to the end of si (si+cx*2)
    mov bx, dx
    and bx, 2
    jz .revY
    add si, cx
    add si, cx
    sub si, 2
    .revY:


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

            cmp bx, 0        ; transparency
            jz .skip_pixel

            imul bx, 0x03    ; Poors man palette
            add bx, bp       ; Palette colors shift by 12,16,1a,1e

            mov [es:di], bl  ; Write pixel color
            .skip_pixel:     ; Or skip this pixel - alpha color
            inc di           ; Move destination to next pixel (+1)
            ;cmp dx, 0        ; Check if mirroring X enabled
            mov bx, dx
            and bx, 1
            jz .revX          ; Jump if not
            dec di           ; Remove previous shift (now it's 0)
            dec di           ; Move destination 1px left (-1)
            .revX:
            loop .draw_pixel

        inc si               ; Move to the next
        inc si               ; Sprite line data

        ; check DX, si -4 if mirror Y
        mov bx, dx
        and bx, 2
        jz .revY2
        sub si, 4
        .revY2:

        add di, 312          ; And next line in destination

        mov bx, dx
        and bx, 1
        jz .revX2
        add di, 0x10           ; If mirrored adjust next line position
        .revX2:
    pop cx                   ; Restore line counter
    loop .plot_line
    popa
    ret

; =========================================== SPRITE DATA ======================

TerrainSpr:

; Dense grass
dw 0x8,0xba
dw 0110100101101001b
dw 1001011010010110b
dw 0110100101101001b
dw 1001011010010110b
dw 0110100101101001b
dw 1001011010010110b
dw 0110100101101001b
dw 1001011010010110b

; Light grass
dw 0x8,0xba
dw 1010101010101010b
dw 1001101001101010b
dw 1010101010101010b
dw 1010011010011010b
dw 1010101010101010b
dw 1001101001101010b
dw 1010101010101010b
dw 1010011010011010b

; Right bank
dw 0x8,0xba
dw 1010100111011111b
dw 1010101001110111b
dw 1001101001110111b
dw 1010101001110111b
dw 1010011001110111b
dw 1010101001110111b
dw 1010101001110111b
dw 1001100111011111b

; Bottom bank
dw 0x8,0xba
dw 1001101010101001b
dw 1010101010101010b
dw 1010011010011010b
dw 0101101010010101b
dw 1101010101111111b
dw 0111111111010101b
dw 1101010101111111b
dw 0011111111110000b

; Corner
dw 0x8,0xba
dw 1010100111011100b
dw 1010010111011100b
dw 1010011101111100b
dw 0101110111110000b
dw 1111011111000000b
dw 0101111100000000b
dw 1111110000000000b
dw 0000000000000000b

; Waves light
dw 0x8, 0xbc
dw 0000000000000000b
dw 0000000000000000b
dw 0000000000000000b
dw 0000001011000000b
dw 0001110000011100b
dw 0000000000000000b
dw 0000000000000000b
dw 0000000000000000b

; Waves dense

PalmSpr:
dw 0x7, 0x27
dw 0010000000000000b
dw 1011100010101000b
dw 1100111011111110b
dw 0000101111110011b
dw 0010110001111000b
dw 0011000001001100b
dw 0000000101000000b

DinoASpr:
dw 0x8, 0x20
dw 0000011011111100b
dw 0000001010010111b
dw 1100000010101010b
dw 1000001010010000b
dw 0110101010101100b
dw 0001101011100000b
dw 0000001010100000b
dw 0000010000010000b

SnakeSpr:
dw 0x8, 0x56
dw 0000000000000000b
dw 0000000000100100b
dw 0010000010011001b
dw 0000010010010101b
dw 0000010011101000b
dw 0010000000010110b
dw 0001011011001001b
dw 0000111001011011b


LevelData:
; start position
; length - number of tiles
; width - when to make line brake
; tiles - visible(1) sprite id(3)  mirror(2) tree(1) empty(1)
dw 320*(100-12)+(160-24)
dw 0x28
dw 0x08

db 11010000b
db 11010000b
db 00000000b
db 11010000b
db 00000000b
db 00000000b
db 00000000b
db 00000000b

db 11001100b
db 10111000b
db 10111000b
db 10111000b
db 10111000b
db 10111000b
db 10111000b
db 11001000b

db 10100100b
db 10010000b
db 10010010b
db 10010000b
db 10000000b
db 10010000b
db 10000000b
db 10100000b

db 10100100b
db 10010000b
db 10000000b
db 10000000b
db 10000000b
db 10010000b
db 10010010b
db 10100000b

db 11000100b
db 10110000b
db 10110000b
db 10110000b
db 10110000b
db 10110000b
db 10110000b
db 11000000b

Logo:
db "P1X"
