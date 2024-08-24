; GAME9 - DINOPIX
; DOS VERSION
;
; Description:
;   Dino cook serving food to octopuses.
;
;
; Author: Krzysztof Krystian Jankowski
; Date: 2024-08/18
; License: MIT

org 0x100
use16

; Memory adresses
_VGA_MEMORY_ equ 0xA000
_DBUFFER_MEMORY_ equ 0x8000
_CURRENT_LEVEL_ equ 0x7000
_PLAYER_POS_ equ 0x7002
_PLAYER_MEM_ equ 0x7004
_PLAYER_MIRROR_ equ 0x7006
_ENTITIES_ equ 0x70a0

; Constants
LEVEL_START_POSITION equ 320*80
PLAYER_START_POSITION equ 0x610            ; AH=Y, AL=X
LEVELS_AVAILABLE equ 0x4
COLOR_SKY equ 0x3b3b
COLOR_WATER equ 0x3636

start:
    mov ax,0x13                             ; Init VGA 320x200x256
    int 0x10                                ; Video BIOS interrupt

    push _DBUFFER_MEMORY_                 ; Set doublebuffer memory
    pop es                                  ; as target

set_keyboard_rate:
    xor ax, ax
    xor bx, bx
    mov ah, 03h         ; BIOS function to set typematic rate and delay
    mov bl, 1Fh         ; BL = 31 (0x1F) for maximum repeat rate (30 Hz)
    int 16h

restart_game:
    mov word [_CURRENT_LEVEL_], 0x0000
    mov word [_PLAYER_POS_], PLAYER_START_POSITION

    mov word [_ENTITIES_], 0x0101      ; Y/X
    mov byte [_ENTITIES_+2], 0x00      ; ID: 0 eyes, 1 submerged
    mov byte [_ENTITIES_+3], 0x00      ; State: 0 explore, 1 hungry, 2 waiting

    mov word [_ENTITIES_+4], 0x0805      ; Y/X
    mov byte [_ENTITIES_+6], 0x00      ; ID: 0 eyes, 1 submerged
    mov byte [_ENTITIES_+7], 0x00      ; State: 0 explore, 1 hungry, 2 waiting



game_loop:
    xor di,di                   ; Clear destination address
    xor si,si                   ; Clear source address

; =========================================== DRAW BACKGROUND ==================
draw_bg:
  mov ax, COLOR_SKY               ; Set color to 3b
  mov cl, 0xa                  ; 16 bars to draw
  .draw_bars:
     push cx

     mov cx, 320*3           ; 3 pixels high
     rep stosw               ; Write to the doublebuffer
     inc ax                  ; Increment color index for next bar
     xchg al, ah             ; Swap colors

     pop cx                  ; Decrement bar counter
     loop .draw_bars

  mov cx, 320*70              ; Clear the rest of the screen
  mov ax, COLOR_WATER              ; Set color to 36
  rep stosw                   ; Write to the doublebuffer

; =========================================== DRAW TERRAIN =====================

draw_terrain:
  mov di, LEVEL_START_POSITION
  sub di, 32    ; bug

  ; draw metatiles
  mov si, LevelData
  mov word ax, [_CURRENT_LEVEL_]
 imul ax, 0x28
  add si, ax

  mov cl, 0x14 ; 20 reads, 2 per line
  .draw_meta_tiles:
  push cx
  push si

  dec cx
  shr cx, 0x1
  jnc .no_new_line
    add di, 320*8-(32*8)
  .no_new_line:

  mov ax, [si]      ; AX - LevelData
  mov cl, 0x4
  .small_loop:
    push cx

    mov cl, 0x4           ; Set up counter for loop
    call convert_value
    push ax             ; Preserve AX - LevelData

    mov si, MetaTiles
    mov ax, bx
   imul ax, 0x4
    add si, ax
    mov ax, [si] ; AX - MeTatile
    mov cl, 0x4
    .draw_tile:
      push cx
      push si

      mov ax, [si]
      shl ax, 1         ; Cut left bit
      jnc .skip_tile

      mov cl, 0x3           ; Set up counter for loop
      call convert_value

      mov si, bx
     imul si, 0x14
      add si, Tiles

      mov cl, 0x2           ; Set up counter for loop
      call convert_value

      mov dx, bx
      call draw_sprite

      ; spawn source?
      shl ax,1         ; Cut left bit
      ; todo: add more resources
      jnc .skip_tree
        mov si, SourcesSpr
        mov ax, di
        shr ax, 6
        and ax, 0x03
       imul ax, 0x10
        add si, ax
        call draw_sprite
      .skip_tree:

      .skip_tile:

      add di,0x8
      pop si
      inc si
      pop cx
    loop .draw_tile

    pop ax
    pop cx
  loop .small_loop

  pop si
  inc si
  inc si
  pop cx
