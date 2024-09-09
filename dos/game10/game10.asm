; GAME10 - The X Project
; DOS VERSION
;
; Description:
;   Hi-end terrain rendering 32x24 with meta-tiles
;
; Size category: 2KB
;
; Author: Krzysztof Krystian Jankowski
; Web: smol.p1x.in/assembly/#dinopix
; License: MIT

org 0x100
use16

; =========================================== MEMORY ADDRESSES ===============
_VGA_MEMORY_ equ 0xA000
_DBUFFER_MEMORY_ equ 0x8000
_PLAYER_ENTITY_ID_ equ 0x7000
_REQUEST_POSITION_ equ 0x7002
_ENTITIES_ equ 0x7010

; =========================================== CONSTANTS =======================
BEEPER_ENABLED equ 0x01
BEEPER_FREQ equ 4800
LEVEL_START_POSITION equ 320*60
SPEED_EXPLORE equ 0x12c
COLOR_SKY equ 0x3b3b
COLOR_WATER equ 0x3636

; =========================================== INITIALIZATION ==================
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
    mov word ax, [si+1]         ; Get position
    mov word [di+1], ax         ; Save position

    mov ah, 0x0                ; No mirroring
    cmp al, 0x10               ; Check side of the screen (16 points as middle)
    jl .skip_mirror_x          ; mirror if on the left side
      inc ah                   ; 1 for X mirroring
    .skip_mirror_x:
    mov byte [di+4], ah        ;  Save mirror (0 or 1)

    mov byte al, [si]           ; Get sprite id
    mov byte [di], al             ; Save sprite id
    mov bx, SpriteOffsetTable        ; Get sprite data offset table
    add bl, al                  ; Add sprite id to the offset index
    mov ah, [bx]              ; Get sprite data offset
    mov byte [di+3], ah       ; Save sprite data offset

    mov byte [di+5], 0x01   ; Save basic state

add si, 0x03            ; Move to the next entity in code
add di, 0x06            ; Move to the next entity in memory
loop .next_entitie

mov word [_PLAYER_ENTITY_ID_], _ENTITIES_ ; Set player entity id to first entity

game_loop:
    xor di,di                   ; Clear destination address
    xor si,si                   ; Clear source address

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

  mov ax, 0x7d7c
  mov bx, 160
  mov cx, 24

  .draw_water:
    push cx

    inc ah
    dec al

    and cx, 0x08
    cmp cx, 0x04
    jl .skip_inc
      add bx, 160
      inc ah
      xchg al, ah
    .skip_inc:
      xchg al, ah
      inc al
    mov cx, bx           ; bar size
    rep stosw               ; Write to the doublebuffer
    pop cx                  ; Decrement bar counter

  loop .draw_water

; palloop:
; mov ax,cx
; mov dx,0x3c8
; out dx,al    ; select palette color
; inc dx
; out dx,al    ; write red value (0..63)
; out dx,al    ; write green value (0..63)
; out dx,al    ; write blue value (0..63)
; loop palloop


; =========================================== DRAW TERRAIN =====================

draw_terrain:
  mov di, LEVEL_START_POSITION
  sub di, 32    ; bug?

  mov si, LevelData         ; Load level data (meta-tiles)
  mov cl, 0x20              ; 32 reads, 2 per line - 16 lines
  .draw_meta_tiles:
  push cx
  push si

  dec cx          ; Decrease counter
  shr cx, 0x1     ; Divide by 2
  jnc .no_new_line  ; Check if even, if not - new line
    add di, 320*8-(32*8)  ; Move to the next line
  .no_new_line:

  mov ax, [si]      ; AX - LevelData
  mov cl, 0x4       ; Set up counter for loop (four meta-tiles per line)
  .small_loop:
    push cx

    mov cl, 0x4         ; How many bits to convert
    call convert_value  ; Convert value to bits (save in BX)
    push ax             ; Preserve AX - LevelData

    mov si, MetaTiles   ; Load meta-tiles sets
    mov ax, bx          ; Get meta-tile index
   imul ax, 0x4         ; Multiply inde by 4 (4 bytes per meta-tile)
    add si, ax          ; Move to the meta-tile set
    mov ax, [si]        ; AX - Meta-Tile
    mov cl, 0x4
    .draw_tile:
      push cx
      push si

      mov ax, [si]
      shl ax, 1         ; Cut left bit
      jnc .skip_tile

      mov cl, 0x3           ; How many bits to convert
      call convert_value   ; Convert value to bits (save in BX)

      mov si, bx        ; Get tile index
     imul si, 0x14      ; Multiply index by 20 (20 bytes per tile)
      add si, Tiles       ; Move to the tile set

      mov cl, 0x2           ; How many bits to convert
      call convert_value  ; Convert value to bits (save in BX)

      mov dx, bx      ; Get tile color index
      call draw_sprite

      .skip_tile:

      add di,0x8    ; Move to the next tile position
      pop si
      inc si        ; Move to the next tile index
      pop cx
    loop .draw_tile

    pop ax
    pop cx
  loop .small_loop

  pop si
  inc si          ; Move to the next meta-tile
  inc si          ; 2 bits per meta-tile
  pop cx
