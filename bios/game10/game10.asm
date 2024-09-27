; GAME10 - The X Project - Mysteries of the Forgotten Isles
; DOS VERSION
;
; Description:
;
;
; Size category: 2KB
;
; Author: Krzysztof Krystian Jankowski
; Web: smol.p1x.in/assembly/#forgotten-isles
; License: MIT

org 0x100
use16

; =========================================== MEMORY ADDRESSES =================

_VGA_MEMORY_ equ 0xA000
_DBUFFER_MEMORY_ equ 0x8000
_PLAYER_ENTITY_ID_ equ 0x7000
_REQUEST_POSITION_ equ 0x7002
_HOLDING_ID_ equ 0x7004
_ENTITIES_ equ 0x7010

_ID_ equ 0  ; 1 byte
_POS_ equ 1 ; 2 bytes / word
_MIRROR_ equ 3  ; 1 byte
_STATE_ equ 4 ; 1 bytes
_MOVABLE_ equ 5 ; 1 byte

; =========================================== MAGIC NUMBERS ====================

ENTITY_SIZE  equ 6
BEEPER_FREQ equ 4400
BEEPER_ALERT equ 5500
BEEP_GOLD equ 800
LEVEL_START_POSITION equ 320*68+32
SPEED_EXPLORE equ 0x12c
COLOR_SKY equ 0x3b3b
COLOR_WATER equ 0x3535

ID_PLAYER equ 0
ID_PALM equ 1
ID_SNAKE equ 2
ID_ROCK equ 3
; ID_TRIGGER equ 4
ID_BRIDGE equ 5
ID_SHIP equ 6
ID_GOLD equ 7

STATE_DEACTIVATED equ 0
STATE_IDLE equ 1
STATE_EXPLORING equ 2
STATE_FOLLOW equ 3
STATE_ACTIVATED equ 4

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

  .next_entitie:
    mov bl, [si]
    cmp bl, 0x0
    jz .done
    
    dec bl             ; Conv level id to game id

    inc si
    mov al, [si]
    inc si
    mov cl, al
    .next_in_group:
      mov byte [di], bl           ; Save sprite id
      mov ax, [si]          ; Get position
      mov [di+_POS_], ax          ; Save position
      mov byte [di+_MIRROR_], 0x0 ;  Save mirror (none)
      mov byte [di+_STATE_], STATE_IDLE ; Save basic state
      mov byte [di+_MOVABLE_], 0x0 ; Save movable flag 
      
      cmp bl, ID_SNAKE
      jnz .skip_snake
        mov byte [di+_STATE_], STATE_EXPLORING ; Save basic state
      .skip_snake:

      cmp bl, ID_PALM
      jnz .skip_palm
        rdtsc
        and al, 0x01
        mov byte [di+_MIRROR_], al ; Save basic state
      .skip_palm: 
      
      add si, 0x02                  ; Move to the next entity in code
      add di, ENTITY_SIZE           ; Move to the next entity in memory
    loop .next_in_group
  jmp .next_entitie
  .done:

mov word [_PLAYER_ENTITY_ID_], _ENTITIES_ ; Set player entity id to first entity
mov byte [_HOLDING_ID_], 0x0      

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
  mov cx, 320*70              ; 70 lines of ocean
  mov ax, COLOR_WATER
  rep stosw

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

    mov     dx, 0x0123       ; Default order: 0, 1, 2, 3
    .check_y:
      test    bl, 2
      jz      .check_x
      xchg    dh, dl           ; Swap top and bottom rows (Order: 2, 3, 0, 1)
    .check_x:
      test    bl, 1
      jz      .push_tiles
      ror     dh, 4            ; Swap nibbles in dh (tiles in positions 0 and 1)
      ror     dl, 4            ; Swap nibbles in dl (tiles in positions 2 and 3)

    .push_tiles:
        mov     cx, 4            ; 4 tiles to push
    .next_tile_push:
        push    dx               ; Push the tile ID
        ror     dx, 4            ; Rotate dx to get the next tile ID in place
        loop    .next_tile_push

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


; =========================================== KEYBOARD INPUT ==================