loop .draw_meta_tiles

; =========================================== DRAW PLAYERS =====================
draw_players:
  mov si, DinoSpr
  mov cx, [_PLAYER_POS_]   ; Load player position into CX (Y in CH, X in CL)
  call conv_pos
  mov word [_PLAYER_MEM_], di

  rdtsc
  shr ax, 0x1
  jnc .skip_jump
  sub di, 320
  .skip_jump:

  mov dx, [_PLAYER_MIRROR_]
  call draw_sprite

;  xor dx,dx
;  mov di, [_PLAYER_MEM_]
;  sub di, 320*13+6


; =========================================== KEYBOARD INPUT ==================
check_keyboard:
  mov ah, 01h         ; BIOS keyboard status function
  int 16h             ; Call BIOS interrupt
  jz .no_key           ; Jump if Zero Flag is set (no key pressed)

  mov ah, 00h         ; BIOS keyboard read function
  int 16h             ; Call BIOS interrupt

  mov si, [_PLAYER_MEM_]
  add si, 320*4+5
  mov byte al, [_PLAYER_MIRROR_]
  shr al, 1
  jnc .skip_adjust
    sub si, 2
  .skip_adjust:

  .check_enter:
  cmp ah, 1ch         ; Compare scan code with enter
  jne .check_up
    inc word [_CURRENT_LEVEL_]
    cmp word [_CURRENT_LEVEL_], LEVELS_AVAILABLE
    jl .ok
    mov word [_CURRENT_LEVEL_], 0x0
    .ok:
    mov word [_PLAYER_POS_], PLAYER_START_POSITION

  .check_up:
  cmp ah, 48h         ; Compare scan code with up arrow
  jne .check_down
    sub si, 320*6
    call check_water
    jz .no_key
    sub word [_PLAYER_POS_],0x0100

  .check_down:
  cmp ah, 50h         ; Compare scan code with down arrow
  jne .check_left
    add si, 320*6
    call check_water
    jz .no_key
    add word [_PLAYER_POS_],0x0100

  .check_left:
  cmp ah, 4Bh         ; Compare scan code with left arrow
  jne .check_right
    sub si, 8
    call check_water
    jz .no_key
    dec word [_PLAYER_POS_]
    mov byte [_PLAYER_MIRROR_], 0x01

  .check_right:
  cmp ah, 4Dh         ; Compare scan code with right arrow
  jne .no_key
    add si, 6
    call check_water
    jz .no_key
    inc word [_PLAYER_POS_]
    mov byte [_PLAYER_MIRROR_], 0x00

  .no_key:

; =========================================== DRAW ENITIES ===============

draw_entities:
  mov si, _ENTITIES_
  mov cx, 2
  .next:
    push cx
    mov word cx, [si]
    call conv_pos

    push si
    mov si, FishSpr
    call draw_sprite
    pop si

    add si, 4
    pop cx
  loop .next

draw_caption:
  mov si, CaptionSpr
  sub di, 320*13-3
  call draw_sprite

  add di, 320*2
  mov si, IconsSpr
  call draw_sprite

; =========================================== VGA BLIT PROCEDURE ===============