loop .draw_meta_tiles

; =========================================== KEYBOARD INPUT ==================
check_keyboard:
  mov ah, 01h         ; BIOS keyboard status function
  int 16h             ; Call BIOS interrupt
  jz .no_key_press           ; Jump if Zero Flag is set (no key pressed)

  mov si, [_PLAYER_ENTITY_ID_]
  mov cx, [si+1]   ; Load player position into CX (Y in CH, X in CL)

  mov ah, 00h         ; BIOS keyboard read function
  int 16h             ; Call BIOS interrupt

  .check_enter:
  cmp ah, 1ch         ; Compare scan code with enter
  jne .check_up
    jmp restart_game

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
    mov byte [si+4], 0x01
    jmp .check_move

  .check_right:
  cmp ah, 4Dh         ; Compare scan code with right arrow
  jne .no_key
    inc cl
    mov byte [si+4], 0x00
    ;jmp .check_move

  .check_move:
  call check_friends
  jz .collision
  call check_water_tile
  jz .collision
  call check_bounds
  jz .collision

  mov word [si+1], cx

  .collision:
  mov word [_REQUEST_POSITION_], cx

  .no_key:
  mov bx, BEEPER_ENABLED
  cmp bx, 0x1
  jnz .no_key_press
    mov bx, BEEPER_FREQ
    add bl, ah
    call set_freq
    call beep
  .no_key_press:

; =========================================== AI ENITIES ===============

ai_entities:
  mov si, _ENTITIES_
  mov cx, [EntityCount]
  .next_entity:
    push cx

    cmp byte [si], 0x3  ; Fish
    jne .skip_entity
      mov byte al, [si+5]   ; State
      and ax, 0x1
      cmp ax, 0x1
      jnz .skip_explore

      rdtsc
      and ax, SPEED_EXPLORE
      cmp ax, SPEED_EXPLORE
      jnz .skip_entity

      .explore:
        mov cx, [si+1]
        call random_move

        call check_bounds
        jz .can_not_move

        call check_friends
        jz .can_not_move

        call check_water_tile
        jz .move_to_new_pos

          mov byte al, [si+5]
          and al, 0x8
          cmp al, 0x8 ; already served
          jz .can_not_move
          mov byte [si+3], 0x0e ; second fish sprite
          mov byte [si+5], 0x02 ; waiting
          jmp .can_not_move
        .move_to_new_pos:
          mov word [si+1], cx
        .can_not_move:

      .skip_explore:
      mov byte al, [si+5]   ; State
      and al, 0x2
      cmp al, 0x2
      jnz .skip_waiting
      .waiting:
      mov word  cx,[si+1]
        cmp word cx, [_REQUEST_POSITION_]
        jne .wait_more
          mov byte [si+3],0x00 ; First fish sprite
          xor byte [si+4],0x01 ; Reverse
          mov byte [si+5],0x09 ; Served
          mov word [_REQUEST_POSITION_], 0x0000
       .wait_more:
      .skip_waiting:

    .skip_entity:
    add si,0x6
    pop cx
  loop .next_entity


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
      mov dx, [si+7]  ; Get Y of next entity

      cmp bh, dh      ; Compare Y values
      jle .no_swap


        mov di, si
        add di, 6

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

        mov cx, 6       ; 6 bytes per entity, so we move 3 words
        .swap_loop:
          mov al, [si]
          xchg al, [di]
          mov [si], al
          inc si
          inc di
          loop .swap_loop
        sub si, 6       ; Reset SI to start of current entity

      .no_swap:
      add si, 6       ; Move to next entity
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

    cmp byte [si+5], 0x0
    jz .skip_entity

    mov cx, [si+1]
    call conv_pos2mem ; Convert position to memory

    movzx bx, byte [si]  ; Get entity type
    imul bx, 0x2
    add di, [SpriteShiftTable + bx]  ; Apply shift based on type

    mov dl, [si+4] ; Get sprite mirror flag
    mov bl, [si+5] ; Get sprite state
    movzx ax, byte [si+3] ; Get sprite data offset
    mov si, EntitiesSpr
    add si, ax          ; Apply offset
    call draw_sprite

    cmp bl, 0x2 ; Waiting for Dino
    jne .skip_caption
      call draw_caption
    .skip_caption:

    cmp bl, 0x10 ; Show source / stash
    jne .skip_source
      call draw_source
    .skip_source:

    .skip_entity:
    pop si
    add si, 0x6
    pop cx
  loop .next

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