check_keyboard:
  mov ah, 01h         ; BIOS keyboard status function
  int 16h             ; Call BIOS interrupt
  jz .no_key_press           ; Jump if Zero Flag is set (no key pressed)

  mov si, [_PLAYER_ENTITY_ID_]
  mov cx, [si+_POS_]   ; Load player position into CX (Y in CH, X in CL)

  mov ah, 00h         ; BIOS keyboard read function
  int 16h             ; Call BIOS interrupt

  .check_enter:
  cmp ah, 1Ch         ; Compare scan code with enter key
  jne .check_up
    mov word [_HOLDING_ID_], 0x0
    mov word [_REQUEST_POSITION_], 0x0
    jmp .no_key_press
  .check_up:
  cmp ah, 48h         ; Compare scan code with up arrow
  jne .check_down
    dec ch
    jmp .check_move

  .check_down:
  cmp ah, 50h         ; Compare scan code with down arrow
  jne .check_left
    inc ch
    jmp .check_move

  .check_left:
  cmp ah, 4Bh         ; Compare scan code with left arrow
  jne .check_right
    dec cl
    mov byte [si+_MIRROR_], 0x1
    jmp .check_move

  .check_right:
  cmp ah, 4Dh         ; Compare scan code with right arrow
  jne .no_key
    inc cl
    mov byte [si+_MIRROR_], 0x0
    ;jmp .check_move

  .check_move:

  call check_friends
  jz .collision

  call check_water_tile
  jz .no_move
  call check_bounds
  jz .no_move

  mov word [si+_POS_], cx
  jmp .no_col

  .collision:
    mov word [_REQUEST_POSITION_], cx
  .no_move:
    mov bx, BEEPER_ALERT
    call beep
    jmp .no_key_press
  .no_col:
  .no_key:
    mov bx, BEEPER_FREQ
    call beep
  .no_key_press:


; =========================================== AI ENITIES ===============

