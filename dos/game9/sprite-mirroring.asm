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
    mov ax,0x2020               ; Set background color (2 bytes)
    mov cx,SCREEN_BUFFER_SIZE   ; Set buffer size to fullscreen
    rep stosw                   ; Fill the buffer with color


draw_test_sprites:
  mov si, TestSpr
  mov di, 320*100+160
  mov dx, 00b
  call draw_sprite
  mov dx, 01b
  mov di, 320*100+160+15
  call draw_sprite

  mov dx, 10b
  mov di, 320*104+160
  call draw_sprite

  mov dx, 11b
  mov di, 320*104+160+15
  call draw_sprite


  mov di, 320*100+120
  mov dx, 00b
  call draw_sprite
  mov dx, 01b
  mov di, 320*100+120+24
  call draw_sprite

  mov dx, 10b
  mov di, 320*108+120
  call draw_sprite

  mov dx, 11b
  mov di, 320*108+120+24
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
draw_msprite:
  push di               ; Save destination position
  xor dx,dx             ; Clear mirroring (left side)
  call draw_sprite
  inc dx                ; Enable mirroring (right side)
  pop di                ; Restore destination position
  add di, 15            ; Adjust mirrored position
  call draw_sprite
  ret

; Drawing Sprite
; ------------------------------
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

        ;cmp dx, 0            ; Mirror X check
        mov bx, dx
        and bx, 1

        jz .revX2
        add di, 16           ; If mirrored adjust next line position
        .revX2:
    pop cx                   ; Restore line counter
    loop .plot_line
    popa
    ret

; =========================================== SPRITE DATA ======================

TestSpr:
dw 0x4,0x10
dw 0000000000000011b
dw 0000000000001110b
dw 0000000000110101b
dw 0000000011010100b

Logo:
db "P1X"