vga_blit:
    push es
    push ds

    push _VGA_MEMORY_                     ; Set VGA memory
    pop es                                  ; as target
    push _DBUFFER_MEMORY_                 ; Set doublebuffer memory
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

conv_pos:
  mov di, LEVEL_START_POSITION
  sub di, 320*2
  xor ax, ax               ; Clear AX
  mov al, ch               ; Move Y coordinate to AL
 imul ax, 320*8
  xor dh, dh               ; Clear DH
  mov dl, cl               ; Move X coordinate to DL
  shl dx, 3                ; DX = X * 8
  add ax, dx               ; AX = Y * 2560 + X * 8
  add di, ax               ; Move result to DI
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
        mov cl, 0x08      ; 8 pixels in line
        .draw_pixel:
            push cx

            mov cl, 2
            call convert_value

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
            pop cx
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

; =========================================== CHECK WATER =====================
; SI - memory position to check for water
check_water:
    mov ax, [es:si]
    ;mov word [es:si], 0x0 ;DEBUG ONLY
    cmp ax, COLOR_WATER
    ret

; =========================================== CONVERT VALUE ===================
; AX - source
; CL - number of bits to convert
; Return: BX
convert_value:
    xor bx, bx          ; Clear BX
    .rotate_loop:
        rol ax, 1       ; Rotate left, moving leftmost bit to carry flag
        adc bx, 0       ; Add carry to BX (0 or 1)
        shl bx, 1       ; Shift BX left, making room for next bit
        loop .rotate_loop
    shr bx, 1           ; Adjust final result (undo last shift)
    ret

; =========================================== SPRITE DATA ======================

Tiles:
; Set of 8x8 tiles for constructing meta-tiles
; word lines
; word palette id
; word per line (8 pixels) of palette indexes

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


SourcesSpr:
dw 0x6, 0x27
dw 0000110000000000b
dw 0000101100000000b
dw 0011111000000000b
dw 0000100000000000b
dw 0000011111000000b
dw 0001011101010100b

dw 0x6, 0x27
dw 0000001000000000b
dw 1000110100100000b
dw 0010111010011100b
dw 1111011111110000b
dw 0010110111011101b
dw 0101111111010101b

dw 0x7, 0x27
dw 0010000000000000b
dw 1011100010101000b
dw 1100111011111110b
dw 0000101111110011b
dw 0010110001111000b
dw 0011000001001100b
dw 0000000101000000b


DinoSpr:
dw 0x8, 0x20
dw 0000011011111100b
dw 0000001010010111b
dw 1100000010101010b
dw 1000001010010000b
dw 0110101010101100b
dw 0001101011100000b
dw 0000001010100000b
dw 0000010000010000b

FishSpr:
dw 0x4, 0x64
dw 0011011100110111b
dw 0001100111011001b
dw 1011011100110111b
dw 0010101010101010b

dw 0x8, 0x64
dw 0011011100110111b
dw 0001100111011011b
dw 0011011111010111b
dw 0011111001101001b
dw 1110111001101001b
dw 1011111110010100b
dw 1010101111111000b
dw 0010111011101000b

CaptionSpr:
dw 0x0c, 0x17
dw 0010101010100100b
dw 1011111111111101b
dw 1011111111111110b
dw 0111111111111101b
dw 1011111111111110b
dw 1011111111111101b
dw 0111111111111101b
dw 0111111111111110b
dw 1101101010101001b
dw 0011111101100111b
dw 0000001110111100b
dw 0000001111000000b

IconsSpr:
dw 0x5, 0x16
dw 0000001111000000b
dw 0000001110000000b
dw 0000001001000000b
dw 0000000000000000b
dw 0000001110000000b

dw 0x5, 0x3b
dw 0000010000000000b
dw 0000101100000000b
dw 0000111111000000b
dw 0000111111000000b
dw 0000001111100000b

dw 0x5, 0x6b
dw 0000001111000000b
dw 0000111110010000b
dw 0000111010010000b
dw 0000111010010000b
dw 0000000101000000b

