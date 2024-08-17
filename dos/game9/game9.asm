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
    mov ax, 0x3b3b                          ; Multiply level by 0x0404
    mov dx, 16                              ; We have 8 bars
    .draw_bars:
        mov cx, 320*3                  ; One bar of 320x200
        rep stosw                           ; Write to the doublebuffer
        inc ax                              ; Increment color index for next bar
        xchg al, ah                         ; Swap colors
        dec dx                              ; Decrement bar counter
        jnz .draw_bars

;13440
    mov dx, 0x7
    mov bx, 0x4
    mov al, 0x37
    .draw_bars2:
    mov cx, 320
    imul cx, bx
    inc al
    ;add al, bl
    mov ah,al
    rep stosw
    add bx, 0x2
    dec dx
    jnz .draw_bars2

draw_terrain:
  ; draw metatiles

  mov di, 320*(104)-32  ; position
  mov si, LevelData
  mov cx, 0x14

  .draw_meta_tiles:
  push cx
  push si


  mov ax, cx
  dec ax
  and ax, 0x1
  cmp ax, 0x1
  jnz .no_new_line
  add di, 320*8-(32*8)
  .no_new_line:

  mov ax, [si] ; AX - LevelData
  mov cx, 0x4
  .small_loop:
    push cx

    xor bx,bx        ; Clear bx
    shl ax,1         ; Cut left bit
    adc bx,0         ; Get first bit
    shl bx,1         ; Mov to represent 1 or 0
    shl ax,1         ; Cut left bit
    adc bx,0         ; Get second bit
    shl bx,1         ; Mov to represent 2 or 0
    shl ax,1         ; Cut left bit
    adc bx,0         ; Get third bit
    shl bx,1         ; Mov to represent 4 or 0
    shl ax,1         ; Cut left bit
    adc bx,0         ; Get forth bit

    push ax ; AX - LevelData

    mov si, MetaTiles
    mov ax, bx
    mov bx, 0x4
    imul bx
    add si, ax
    mov ax, [si] ; AX - MeTatile
    mov cx, 0x4
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
    add si, Tiles

    xor bx,bx        ; Clear bx
    shl ax,1         ; Cut left bit
    adc bx,0         ; Get first bit
    shl bx,1
    shl ax,1         ; Cut left bit
    adc bx,0         ; Get second bit
    mov dx, bx
    call draw_sprite

    ; spawn source?
    xor bx,bx        ; Clear bx
    shl ax,1         ; Cut left bit
    adc bx,0         ; Get first bit
    ; todo: add more resources
    jz .skip_tree


    mov si, PalmSpr
    call draw_sprite
    .skip_tree:
    .skip_tile:

    ; next tile
    add di,0x8

    pop si
    inc si
  loop .draw_tile

    pop ax
    pop cx
    dec cx
  jnz .small_loop


  pop si
  inc si
  inc si
  pop cx
  dec cx
  jnz .draw_meta_tiles



draw_players:
  mov si, DinoASpr
  mov di, 320*148+160
  rdtsc
  and ax, 0x1
  mov bx, 320
  imul ax, bx
  sub di, ax
  xor dx, dx
  call draw_sprite

  mov si, OctopusSpr
  mov di, 320*104+64
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

Tiles:

; Dense grass
dw 0x8,0x55
dw 1010101010101010b
dw 1001101001100110b
dw 1010101010101001b
dw 0110011010011010b
dw 1010101010101010b
dw 0101101001101110b
dw 1010101010101010b
dw 1010011010011010b


; Light grass
dw 0x8,0x55
dw 1010101010101010b
dw 1010101010101010b
dw 1001101010100110b
dw 1010101010101010b
dw 1010100110101010b
dw 1010101010101010b
dw 1010101001101010b
dw 0110101010101010b


; Right bank
dw 0x8,0x55
dw 1010100111011111b
dw 1010101001111111b
dw 1001101001111111b
dw 1010101001111111b
dw 1010011001111111b
dw 1010101001111111b
dw 1010101001111111b
dw 1001100111011111b

; Bottom bank
dw 0x8,0x55
dw 1001101010101001b
dw 1010101010101010b
dw 1010011010011010b
dw 0101101010010111b
dw 1101010101111111b
dw 1111111111111111b
dw 0111111111110100b
dw 0001010101010000b

; Corner
dw 0x8,0x54
dw 1010100111110100b
dw 1010010111111100b
dw 1010011111111100b
dw 0101111111110100b
dw 1111111111010000b
dw 1111111101000000b
dw 0111110100000000b
dw 0000000000000000b


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

OctopusSpr:
dw 0x8, 0x16
dw 0011111111000000b
dw 1010101010110000b
dw 0110001100100000b
dw 0001101010100000b
dw 0000011001000011b
dw 1100000000001000b
dw 0010001011000100b
dw 0001000100000000b

MetaTiles:
; tiles - visible(1) sprite id(3)  mirror(2) source(2):
;   00 no source
;   01 source 1
;   10 source 2
;   11 source 3
; 000 Dense grass
; 001 Light grass
; 010 Right bank
; 011 Bottom bank
; 100 Corner
db 0b

; *___YX___

; 0000 up-ball
db 11001100b
db 10111000b
db 10111100b
db 11001000b

; 0001 down-ball
db 11000100b
db 10110100b
db 10110000b
db 11000000b

; 0010 up-left-long-ball
db 11001100b
db 10111000b
db 10111100b
db 10111000b

; 0011 up-right-long-ball
db 10111000b
db 10111100b
db 10111000b
db 11001000b

; 0100 down-left-long-ball
db 11000100b
db 10110000b
db 10110100b
db 10110000b

; 0101 down-right-long-ball
db 10110000b
db 10110100b
db 10110000b
db 11000000b

; 0110 left-bank
db 10100100b
db 10000100b
db 10000000b
db 10000100b

; 0111 right-bank
db 10000000b
db 10000100b
db 10000100b
db 10100000b

; 1000 top-bank
db 10111100b
db 10111000b
db 10111100b
db 10111000b

; 1001 bottom-bank
db 10110100b
db 10110100b
db 10110100b
db 10110100b

; 1010 light-grass
db 10000100b
db 10000000b
db 10000000b
db 10000100b

; 1011 dense-grass
db 10010100b
db 10010000b
db 10010100b
db 10010000b

; 1100 source-1
db 10010000b
db 10000010b
db 10000000b
db 10010000b

; 1101 source-2
db 10010000b
db 10010000b
db 10000010b
db 10000000b

; 1110 source-3
db 10010000b
db 10000010b
db 10000000b
db 10010000b

; 1111 empty-filler
db 00000000b
db 00000000b
db 00000000b
db 00000000b

LevelData:
; list of meta tiles
; width of each level is 8x8
;1 ****____****____
dw 0000111111111111b
dw 0010001111110000b
;2 ****____****____
dw 0110001111111111b
dw 0110101010000111b
;3 ****____****____
dw 0110101110001000b
dw 1010101110100111b
;4 ****____****____
dw 0001011010101011b
dw 1011101010110111b
;5 ****____****____
dw 1111011010101010b
dw 1010101110101111b
;6 ****____****____
dw 1111011001010110b
dw 1011101011111111b
;7 ****____****____
dw 1111000111111111b
dw 1111111111111111b
;8 ****____****____
dw 1111111111111111b
dw 1111111111111111b
;9 ****____****____
dw 1111111111111111b
dw 1111111111111111b
;10 ****____****____
dw 0000111111111111b
dw 1111111111110000b


Logo:
db "P1X"