; =========================================== SOUND PROCEDURE ==================

disable_speaker:
  mov bx, BEEPER_ENABLED
  cmp bx, 0x1
  jnz .beep_disabled
    in al, 0x61    ; Read the PIC chip
    and al, 0x0FC  ; Clear bit 0 to disable the speaker
    out 0x61, al   ; Write the updated value back to the PIC chip
  .beep_disabled:

; =========================================== ESC OR LOOP =====================

    in al,0x60                  ; Read keyboard
    dec al                      ; Decrement AL (esc is 1, after decrement is 0)
    jnz game_loop               ; If not zero, loop again

; =========================================== TERMINATE PROGRAM ================
  exit:
    mov ax, 0x0003             ; Return to text mode
    int 0x10                   ; Video BIOS interrupt
    ret                       ; Return to DOS

; =========================================== CNVERT XY TO MEM =====================
; Expects: CX - position YY/XX
; Return: DI memory position
conv_pos2mem:
  mov di, LEVEL_START_POSITION
  add di, 320*8+32
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

; =========================================== CHECK WATER TILE ================
; Expects: CX - Player position (CH: Y 0-15, CL: X 0-31)
; Returns: AL - 1 if water (0xF), 0 otherwise
check_water_tile:
    push cx

    mov ax, cx
    shl ah, 2       ; Y * 4
    mov bl, ah      ; add shift to target position
    cmp al, 0x0f    ; check if X is > 15
    jle .no_shift   ; if not, skip
      sub al, 0x10    ; if yes, subtract 16 from X
      add bx, 0x2     ; add 2 to target position
    .no_shift:
    mov dx, [LevelData + bx] ; get target data
    shr al, 0x2     ; X / 4
    inc al
    shl al, 0x2       ; cl * 4
    mov cl, al      ; move X / 4 to cl
    rol dx, cl      ; rotate left by cl
    and dl, 0x0F    ; Check last nibble
    cmp dl, 0x0F    ; Check if it's water (0xF)

    pop cx
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

; =========================================== CHECK FRIEDS =====================
; Expects: CX - Position YY/XX
; Return: AX - Zero if hit bound, 1 if no bunds at this location
check_friends:
  push si
  push cx
  xor bx, bx
  mov ax, cx

  mov cx, [EntityCount]
  mov si, _ENTITIES_
  .next_entity:
    cmp word [si+1], ax
    jnz .different
    inc bx
    .different:
    add si, 0x6
  loop .next_entity

  pop cx
  pop si
  cmp bx,0x1
  jnz .no_friend
  mov ax, 0x0
ret
  .no_friend:
  mov ax, 0x1
ret

; =========================================== CHECK PLAYER =====================
; Expects: CX - Position YY/XX
; Return: AX - Zero if not player, 1 if player at this location
check_player:
   mov ax, [_ENTITIES_+1]

   ; Check Y position
   sub ch, ah
   cmp ch, 2
   ja .not_player

   ; Check X position
   mov al, [_ENTITIES_]
   sub cl, al
   cmp cl, 2
   ja .not_player

   mov ax, 0x1
   ret