dw 0x4, 0x22
dw 0000000111000000b
dw 0011011001111000b
dw 0001011110100100b
dw 0000001001000000b


MetaTiles:
; List of tiles, one row of 4 tiles per meta-tile
db 0b
db 11001100b,10111000b,10111100b,11001000b  ; 0000 up-ball
db 11000100b,10110100b,10110000b,11000000b  ; 0001 down-ball
db 11001100b,10111000b,10111100b,10111000b  ; 0010 up-left-long-ball
db 10111000b,10111100b,10111000b,11001000b  ; 0011 up-right-long-ball
db 11000100b,10110000b,10110100b,10110000b  ; 0100 down-left-long-ball
db 10110000b,10110100b,10110000b,11000000b  ; 0101 down-right-long-ball
db 10100100b,10000100b,10000100b,10000100b  ; 0110 left-bank
db 10000000b,10000100b,10000000b,10100000b  ; 0111 right-bank
db 10111100b,10111000b,10111100b,10111000b  ; 1000 top-bank
db 10110100b,10110100b,10110100b,10110100b  ; 1001 bottom-bank
db 10100100b,10000100b,10000100b,10100000b  ; 1010 both-banks
db 10000100b,10000000b,10000000b,10000100b  ; 1011 light-terrain
db 10010100b,10010000b,10010100b,10010000b  ; 1100 dense-terrain
db 00000000b,00000000b,00000000b,00000000b  ; 1101 ???
db 10010000b,10000010b,10000000b,10010000b  ; 1110 source-random
db 00000000b,00000000b,00000000b,00000000b  ; 1111 empty-filler

LevelData:
; List of meta tiles, width of each level is 8x10
; Two words per line
; 8x10 = 80 tiles
; 40 bytes per level
      ; Custom Level, 40 bytes
; Made in smol.p1x.in/4bitleveleditor

; Level-1
dw 1111111100100011b,1111111111111111b
dw 1111111110101010b,1111111111111111b
dw 1111111100011010b,0011111111111111b
dw 1111111111110110b,0111111111111111b
dw 1111111100101011b,0111111111111111b
dw 1111111101101110b,0111111111111111b
dw 1111111101001011b,0101111111111111b
dw 1111111111111010b,1111111111111111b
dw 1111111111111010b,1111111111111111b
dw 1111111111110001b,1111111111111111b


; Level-2 (40b)

dw 1111111111111111b,1111111111111111b
dw 1111000011111111b,1111000011111111b
dw 0010101011111111b,1111010000110011b
dw 0110010111111111b,1111111101000111b
dw 1010111111111111b,1111111111111010b
dw 1010111111110010b,0000000000100100b
dw 1010001100101011b,1110010110110011b
dw 0110111001011001b,0001111111100111b
dw 0100010111111111b,1111111101000101b
dw 1111111111111111b,1111111111111111b

; Level-3 (40b)
dw 1111111111111111b,1111111111111111b
dw 1111111111111111b,1111111111111111b
dw 1111111100101000b,1000001111111111b
dw 0010100001101100b,1100011110000011b
dw 0110110011001100b,1100110011000111b
dw 0100110001110100b,1100100111000101b
dw 1111101000011111b,1010111110101111b
dw 1111101011111111b,1010111110101111b
dw 1111111011111111b,1110111111101111b
dw 1111000111111111b,0001111100011111b

; Level-4 (40b)
dw 1111111111111111b,1111111111111111b
dw 1111001011111111b,1111111100001111b
dw 1111011000110000b,1111001001111111b
dw 1111011010111011b,0011011001111111b
dw 1111011010111011b,1011111001111111b
dw 1111000110101001b,1001101101111111b
dw 1111111110101111b,1111010001111111b
dw 1111111110101111b,1111111100011111b
dw 1111111111101111b,1111111111111111b
dw 1111111100011111b,1111111111111111b


Logo:
db "P1X"