ai_entities:
  mov si, _ENTITIES_
  mov cx, [EntityCount]
  .next_entity:
    push cx

    cmp byte [si+_STATE_], STATE_EXPLORING
    jnz .skip_explore
      rdtsc
      and ax, SPEED_EXPLORE
      cmp ax, SPEED_EXPLORE
      jnz .skip_explore

      .explore:
        mov cx, [si+_POS_]
        call random_move

        call check_bounds
        jz .can_not_move

        call check_friends
        jz .can_not_move

        call check_water_tile
        jz .can_not_move
        .move_to_new_pos:
          cmp cx, [si+_POS_]
          jg .skip_mirror_x
            mov byte [si+_MIRROR_], 0x1
          .skip_mirror_x:
          mov word [si+_POS_], cx
        .can_not_move:

    .skip_explore:


    cmp byte [si+_ID_], ID_ROCK
    jnz .skip_rock
      mov cx, [si+_POS_]
      cmp cx, [_REQUEST_POSITION_]
      jnz .skip_rock
        cmp word [_HOLDING_ID_], 0x0  
        jnz .skip_rock
          mov byte [si+_STATE_], STATE_FOLLOW
          mov byte [_REQUEST_POSITION_], 0
          mov word [_HOLDING_ID_], ID_ROCK         
    .skip_rock:

    cmp byte [si+_ID_], ID_BRIDGE
    jnz .skip_bridge
      mov cx, [si+_POS_]
      cmp cx, [_REQUEST_POSITION_]
      jnz .skip_bridge
        cmp word [_HOLDING_ID_], ID_ROCK
        jnz .skip_bridge
          mov byte [si+_STATE_], STATE_DEACTIVATED
          mov byte [_REQUEST_POSITION_], 0
          mov word [_HOLDING_ID_], 0xffff
    .skip_bridge:

    cmp byte [si+_STATE_], STATE_FOLLOW
    jnz .no_follow
      cmp word [_HOLDING_ID_], 0x0 
      jnz .check_kill
        mov byte [si+_STATE_], STATE_ACTIVATED
      .check_kill:
      cmp word [_HOLDING_ID_], 0xffff
      jnz .skip_kill
        mov byte [si+_STATE_], STATE_DEACTIVATED
        mov word [_HOLDING_ID_], 0x0
      .skip_kill:
      
    .no_follow: 
    
    add si, ENTITY_SIZE
    pop cx
    dec cx
  jnz .next_entity


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
      mov bx, [si+_POS_]  ; Get Y of current entity
      mov dx, [si+ENTITY_SIZE+_POS_]  ; Get Y of next entity

      cmp bh, dh      ; Compare Y values
      jl .no_swap

        mov di, si
        add di, ENTITY_SIZE

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

        mov cx, ENTITY_SIZE       ; 6 bytes per entity, so we move 3 words
        .swap_loop:
          mov al, [si]
          xchg al, [di]
          mov [si], al
          inc si
          inc di
          loop .swap_loop
        sub si, ENTITY_SIZE       ; Reset SI to start of current entity

      .no_swap:
      add si, ENTITY_SIZE       ; Move to next entity
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

    cmp byte [si+_STATE_], STATE_DEACTIVATED
    jz .skip_entity

    mov cx, [si+_POS_]
    call conv_pos2mem       ; Convert position to memory
    
    cmp byte [si+_STATE_], STATE_FOLLOW
    jnz .skip_follow
      push si
      mov si, [_PLAYER_ENTITY_ID_]
      mov cx, [si+_POS_]   ; Load player position into CX (Y in CH, X in CL)
      pop si
      mov word [si+_POS_], cx ; Save new position
      dec ch
      dec ch      ; Move up over the player
      call conv_pos2mem       ; Convert position to memory
      add di, 320*4
    .skip_follow:


    mov byte al, [si]       ; Get brush id in AL
    mov ah, al              ; Save a copy in AH

    cmp ah, ID_PLAYER
    jnz .skip_player_check
      cmp byte [_HOLDING_ID_], 0x0
      jz .skip_player_check
      mov al, 0x9
    .skip_player_check:
    shl al, 0x2
    mov bx, BrushRefs       ; Get brush reference table
    add bl, al              ; Shift to ref (id*2 bytes)
    mov dx, [bx]            ; Get brush data address
    push dx

    add al, 0x2               ; offest is at next byte (+2)
    movzx bx, al            ; Get address to BX
    add di, [BrushRefs + bx]  ; Get shift and apply to destination position
    mov dl, [si+_MIRROR_]     ; Get brush mirror flag
    pop si
    call draw_sprite

    cmp ah, ID_PLAYER
    jnz .skip_player_draw
      mov si, IndieBottomBrush
      add di, 320*7
      call draw_sprite
    .skip_player_draw:

    cmp ah, ID_SHIP
    jnz .skip_ship_draw
      xor dl, dl ; mo mirror
      sub di, 8
      mov si, ShipEndBrush
      call draw_sprite
      add di, 16
      inc dl ; mirror x
      mov si, ShipEndBrush
      call draw_sprite
    .skip_ship_draw:

    cmp ah, ID_GOLD
    jnz .skip_gold_draw
      mov ax, [GameTick]
      and ax, 0x8
      cmp ax, 0x4
      jl .skip_gold_draw
      xor dl, dl ; no mirror
      mov si, GoldBrush
      call draw_sprite
    .skip_gold_draw:

    .skip_entity:
    pop si
    add si, ENTITY_SIZE
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
call no_beep

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

.move_x:
  test ax, 0x3
  jz .move_y
    dec cl
    test ax, 0x10
    jz .skip_move
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
  test ax, 0x1
  ret

; =========================================== CHECK FRIEDS =====================
; Expects: CX - Position YY/XX
; Return: AX - Zero if hit entity, 1 if clear
check_friends:
  push si
  push cx
  xor bx, bx
  mov ax, cx

  mov cx, [EntityCount]
  mov si, _ENTITIES_
  .next_entity:
    cmp byte [si+_STATE_], STATE_DEACTIVATED
    jz .skip_this_entity
    cmp byte [si+_STATE_], STATE_FOLLOW
    jz .skip_this_entity
    cmp word [si+_POS_], ax
    jnz .skip_this_entity
    cmp byte [si+_MOVABLE_], 0x1
    jz .skip_this_entity
    inc bx
    .skip_this_entity:
    add si, ENTITY_SIZE
  loop .next_entity

  pop cx
  pop si
  cmp bx,0x1 
ret