.not_player:
   mov ax, 0x0
   ret

; =========================================== DRAW SOURCE =====================
; Expects: DI - memory position
; Return: -
draw_source:
  mov si, CaptionSpr
  sub di, 320*6-2
  mov cx, 0x3
  .next_color:
    add bp, 0xa
    call draw_sprite
    sub di, 320*4
  loop .next_color
ret

; =========================================== DRAW CAPTION =====================
; Expects: DI - memory position
; Return: -
draw_caption:
  xor dx, dx

;  mov si, CaptionSpr
;  sub di, 320*9-2
;  call draw_sprite

;  mov si, IconsSpr
;  add di, 320*4
;  call draw_sprite

  mov si, CaptionSpr
  sub di, 320*14-2
  call draw_sprite
  add di, 320*5-2
  mov bp, 0x8
  call draw_sprite

 ret


; =========================================== SET FREQUENCY =====================
; Set the speaker frequency
; Expects: BX - frequency value
; Return: -
set_freq:
  mov al, 0x0B6  ; Command to set the speaker frequency
  out 0x43, al   ; Write the command to the PIT chip
  mov ax, bx  ; Frequency value for 440 Hz
  out 0x42, al   ; Write the low byte of the frequency value
  mov al, ah
  out 0x42, al   ; Write the high byte of the frequency value
ret

; =========================================== BEEP ============================
; Run the speaker for a short period. Run set_freq first.
; Expects: -
; Return: -
beep:
  in al, 0x61    ; Read the PIC chip
  or al, 0x03    ; Set bit 0 to enable the speaker
  out 0x61, al   ; Write the updated value back to the PIC chip
ret

; =========================================== DRAW SPRITE PROCEDURE ============
; Expects:
; BP - color shift
; DI - positon (linear)
; DX - settings: 00 normal, 01 mirrored x, 10 mirrored y, 11 mirrored x&y
; Return: -
draw_sprite:
    pusha
    mov cx, [si]        ; Get the sprite lines
    inc si
    inc si              ; Mov si to the color data
    add bp, [si]        ; Get the start color of the palette
    inc si
    inc si              ; Mov si to the sprite data
    mov bx, dx
    and bx, 1
    jz .revX3
    add di, 0x7
    .revX3:
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
    xor bp, bp
    ret


; =========================================== CONVERT VALUE ===================
; Expects:
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
; Set of 8x8 tiles for constructing meta-tiles
; Data: number of lines, palette id, lines (8 pixels) of palette indexes

Tiles:

dw 0x8,0x56             ; Dense grass
dw 1010101010101010b
dw 1001101001100110b
dw 1010101010101001b
dw 0110011010011010b
dw 1010101010101010b
dw 0101101001101110b
dw 1010101010101010b
dw 1010011010011010b

dw 0x8,0x56             ; Light grass
dw 1010101010101010b
dw 1010101010101010b
dw 1001101010100110b
dw 1010101010101010b
dw 1010100110101010b
dw 1010101010101010b
dw 1010101001101010b
dw 0110101010101010b

dw 0x8,0x56           ; Right bank
dw 1010100111011111b
dw 1010101001111111b
dw 1001101001111111b
dw 1010101001111111b
dw 1010011001111111b
dw 1010101001111111b
dw 1010101001111111b
dw 1001100111011111b

dw 0x8,0x56           ; Bottom bank
dw 1001101010101001b
dw 1010101010101010b
dw 1010011010011010b
dw 0101101010010111b
dw 1101010101111111b
dw 1111111111111111b
dw 0111111111110100b
dw 0001010101010000b

dw 0x8,0x56           ; Corner
dw 1010100111110100b
dw 1010010111111100b
dw 1010011111111100b
dw 0101111111110100b
dw 1111111111010000b
dw 1111111101000000b
dw 0111110100000000b
dw 0000000000000000b

SpriteOffsetTable:
db 0x6a, 0x22, 0x46, 0x00, 0x58

; Sprite shift table: 320 * shift amount
SpriteShiftTable:
    dw -320*2       ; Type 0: player No shift
    dw -320*10   ; Type 1: Tree (320 * -9)
    dw 0     ; Type 2: Tomb (320 * 3)
    dw 0       ; Type 3: fish No shift
    dw 0       ; Type 4: monkey No shift

