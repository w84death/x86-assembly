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

PLAYER_VELMAX equ 0x2F
PLAYER_X_ADR equ 0x7000
PLAYER_Y_ADR equ 0x7002
PLAYER_VELX_ADR equ 0x7004
PLAYER_VELY_ADR equ 0x7006

;ENTITIES_ADR aqu 0x70A0
; type; bullet, enemy 01234, power-up
; pos x
; pos y
; target x
; target y
; vel x
; vel y



start:
    mov ax,0x13                             ; Init VGA 320x200x256
    int 0x10                                ; Video BIOS interrupt

    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop es                                  ; as target

    cli
    mov al, 0xF4
    out 0x60, al
    sti

mov word [PLAYER_X_ADR], 0xA0
mov word [PLAYER_Y_ADR], 0xA0
mov word [PLAYER_VELX_ADR], 0x00
mov word [PLAYER_VELY_ADR], 0x00

game_loop:
    ;inc bp
    xor di,di                   ; Clear destination address
    xor si,si                   ; Clear source address

draw_bg:
    mov ax,0x1111               ; Set background color (2 bytes)
    mov cx,SCREEN_BUFFER_SIZE   ; Set buffer size to fullscreen
    rep stosw                   ; Fill the buffer with color

draw_tunnel:

  mov ax, 0
  mov bx, 160
  mov cx, 160
  mov dx, 0x1A
  .l:
  call draw_box
  add ax, 2
  sub cx, 8
  dec dx
  cmp dx, 0x10
  jg .l

booster_logic:
  mov si, PLAYER_VELX_ADR
  mov di, PLAYER_X_ADR
  call calc_velocity
  mov si, PLAYER_VELY_ADR
  mov di, PLAYER_Y_ADR
  call calc_velocity

draw_ship:
    mov di, [PLAYER_Y_ADR] ;y
    imul di, 320
    add di, [PLAYER_X_ADR] ;x

    mov si, BoosterSpr
    sub di, 10
    call draw_msprite
    add di, 5
    call draw_msprite

    mov si, ShipSpr
    sub di, 320*6+25
    call draw_msprite

draw_bullet:
    mov si, Bullet1Spr
    mov di, 320*80+160+11
    call draw_sprite

draw_powerups:
    mov si, Power1Spr
    mov di, 320*90+110
    call draw_msprite

    mov si, Power2Spr
    mov di, 320*90+210
    call draw_msprite

draw_enemies:
    mov si, Enemy1Spr
    mov di, 320*60+140
    call draw_msprite

    mov si, Enemy2Spr
    mov di, 320*60+160
    call draw_msprite

    mov si, Enemy3Spr
    mov di, 320*60+180
    call draw_msprite

    mov si, Enemy4Spr
    mov di, 320*60+200
    call draw_msprite


handle_keyboard:

        ;in al, 0x64
        ;test al, 1
        ;jnz .done

        in al,0x60                           ; Read keyboard

        ;test al, 0x80
        ;jnz .done

        cmp al,0x01                         ; ESC pressed
        je exit

        mov bx, word [PLAYER_VELX_ADR]
        mov cx, word [PLAYER_VELY_ADR]

        cmp al,0x48                         ; Up pressed
        jne .no_up
          sub cx, 0x03
        .no_up:
        cmp al,0x50                         ; Down pressed
        jne .no_down
          add cx, 0x03
        .no_down:
        cmp al,0x4D                         ; Right pressed
        jne .no_right
          add bx, 0x03
        .no_right:
        cmp al,0x4B                         ; Left pressed
        jne .no_left
          sub bx, 0x03
        .no_left:

         cmp bx, 0x0A
         jg .skipx
         cmp bx, -0x0A
         jl .skipx
           mov word [PLAYER_VELX_ADR], bx
         .skipx:
         cmp cx, 0x08
         jg .done
         cmp cx, -0x08
         jl .done
           mov word [PLAYER_VELY_ADR], cx
        .done:


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

; DI - positon (linear)
; SI - sprite data addr
;    2 bit height (lines)
;    2 bit color palette
;    2-bit per pixel data
;
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
            cmp dx, 0        ; Check if mirroring X enabled
            jz .revX          ; Jump if not
            dec di           ; Remove previous shift (now it's 0)
            dec di           ; Move destination 1px left (-1)
            .revX:
            loop .draw_pixel

        inc si               ; Move to the next
        inc si               ; Sprite line data

        ; check DX, si -4 if mirror Y

        add di, 312          ; And next line in destination

        cmp dx, 0            ; Mirror X check
        jz .revX2
        add di, 16           ; If mirrored adjust next line position
        .revX2:
    pop cx                   ; Restore line counter
    loop .plot_line
    popa
    ret

calc_velocity:
  mov word ax, [si]
  cmp ax, 0
  jz .done
  jg .poz
  jl .neg
  .poz:
  dec word [si]
  jmp short .add
  .neg:
  inc word [si]
  .add:
  ;shr ax, 2
  add word [di],ax
  .done:
  ret

draw_box:
  pusha
  imul ax, 320
  add ax, bx
  mov di, ax
  mov bx, cx

  push bx
  sub di, bx
  shl bx, 1
  mov cx, bx
  mov ax, dx
  rep stosb
  mov cx, bx
  pop bx
  imul bx, 320
  sub bx, cx
  add di, bx
  rep stosb
  popa
  ret

; =========================================== SPRITE DATA ======================

ShipSpr:
dw 0xC,0x12
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
dw 0x8,0x10
dw 0000000000001010b
dw 0000000000101011b
dw 0000000010011010b
dw 0000000111011011b
dw 0000011110011101b
dw 0001111010100101b
dw 0001010000011001b
dw 0000000000000110b
Enemy1Spr:
dw 0x8,0x47
dw 0000001100000010b
dw 0000000111000001b
dw 0001000010100110b
dw 1000010101110110b
dw 0011100000101001b
dw 0000000011010111b
dw 0000001000000010b
dw 0000010000000000b
Enemy2Spr:
dw 0x8,0x20
dw 0111111101000000b
dw 0001101011110000b
dw 0000000110100010b
dw 0001010000101011b
dw 0000101110010110b
dw 0001010000011101b
dw 0000000110100110b
dw 0001101001000010b
Enemy3Spr:
dw 0x8,0x23
dw 1011111101000001b
dw 1101010110000110b
dw 1101101010011011b
dw 0110101011011011b
dw 0001010101100110b
dw 0000100100111101b
dw 0010001001010110b
dw 0010011000001000b
Enemy4Spr:
dw 0x8,0x55
dw 1100000000001100b
dw 0010000000001000b
dw 0000100000010101b
dw 0000000110101010b
dw 0010111001011101b
dw 1111101010100010b
dw 0110111111111111b
dw 0000000101101010b
Power1Spr:
dw 0x8,0x13
dw 1011000000000000b
dw 1100001111111001b
dw 0000111010100111b
dw 0000101111011111b
dw 0000110101010111b
dw 0000111001010101b
dw 1100001010111011b
dw 1011000000000000b
Power2Spr:
dw 0x8,0x13
dw 1011000000000011b
dw 1100001111100111b
dw 0000111010101101b
dw 0000101101110101b
dw 0000110101011101b
dw 0000110101010111b
dw 1100001010100111b
dw 1011000000000010b
Bullet1Spr:
dw 0x5,0x12
dw 0000001010000000b
dw 0000001111000000b
dw 0000011111010000b
dw 0001100101100100b
dw 0000010000010000b


Logo:
db "P1X"