; =========================================== CHECK WATER TILE ================
; Expects: CX - Player position (CH: Y 0-15, CL: X 0-31)
; Returns: AL - 0 if water (0xF), 1 otherwise

check_water_tile:
  mov ax, cx      ; Copy position to AX
  shr ah, 1       ; Y / 2
  shr al, 1       ; X / 2 to convert to tile position
  movzx bx, ah
  shl bx, 4       ; Multily by 16 tiles wide
  add bl, al      ; Y / 2 * 16 + X / 2
  add bx, LevelData
  mov al, [bx]    ; Read tile
  test al, 0x40   ; Check if movable (7th bit set)
  ret

; =========================================== DRAW SPRITE PROCEDURE ============
; Expects:
; DI - positon (linear)
; DL - settings: 0 normal, 1 mirrored x, 2 mirrored y, 3 mirrored x&y
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

    test dl, 0x1              ; Check x mirror
    jz .no_x_mirror
      add di, 0x7             ; Move point to the last right pixel
    .no_x_mirror:

    test dl, 0x2              ; Check
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
db 0x00, 0x34, 0x17, 0x1b   ; 0x0 Grays
db 0x00, 0x06, 0x27, 0x43   ; 0x1 Indie top
db 0x00, 0x7f, 0x13, 0x15   ; 0x2 Indie bottom
db 0x35, 0x34, 0x19, 0x1a   ; 0x3 Bridge
db 0x00, 0xb7, 0xbb, 0x8c   ; 0x4 Wood
db 0x00, 0x46, 0x5a, 0x5c   ; 0x5 Terrain 1 - shore
db 0x47, 0x46, 0x45, 0x54   ; 0x6 Terrain 2 - in  land
db 0x00, 0x06, 0x77, 0x2e   ; 0x7 Palm
db 0x00, 0x27, 0x2a, 0x2b   ; 0x8 Snake
db 0x00, 0x2b, 0x2c, 0x5b   ; 0x9 Gold Coin
db 0x00, 0x15, 0x19, 0x1a   ; 0xa Rock

; =========================================== BRUSH REFERENCES =================
; Brush data offset table
; Data: offset to brush data, Y shift

BrushRefs:
dw IndieTopBrush, -320*6
dw PalmBrush, -320*10
dw SnakeBrush, -320*2
dw RockBrush, 0
dw 0, 320
dw BridgeBrush, 0
dw ShipMiddleBrush, 0
dw Gold2Brush, 320
dw GoldBrush, 320
dw IndieTop2Brush, -320*5

; =========================================== BRUSHES DATA =====================
; Set of 8xY brushes for entities
; Data: number of lines, palettDefaulte id, lines (8 pixels) of palette color id

IndieTopBrush:
db 0x7, 0x1
dw 0000000101010000b
dw 0000010101010100b
dw 0000001111110000b
dw 0000000011110000b
dw 0000001010000000b
dw 0000001010100000b
dw 0000001101010000b

IndieTop2Brush:
db 0x7, 0x1
dw 0001000101000100b
dw 0011010101011100b
dw 0011001111111100b
dw 0011000011110000b
dw 0000111010000000b
dw 0000001010100000b
dw 0000001111110000b
dw 0000000101010000b

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
db 0x8, 0x3             ; Non movable - bridge spot
dw 0000000000000000b
dw 0000000101000000b
dw 0000010101010000b
dw 0001010000010100b
dw 0001000000000100b
dw 0001010000010100b
dw 0000010101010000b
dw 0000000101000000b

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
db 0x6, 0x9
dw 0000111111110000b
dw 0011101111101100b
dw 1110111010111011b
dw 1010111010101010b
dw 0001101110100100b
dw 0000010101010000b

Gold2Brush:
db 0x6, 0x9
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

db 0x8, 0x0           ; 0x8 Bridge Movable
dw 0000000000000000b
dw 0000000000000000b
dw 0000111111100000b
dw 0011111110101000b
dw 1111111010101011b
dw 0110111010111101b
dw 0001010101010100b
dw 0000000000000000b

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
db 00001000b, 00001000b, 00001000b, 00001000b
db 00000000b, 00000000b, 00000000b, 00000000b
db 00000000b, 00000000b, 00000000b, 00000000b
db 00000000b, 00000000b, 00000000b, 00000000b

