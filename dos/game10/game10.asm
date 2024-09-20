; GAME10 - The X Project - Mysteries of the Forgotten Isles
; DOS VERSION
;
; Description:
;   You are an intrepid explorer stranded on the Forgotten Isles, a chain of 
;   islands shrouded in myth. These islands were once home to an advanced 
;   civilization known for their ingenious engineering and mystical practices. 
;   Scattered across the islands are pressure plates that, when activated, 
;   reveal clues and alter the landscape by raising bridges or opening gates. 
;   However, these plates require a sustained weight to remain activated, 
;   necessitating the use of rocks to keep them pressed while you progress.
;
; Size category: <2KB
;
; Author: Krzysztof Krystian Jankowski
; Web: smol.p1x.in/assembly/#dinopix
; License: MIT

org 0x100
use16

; =========================================== MEMORY ADDRESSES =================

_VGA_MEMORY_ equ 0xA000
_DBUFFER_MEMORY_ equ 0x8000
_PLAYER_ENTITY_ID_ equ 0x7000
_REQUEST_POSITION_ equ 0x7002
_ENTITIES_ equ 0x7010

_ID_ equ 0
_POS_ equ 1
_BRUSH_ equ 3
_MIRROR_ equ 5
_STATE_ equ 6

; =========================================== MAGIC NUMBERS ====================

BEEPER_ENABLED equ 0x01
BEEPER_FREQ equ 4800
LEVEL_START_POSITION equ 320*68+32
SPEED_EXPLORE equ 0x12c
COLOR_SKY equ 0x3b3b
COLOR_WATER equ 0x3636

ID_PLAYER equ 0 
ID_PALM equ 1
ID_SNAKE equ 2
ID_ROCK equ 3
ID_TRIGGER equ 4
ID_BRIDGE equ 5
ID_SHIP equ 6
ID_GOLD equ 7

; =========================================== INITIALIZATION ===================
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

; =========================================== SPAWN ENTITIES ==================
; Expects: entities array from level data
; Returns: entities in memory array
spawn_entities:
  mov si, EntityData
  mov di, _ENTITIES_

  mov cx, [EntityCount]
  .next_entitie:
    mov ax, [si+_POS_]         ; Get position
    mov [di+_POS_], ax         ; Save position

    mov byte [di+_MIRROR_], 0x0       ;  Save mirror (none)

    mov byte al, [si]           ; Get sprite id
    dec al                    ; Convert to engine numbering from level editor
    mov byte [di], al             ; Save sprite id
    mov bx, BrushRefs        ; Get sprite data offset table
    shl al, 2               ; Shift to ref (id*2 bytes)
    add bl, al                  ; Add sprite id to the offset index
    mov ax, [bx]              ; Get sprite data offset
    mov [di+_BRUSH_], ax       ; Save sprite data offset

    mov byte [di+_STATE_], 0x01   ; Save basic state

  add si, 0x03            ; Move to the next entity in code
  add di, 0x07            ; Move to the next entity in memory
loop .next_entitie

mov word [_PLAYER_ENTITY_ID_], _ENTITIES_ ; Set player entity id to first entity

; =========================================== GAME LOGIC =======================

game_loop:
  xor di, di
  xor si, si

; =========================================== DRAW BACKGROUND ==================

draw_bg:
  mov ax, COLOR_SKY               ; Set starting sky color
  mov cl, 0xa                  ; 10 bars to draw
  .draw_sky:
     push cx

     mov cx, 320*3           ; 3 pixels high
     rep stosw               ; Write to the doublebuffer
     inc ax                  ; Increment color index for next bar
     xchg al, ah             ; Swap colors

     pop cx                  ; Decrement bar counter
     loop .draw_sky

draw_ocean:
  xor dx, dx
  mov di, 320*60
  mov si, OceanBrush

  mov cx, 18
  .ll:
    push cx
    xor dh, 0x1

    mov cx, 40
    .l:
      ;xor dl, 0x1
      add dl, dh
      call draw_sprite
      add di, 8
    loop .l
       
    add di, 320*7
    pop cx
  loop .ll

  mov ax, [GameTick]
  and ax, 0x3
  cmp ax, 0x3
  jnz skip_anim
    mov si, PaletteSets
    add si, 3*4
    rol dword [si], 8
  skip_anim:

; =========================================== DRAWING LEVEL ====================

draw_level:
  mov si, LevelData
  mov di, LEVEL_START_POSITION
  xor cx, cx
  .next_meta_tile:
    push cx
    push si

    mov byte al, [si]     ; Read level cell
    mov bl, al            ; Make a copy
    shr bl, 0x4           ; Remove first nible
    and bl, 0x3           ; Read XY mirroring - BL

    and ax, 0xf           ; Read first nibble - AX
    jnz .not_empty 
      add di, 16
      jmp .skip_meta_tile
    .not_empty:
    
    mov si, MetaTiles
    shl ax, 0x2           ; ID*4 Move to position; 4 bytes per tile
    add si, ax            ; Meta-tile address
    
    mov dx, 0x0123        ; Default order: 0, 1, 2, 3
    test bl, 2           ; Mirror Y?
    jz .check_x
    xchg dh, dl          ; Order: 2, 3, 0, 1
    .check_x:
        test bl, 1           ; Mirror X?
        jz .push_tiles
        xchg dh, dl          ; Order: 2, 3, 0, 1
        rol dx, 8            ; Order: 1, 0, 3, 2
    
    .push_tiles:
        mov cx, 4            ; 4 tiles to push
    .next_tile_push:
        push dx              ; Push the tile ID
        ror dx, 4            ; Rotate to get the next tile ID in AL
        loop .next_tile_push
    
    mov cx, 0x4           ; 2x2 tiles
    .next_tile:
      pop dx              ; Get tile order
      and dx, 0x7
      push si
      add si, dx
      mov byte al, [si]   ; Read meta-tile with order
      pop si
      mov bh, al
      shr bh, 4            ; Extract the upper 4 bits
      and bh, 3            ; Mask to get the mirror flags (both X and Y)

      xor bh, bl          ; invert original tile mirror by meta-tile mirror
      mov dl, bh          ; set final mirror for tile
      
      and ax, 0xf         ; First nibble
      dec ax              ; We do not have tile 0, shifting values
     imul ax, 18          ; Move to position
      
      push si
      mov si, TerrainTiles
      add si, ax
      call draw_sprite
      pop si
    
      add di, 8

      cmp cx, 0x3
      jnz .skip_set_new_line
        add di, 320*8-16  ; Word wrap
      .skip_set_new_line:
      
      ;inc si
    loop .next_tile
    sub di, 320*8
    .skip_meta_tile:
      
    pop si
    inc si
    pop cx
    inc cx
    test cx, 0xf
    jnz .no_new_line 
      add di, 320*16-(16*16)  ; Move to the next display line 
    .no_new_line:

    cmp cx, 0x80           ; 128 = 16*8
  jl .next_meta_tile

; =========================================== SORT ENITIES ===============
; Sort entities by Y position
; Expects: entities array
; Returns: sorted entities array

sort_entities:
  xor ax, ax

  mov cx, [EntityCount]
  dec cx  ; We'll do n-1 passes

  .outer_loop:
    push cx
    mov si, _ENTITIES_

    .inner_loop:
      push cx
      mov bx, [si+1]  ; Get Y of current entity
      mov dx, [si+8]  ; Get Y of next entity

      cmp bh, dh      ; Compare Y values
      jle .no_swap


        mov di, si
        add di, 7

        mov ax, [_PLAYER_ENTITY_ID_]
        cmp ax, si
        jne .check_next_entity
          mov [_PLAYER_ENTITY_ID_], di
          jmp .swap_entities
        .check_next_entity:
        cmp ax, di
        jne .swap_entities
          mov [_PLAYER_ENTITY_ID_], si
        .swap_entities:

        mov cx, 7       ; 6 bytes per entity, so we move 3 words
        .swap_loop:
          mov al, [si]
          xchg al, [di]
          mov [si], al
          inc si
          inc di
          loop .swap_loop
        sub si, 7       ; Reset SI to start of current entity

      .no_swap:
      add si, 7       ; Move to next entity
      pop cx
      loop .inner_loop

    pop cx
    loop .outer_loop


; =========================================== DRAW ENITIES ===============

draw_entities:
  mov si, _ENTITIES_
  mov cx, [EntityCount]
  .next:
    push cx
    push si