EntitiesSpr:          ; Fish Swim  -  0x00
dw 0x5, 0x64
dw 0011010000110100b
dw 1101110111011101b
dw 1111011111100111b
dw 0011111110111110b
dw 1111101011111111b

dw 0x8, 0x64          ; Fish Waiting   - 14 /0xe
dw 0011011100110111b
dw 0001100111011011b
dw 0011011111010111b
dw 0011111001101001b
dw 1110111001101001b
dw 1011111110010100b
dw 1010101111111000b
dw 0010111011101000b

dw 0x10, 0x27         ; Palm Tree - 34 / 0x22
dw 0010101100101011b
dw 1010111010111000b
dw 1000111010101110b
dw 0011101010101000b
dw 0010101011101010b
dw 1010101101101111b
dw 0010110110111011b
dw 0010000111110010b
dw 1011001101100011b
dw 1100001101011000b
dw 1100001011011100b
dw 0000001101011000b
dw 0000100101110000b
dw 0010110101111000b
dw 1011010101011110b
dw 0010111111111000b

dw 0x7,0x15           ; tomb - 70/0x46
dw 0000101010000000b
dw 0010111110010000b
dw 0010111110010000b
dw 0010111010010000b
dw 0000010101000000b
dw 0000000000000000b
dw 0000000000000000b

dw 0x7,0x6e           ; monkey - 84+4/0x58
dw 0010101000000000b
dw 1000000000101000b
dw 0110000010111000b
dw 0001101010010100b
dw 0000101001000000b
dw 0000010100010000b
dw 0001000100010000b

dw 0x8, 0x20          ; dino - 102+4/0x6a
dw 0000011011111100b
dw 0000001010010111b
dw 1100000010101010b
dw 1000001010010000b
dw 0110101010101100b
dw 0001101011100000b
dw 0000001010100000b
dw 0000010000010000b

CaptionSpr:
dw 0x08, 0x15
dw 0011111111111100b
dw 1100111111111111b
dw 1111111111111111b
dw 1111111111111111b
dw 1111111111111111b
dw 0011111111111100b
dw 0000000011110000b
dw 0000000011000000b

; =========================================== META-TILES ======================

MetaTiles:
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
db 00000000b,00000000b,00000000b,00000000b  ; 1101 ???
db 00000000b,00000000b,00000000b,00000000b  ; 1111 empty-filler

; =========================================== LEVEL DATA ======================

LevelData:
dw 1111111111111111b,1111111111111111b
dw 1111000011111111b,1111111111111111b
dw 0010101000111111b,1111111111111111b
dw 0110101001011111b,1111111111111111b
dw 0110101011110000b,1111111111111111b
dw 0110101011111010b,1111111111111111b
dw 0100101010001010b,1000100000111111b
dw 1111011010111010b,1011110001111111b
dw 1111011010111010b,1100101101111111b
dw 1111010010011010b,1001101001011111b
dw 1111111111111010b,1111101011111111b
dw 1111111111110001b,1111101011111111b
dw 1111111111111111b,1111101011111111b
dw 1111111111111111b,1111101011111111b
dw 1111111111111111b,1111000111111111b
dw 1111111111111111b,1111111111111111b

EntityCount:
dw 24

EntityData:
db 0
dw 0x080e
db 1
dw 0x0209
db 1
dw 0x020A
db 3
dw 0x0211
db 1
dw 0x0301
db 1
dw 0x0309
db 1
dw 0x0401
db 1
dw 0x0402
db 3
dw 0x041C
db 1
dw 0x0501
db 1
dw 0x050D
db 1
dw 0x050E
db 2
dw 0x0515
db 2
dw 0x0516
db 1
dw 0x060D
db 2
dw 0x0716
db 2
dw 0x0807
db 2
dw 0x080A
db 4
dw 0x080D
db 2
dw 0x091A
db 3
dw 0x0A02
db 2
dw 0x0A09
db 1
dw 0x0A0D
db 3
dw 0x0E1B

; End of Level Data

Logo:
db "P1X"
; Thanks for reading the source code!
; Visit http://smol.p1x.in for more.