; =========================================== LEVEL DATA =======================
; 16x8 level data
; Data: 4x4 meta-tiles id
; Nibble is meta-tile id, 2 bits ar nibbles XY mirroring, 1 bit movable

LevelData:
db 00000000b, 01000011b, 01000001b, 01010001b
db 00000001b, 01010001b, 01010001b, 01010011b
db 00000000b, 01000011b, 01000001b, 01000001b
db 01010011b, 00000000b, 01000011b, 01010011b
db 00000000b, 01100010b, 01000101b, 01000101b
db 01000110b, 01000110b, 01000110b, 01010010b
db 00000000b, 01000010b, 01010110b, 01111000b
db 01110011b, 00000000b, 01000010b, 01010010b
db 00000000b, 01000010b, 01000101b, 01000110b
db 01000111b, 01010111b, 01000110b, 01010010b
db 01001100b, 01000010b, 01000110b, 01010010b
db 00000000b, 00000000b, 01000010b, 01010010b
db 00000000b, 01100011b, 01101000b, 01000101b
db 01000111b, 01000110b, 01111000b, 01110011b
db 00000000b, 01000010b, 01000101b, 01010010b
db 01001100b, 01000011b, 01001000b, 01010010b
db 00000000b, 00000000b, 01100011b, 01100001b
db 01110001b, 01100001b, 01110011b, 00000000b
db 00000000b, 01100011b, 01100001b, 01110011b
db 00000000b, 01100011b, 01100001b, 01110011b
db 00000000b, 00000000b, 00000000b, 00000000b
db 01001100b, 00000000b, 00000000b, 00000000b
db 00000000b, 00000000b, 01001100b, 00000000b
db 00000000b, 00000000b, 00000000b, 00000000b
db 00000000b, 00000000b, 00000000b, 01000011b
db 01010001b, 01000001b, 01010011b, 00000000b
db 01000011b, 01010001b, 01010001b, 01000001b
db 01010011b, 00000000b, 00000000b, 00000000b
db 00000000b, 00000000b, 00000000b, 01100011b
db 01100001b, 01110001b, 01110011b, 00000000b
db 01100011b, 01100001b, 01100001b, 01110001b
db 01110011b, 00000000b, 00000000b, 00000000b

; =========================================== ENTITIES DATA ====================

EntityCount:
dw 0x0047

EntityData:
db 1, 1
dw 0x0404
db 2, 48
dw 0x0008
dw 0x000a
dw 0x000d
dw 0x000e
dw 0x0013
dw 0x0014
dw 0x0105
dw 0x0113
dw 0x0114
dw 0x0204
dw 0x0206
dw 0x0209
dw 0x020c
dw 0x0212
dw 0x0213
dw 0x0215
dw 0x0308
dw 0x0309
dw 0x030a
dw 0x030b
dw 0x030c
dw 0x0312
dw 0x0313
dw 0x0316
dw 0x031e
dw 0x0409
dw 0x041d
dw 0x0606
dw 0x0706
dw 0x070b
dw 0x0713
dw 0x071d
dw 0x071e
dw 0x071f
dw 0x0807
dw 0x080a
dw 0x080b
dw 0x0813
dw 0x081d
dw 0x081f
dw 0x0906
dw 0x0907
dw 0x090a
dw 0x0917
dw 0x0d07
dw 0x0e08
dw 0x0e16
dw 0x0f17
db 3, 3
dw 0x010c
dw 0x0117
dw 0x071b
db 4, 8
dw 0x001e
dw 0x0107
dw 0x060d
dw 0x0d0a
dw 0x0d0c
dw 0x0d13
dw 0x0e0a
dw 0x0e0b
db 6, 7
dw 0x0410
dw 0x0411
dw 0x0510
dw 0x0511
dw 0x0619
dw 0x0719
dw 0x0a14
db 7, 1
dw 0x0400
db 8, 3
dw 0x081e
dw 0x0e07
dw 0x0e15
db 0x0 ; End of entities

; =========================================== THE END ====================
; Thanks for reading the source code!
; Visit http://smol.p1x.in for more.

Logo:
db "P1X"    ; Use HEX viewer to see P1X at the end of binary