_ID_ equ 0
_POS_ equ 1
_BRUSH_ equ 3
_MIRROR_ equ 5
_STATE_ equ 6

    cmp byte [si+_STATE_], 0x0
    jz .skip_entity

    mov cx, [si+_POS_]
    call conv_pos2mem       ; Convert position to memory

    mov byte al, [si]       ; Get brush id in AL
    mov ah, al              ; Save a copy in AH
    mov bx, BrushRefs       ; Get brush data offset table
    shl al, 2               ; Shift to ref (id*2 bytes)
    add al, 2               ; offest is at next byte (+2)
    movzx bx, al            ; Get address to BX
    add di, [BrushRefs + bx]  ; Get shift and apply to destination position

    mov dl, [si+_MIRROR_]   ; Get brush mirror flag
    mov bx, [si+_BRUSH_]    ; Get brush data address
    mov si, bx
    call draw_sprite

    cmp ah, ID_PLAYER       ; Test (copy) id for player
    jnz .skip_player_draw
      mov si, IndieBottomBrush
      add di, 320*7
      call draw_sprite
    .skip_player_draw:

    cmp ah, ID_BRIDGE
    jnz .skip_bridge_draw
      add di, 8
      mov dl, 0x01
      call draw_sprite
    .skip_bridge_draw:

    cmp ah, ID_SHIP
    jnz .skip_ship_draw
      sub di, 8
      mov si, ShipEndBrush
      call draw_sprite
      add di, 16
      mov dl, 0x01
      mov si, ShipEndBrush
      call draw_sprite
    .skip_ship_draw:

    cmp ah, ID_GOLD
    jnz .skip_gold_draw
      mov ax, [GameTick]
      and ax, 0x8
      cmp ax, 0x4
      jl .skip_gold_draw
      xor dx, dx
      mov si, GoldBrush
      call draw_sprite
    .skip_gold_draw:

    .skip_entity:
    pop si
    add si, 0x7
    pop cx
    dec cx
  jg .next

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


; =========================================== V-SYNC ======================

wait_for_vsync:
    mov dx, 03DAh
    .wait1:
        in al, dx
        and al, 08h
        jnz .wait1
    .wait2:
        in al, dx
        and al, 08h
        jz .wait2


; =========================================== GAME TICK ========================

inc word [GameTick]

; =========================================== ESC OR LOOP ======================

    in al,0x60                  ; Read keyboard
    dec al                      ; Decrement AL (esc is 1, after decrement is 0)
    jnz game_loop               ; If not zero, loop again

; =========================================== TERMINATE PROGRAM ================
  
  exit:
    mov ax, 0x0003             ; Return to text mode
    int 0x10                   ; Video BIOS interrupt
    ret                       ; Return to DOS

; =========================================== CNVERT XY TO MEM =================
; Expects: CX - position YY/XX
; Return: DI memory position
conv_pos2mem:
  mov di, LEVEL_START_POSITION
  xor ax, ax               ; Clear AX
  mov al, ch               ; Move Y coordinate to AL
 imul ax, 320*8
  xor dh, dh               ; Clear DH
  mov dl, cl               ; Move X coordinate to DL
  shl dx, 3                ; DX = X * 8
  add ax, dx               ; AX = Y * 2560 + X * 8
  add di, ax               ; Move result to DI
ret

; =========================================== RANDOM MOVE  =====================
; Expects: CX - position YY/XX
; Return: CX - updated pos

random_move:
  rdtsc
  and ax, 0x13
  jz .skip_move

  test ax, 0x3
  jz .move_y
    dec cl
    test byte [si+4], 0x01
    jnz .skip_move
    add cl, 2
  ret

.move_y:
  dec ch
  test ax, 0x10
  jz .skip_move
  add ch, 2

.skip_move:
  ret


; =========================================== CHECK BOUNDS =====================
; Expects: CX - Position YY/XX
; Return: AX - Zero if hit bound, 1 if no bounds at this location

check_bounds:
  xor ax, ax                                ; Assume bound hit (AX = 0)
  cmp ch, 0x0f
  ja .return
  cmp cl, 0x20
  ja .return
  inc ax                                    ; No bound hit (AX = 1)
.return:
  cmp ax, 0x0
  ret


; =========================================== DRAW SPRITE PROCEDURE ============
; Expects:
; DI - positon (linear)
; DX - settings: 00 normal, 01 mirrored x, 10 mirrored y, 11 mirrored x&y
; Return: -

draw_sprite:
    pusha
    xor cx, cx
    mov byte cl, [si]       ; lines
    inc si

    xor ax, ax
    mov byte al, [si]       ; Palette
    inc si

    shl ax, 0x2              ; each set is 4x 1 byte
    mov bp, ax
    add bp, PaletteSets

    mov bl, dl              ; Check x mirror
    and bl, 0x1
    jz .no_x_mirror
      add di, 0x7             ; Move point to the last right pixel
    .no_x_mirror:

    mov bl, dl              ; Check
    and bl, 0x2
    jz .no_y_mirror
      add si, cx
      add si, cx              ; Move to the last position
      sub si, 0x2             ; Back one word
    .no_y_mirror:

    .plot_line:
        push cx           ; Save lines couter
        mov ax, [si]      ; Get sprite line
        xor bx, bx
        mov cl, 0x08      ; 8 pixels in line
        push si
        .draw_pixel:
            push cx

            mov cl, 0x2
            call get_bits_from_word

            mov si, bp      ; Palette Set
            add si, bx      ; Palette color
            mov byte bl, [si] ; Get color from the palette

            cmp bl, 0x0        ; transparency
            jz .skip_pixel
              mov byte [es:di], bl  ; Write pixel color
            .skip_pixel:     ; Or skip this pixel - alpha color

            inc di           ; Move destination to next pixel (+1)

            mov bl, dl
            and bl, 0x1
            jz .no_x_mirror2          ; Jump if not
              dec di           ; Remove previous shift (now it's 0)
              dec di           ; Move destination 1px left (-1)
            .no_x_mirror2:

            pop cx
            loop .draw_pixel

        pop si
        add si, 0x2               ; Move to the next sprite line data

        mov bl, dl
        and bl, 0x2
        jz .no_y_mirror2
          sub si, 0x4
        .no_y_mirror2:

        add di, 312          ; Move to next line in destination

        mov bl, dl
        and bl, 0x1
        jz .no_x_mirror3
          add di, 0x10           ; If mirrored adjust next line position
        .no_x_mirror3:

    pop cx                   ; Restore line counter
    loop .plot_line
    popa
  ret


; =========================================== CONVERT VALUE ===================
; Expects:
; AX - source
; CL - number of bits to convert
; Return: BX

get_bits_from_word:
    xor bx, bx          ; Clear BX
    .rotate_loop:
        rol ax, 1       ; Rotate left, moving leftmost bit to carry flag
        adc bx, 0       ; Add carry to BX (0 or 1)
        shl bx, 1       ; Shift BX left, making room for next bit
        loop .rotate_loop
    shr bx, 1           ; Adjust final result (undo last shift)
    ret


; =========================================== BEEP PC SPEAKER ==================
; Set the speaker frequency
; Expects: BX - frequency value
; Return: -

beep:
  mov al, 0x0B6  ; Command to set the speaker frequency
  out 0x43, al   ; Write the command to the PIT chip
  mov ax, bx  ; Frequency value for 440 Hz
  out 0x42, al   ; Write the low byte of the frequency value
  mov al, ah
  out 0x42, al   ; Write the high byte of the frequency value
  in al, 0x61    ; Read the PIC chip
  or al, 0x03    ; Set bit 0 to enable the speaker
  out 0x61, al   ; Write the updated value back to the PIC chip
ret

no_beep:
  in al, 0x61    ; Read the PIC chip
  and al, 0x0FC  ; Clear bit 0 to disable the speaker
  out 0x61, al   ; Write the updated value back to the PIC chip
ret

; =========================================== GAME LIVE VARIABLES ==============

GameTick:
dw 0x0

; =========================================== COLOR PALETTES ===================
; Set of four colors per palette. 0x00 is transparency; use 0x10 for black.

PaletteSets:
db 0x00, 0x13, 0x17, 0x1b   ; 0x0 Grays
db 0x00, 0x06, 0x27, 0x43   ; 0x1 Indie top
db 0x00, 0x7f, 0x13, 0x15   ; 0x2 Indie bottom
db 0x95, 0x94, 0x7c, 0x7d   ; 0x3 Ocean
db 0x00, 0xb7, 0xbb, 0x8c   ; 0x4 Wood
db 0x00, 0x46, 0x5a, 0x5c   ; 0x5 Terrain 1 - shore
db 0x47, 0x46, 0x45, 0x54   ; 0x6 Terrain 2 - in  land
db 0x00, 0x06, 0x77, 0x2e   ; 0x7 Palm
db 0x00, 0x27, 0x2a, 0x2b   ; 0x8 Snake
db 0x00, 0x26, 0x43, 0x44   ; 0x9 Artifact
db 0x00, 0x15, 0x19, 0x1a   ; 0xa Rock
db 0x00, 0x76, 0x1c, 0x1d   ; 0xb Trigger off
db 0x00, 0x76, 0x18, 0x5c   ; 0xc Trigger Act
db 0x00, 0x2b, 0x2c, 0x5b   ; 0xd Gold

; =========================================== BRUSHES DATA =====================
; Set of 8xY brushes for entities
; Data: number of lines, palettDefaulte id, lines (8 pixels) of palette color id

BrushRefs:
dw IndieTopBrush, -320*6  ; 1
dw PalmBrush, -320*10     ; 2
dw SnakeBrush, -320*2     ; 3
dw RockBrush, 0           ; 4
dw TriggerBrush, 320*3    ; 5
dw BridgeBrush, 0         ; 6
dw ShipMiddleBrush, 0     ; 7
dw Gold2Brush, 320        ; 8
dw GoldBrush, 320         ; 9
dw TriggerActBrush, 320*3 ; 10

IndieTopBrush:
db 0x7, 0x1
dw 0000000101010000b
dw 0000010101010100b
dw 0000001111110000b
dw 0000000011110000b
dw 0000001010000000b
dw 0000001010100000b
dw 0000001101010000b

IndieBottomBrush:
db 0x4, 0x2
dw 0000000101010000b
dw 0000000100010000b
dw 0000001000100000b
dw 0000001000100000b

SnakeBrush:
db 0x8, 0x8
dw 0000000011011101b
dw 0000001111111111b
dw 0000001110001011b
dw 0000001010110001b
dw 0011000010101100b
dw 0000100001101000b
dw 0000010001010100b
dw 0000110101010000b

OceanBrush:
db 0x8, 0x3
dw 1111111110100100b
dw 0000111111111001b
dw 0000000011111110b
dw 0101000000001110b
dw 0101010100001111b
dw 1010010100001111b
dw 1110100101000011b
dw 1111100101000011b

ShipEndBrush:
db 0x7, 0x4
dw 0000101010101111b
dw 0000111111111010b
dw 0000101111111111b
dw 0000010101011011b
dw 0000000111111111b
dw 0000011010101010b
dw 0000000101010101b

ShipMiddleBrush:
db 0x7, 0x4
dw 1111101010111111b
dw 1111111111111111b
dw 1111111111111111b
dw 1111111111111111b
dw 1010111110101011b
dw 1010100110101010b
dw 0101010101010101b

PalmBrush:
db 0x10, 0x7
dw 0010100000101010b
dw 1011111010111110b
dw 1011101011101011b
dw 1010111110111011b
dw 1011111010111110b
dw 1011101010101110b
dw 1110111001101110b
dw 0011000101111011b
dw 0000000001000000b
dw 0000000001000000b
dw 0000000100001000b
dw 1011000100101100b
dw 1110110111101110b
dw 0010110101111011b
dw 1011101101101100b
dw 0011101011101100b

BridgeBrush:
db 0x8, 0x0
dw 0010101111101010b
dw 1011111010111111b
dw 1111101111111111b
dw 1111101011111111b
dw 1011111010101111b
dw 0110111111111010b
dw 0101101010101010b
dw 0001010101010101b

TriggerBrush:
db 0x5, 0xb
dw 0011111111111100b
dw 1110101010101011b
dw 1010101010101010b
dw 0110101010101001b
dw 0001010101010100b

TriggerActBrush:
db 0x5, 0xc
dw 0001010101010100b
dw 0110101010101001b
dw 1010101010101010b
dw 1110101010101011b
dw 0011111111111100b

RockBrush:
db 0x8, 0xa
dw 0000111111110000b
dw 0011111110101100b
dw 1111101111111111b
dw 1110111110101111b
dw 1011111010111001b
dw 0111111011111101b
dw 0101111110110101b
dw 0001010101010100b

GoldBrush:
db 0x6, 0xd
dw 0000111111110000b
dw 0011101111101100b
dw 1110111010111011b
dw 1010111010101010b
dw 0001101110100100b
dw 0000010101010000b

Gold2Brush:
db 0x6, 0xd
dw 0000001100000000b
dw 0000001100000000b
dw 0000001000000000b
dw 0000001000000000b
dw 0000000100000000b
dw 0000000100000000b


; =========================================== TERRAIN TILES DATA ===============
; 8x8 tiles for terrain
; Data: number of lines, palettDefaulte id, lines (8 pixels) of palette color id

TerrainTiles:
db 0x8, 0x05          ; 0x1 Shore left bank
dw 0010111101010101b
dw 0010111111010101b
dw 0010101111010101b
dw 0000101111010101b
dw 0000101111010101b
dw 0010101111010101b
dw 0010111101010101b
dw 0010111111010101b

db 0x8, 0x05          ; 0x2 Shore top bank
dw 0000000000000000b
dw 1010100000101010b
dw 1111101010101111b
dw 1111111111111111b
dw 0111111111111101b
dw 0101010101010101b
dw 0101010101010101b
dw 0101010101010101b

db 0x8, 0x5          ; 0x3 Shore corner outside
dw 0000101010101010b
dw 0010101111111110b
dw 1010111111111111b
dw 1011111111111111b
dw 1011111101010111b
dw 1011110101010101b
dw 1011110101010101b
dw 1011110101010101b

db 0x8, 0x5          ; 0x4 Shore corner filler inside
dw 1010111101010101b
dw 1011110101010101b
dw 1111010101010101b
dw 1101010101010101b
dw 0101010101010101b
dw 0101010101010101b
dw 0101010101010101b
dw 0101010101010101b

db 0x8, 0x6          ; 0x5 Ground light
dw 0110010101011001b
dw 1001011001010110b
dw 0101100101101001b
dw 0101010101010110b
dw 1001010110100101b
dw 0110100101010101b
dw 1001010110100110b
dw 0110010101011001b

db 0x8, 0x6           ; 0x6 Ground medium
dw 0110001001001001b
dw 1001010100100001b
dw 0100100101000110b
dw 0101010001101001b
dw 0101001000010101b
dw 1001010001100100b
dw 0101100101010110b
dw 0101010101010010b

db 0x8, 0x6           ; 0x7 Ground dense
dw 1011001001001001b
dw 1110110100110001b
dw 0011000101000111b
dw 0101101110101001b
dw 0101111011101101b
dw 1001001100111011b
dw 0111100101001100b
dw 1001011001010101b

db 0x8, 0x3           ; 0x8 Bridge disabled
dw 0000000000000000b
dw 0010101111101010b
dw 1011111010111111b
dw 1111101111111111b
dw 1111101011111111b
dw 1011111010101111b
dw 0110111111111010b
dw 0001101010101010b

; =========================================== META-TILES DECLARATION ===========
; 4x4 meta-tiles for level
; Data: 4x4 tiles id

MetaTiles:
db 00000000b, 00000000b, 00000000b, 00000000b
db 00000010b, 00000010b, 00000101b, 00000101b
db 00000001b, 00000101b, 00000001b, 00000101b
db 00000011b, 00000010b, 00000001b, 00000101b
db 00000101b, 00000101b, 00000101b, 00000101b
db 00000110b, 00000110b, 00000110b, 00000110b
db 00000110b, 00000110b, 00000111b, 00000110b
db 00000111b, 00000111b, 00000111b, 00000111b
db 00000100b, 00000101b, 00000101b, 00000101b
db 00000100b, 00000101b, 00000101b, 00110100b
db 00000000b, 00000000b, 00000000b, 00000000b
db 00000000b, 00000000b, 00000000b, 00000000b
db 00001000b, 00011000b, 00001000b, 00011000b
db 00000000b, 00000000b, 00000000b, 00000000b
db 00000000b, 00000000b, 00000000b, 00000000b
db 00000000b, 00000000b, 00000000b, 00000000b

; =========================================== LEVEL DATA =======================
; 16x16 level data
; Data: 4x4 meta-tiles id
; First nibble is meta-tile id, next 2 bits ar nibbles XY mirroring

LevelData:
db 00000000b, 00000011b, 00000001b, 00010001b
db 00000001b, 00010001b, 00010001b, 00010011b
db 00000000b, 00000011b, 00000001b, 00000001b
db 00010011b, 00000000b, 00000011b, 00010011b
db 00000000b, 00100010b, 00000101b, 00000101b
db 00000110b, 00000110b, 00000110b, 00010010b
db 00000000b, 00000010b, 00010110b, 00111000b
db 00110011b, 00000000b, 00000010b, 00010010b
db 00000000b, 00000010b, 00000101b, 00000110b
db 00000111b, 00010111b, 00000110b, 00010010b
db 00001100b, 00000010b, 00000110b, 00010010b
db 00000000b, 00000000b, 00000010b, 00010010b
db 00000000b, 00100011b, 00101000b, 00000101b
db 00000111b, 00000110b, 00111000b, 00110011b
db 00000000b, 00000010b, 00000101b, 00010010b
db 00001100b, 00000011b, 00001000b, 00010010b
db 00000000b, 00000000b, 00100011b, 00100001b
db 00110001b, 00100001b, 00110011b, 00000000b
db 00000000b, 00100011b, 00100001b, 00110011b
db 00000000b, 00100011b, 00100001b, 00110011b
db 00000000b, 00000000b, 00000000b, 00000000b
db 00001100b, 00000000b, 00000000b, 00000000b
db 00000000b, 00000000b, 00001100b, 00000000b
db 00000000b, 00000000b, 00000000b, 00000000b
db 00000000b, 00000000b, 00000000b, 00000011b
db 00010001b, 00000001b, 00010011b, 00000000b
db 00000011b, 00010001b, 00010001b, 00000001b
db 00010011b, 00000000b, 00000000b, 00000000b
db 00000000b, 00000000b, 00000000b, 00100011b
db 00100001b, 00110001b, 00110011b, 00000000b
db 00100011b, 00100001b, 00100001b, 00110001b
db 00110011b, 00000000b, 00000000b, 00000000b

; =========================================== ENTITIES DATA ====================

EntityCount:
dw 0x41

EntityData:
db 2
dw 0x0008
db 2
dw 0x000a
db 2
dw 0x000d
db 2
dw 0x000e
db 2
dw 0x0013
db 2
dw 0x0014
db 4
dw 0x001e
db 2
dw 0x0105
db 4
dw 0x0107
db 5
dw 0x010a
db 3
dw 0x010c
db 2
dw 0x0113
db 2
dw 0x0114
db 3
dw 0x0117
db 2
dw 0x0204
db 2
dw 0x0206
db 2
dw 0x0209
db 2
dw 0x020c
db 2
dw 0x0212
db 2
dw 0x0213
db 2
dw 0x0215
db 2
dw 0x0308
db 2
dw 0x0309
db 2
dw 0x030a
db 2
dw 0x030b
db 2
dw 0x030c
db 2
dw 0x0312
db 2
dw 0x0313
db 2
dw 0x0316
db 2
dw 0x031e
db 1
dw 0x0404
db 2
dw 0x0409
db 6
dw 0x0410
db 2
dw 0x041d
db 5
dw 0x041e
db 7
dw 0x0502
db 6
dw 0x0510
db 2
dw 0x0606
db 4
dw 0x060d
db 2
dw 0x0706
db 2
dw 0x070b
db 2
dw 0x0713
db 3
dw 0x071b
db 2
dw 0x071d
db 2
dw 0x071e
db 2
dw 0x071f
db 2
dw 0x0807
db 2
dw 0x080a
db 2
dw 0x080b
db 2
dw 0x0813
db 2
dw 0x081d
db 8
dw 0x081e
db 2
dw 0x081f
db 2
dw 0x0906
db 2
dw 0x0907
db 2
dw 0x090a
db 2
dw 0x0917
db 2
dw 0x0d07
db 4
dw 0x0d0a
db 4
dw 0x0d13
db 5
dw 0x0e07
db 2
dw 0x0e08
db 2
dw 0x0e16
db 5
dw 0x0e17
db 2
dw 0x0f17

; =========================================== THE END ====================
; Thanks for reading the source code!
; Visit http://smol.p1x.in for more.

Logo:
db "P1X"    ; Use HEX viewer to see P1X at the end of binary