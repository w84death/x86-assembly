; GAME9 - DINOPIX
; DOS VERSION
;
; Description:
;   Dino cook serving food to sea creatures.
;
; Size category: 2KB
;
; Author: Krzysztof Krystian Jankowski
; Web: smol.p1x.in/assembly/#dinopix
; License: MIT

org 0x100
use16

; Memory adresses
_VGA_MEMORY_ equ 0xA000
_DBUFFER_MEMORY_ equ 0x8000
;_CURRENT_LEVEL_ equ 0x7000
_PLAYER_POS_ equ 0x7002
_PLAYER_MEM_ equ 0x7004
_PLAYER_MIRROR_ equ 0x7006
_ENTITIES_ equ 0x7010

; Constants
BEEPER_ENABLED equ 0x0
BEEPER_FREQ equ 4800
LEVEL_START_POSITION equ 320*60
PLAYER_START_POSITION equ 0x080f           ; AH=Y, AL=X
SPEED_EXPLORE equ 0x12c
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
    mov word [_PLAYER_POS_], PLAYER_START_POSITION

; ENTITE
;  0 0x00 - type: 1 player, 1 tree, 2 grass, 3 fish, 4 monkey
; +1 0x0000 - Position YY/XX
; +2 ----
; +3 0x00 - Mirror Y/X
; +4 0x00 - 0 eyes, 0x0c submerged
; +5 0x00 - Status
;    0000 - 0 stopped ; do not drawn
;    0001 - 1 exploring ; draw
;    0010 - 2 waiting for placing order
;    0100 - 4 waiting for food
;    1001 - 9 served, back
;
; NOT IMPLEMENTED YET:
; +6 0x0000 - status timer
; +7 ----
;
spawn_entities:
  mov si, EntityData
  mov di, _ENTITIES_
  mov cx, [EntityCount]
  .next_entitie:

; 0 Player
; 1 Palm Tree - 0x22
; 2 grass - 0x46
; 3 fish swim - 0/0
; 4 monkey - 70/0x3a

; pos
    mov word ax, [si+1]
    mov word [di+1], ax

; mirror
    mov ah,0x0
    cmp al, 0x10
    jl .skip_mirror_x
      inc ah
    .skip_mirror_x:
    mov byte [di+4], ah

; sprite data
    mov byte al, [si]
    mov byte [di],al
    cmp al, 0x01
    jne .n2
      mov al, 0x22
    .n2:
    cmp al, 0x02
    jne .n3
      mov al, 0x46
    .n3:
    cmp al, 0x03
    jne .n4
      mov al, 0x00
    .n4:
     cmp al, 0x04
    jne .n5
      mov al, 0x54
    .n5:

    mov byte [di+3], al

; status
    mov byte [di+5], 0x01

    add si, 0x03
    add di, 0x06
  loop .next_entitie


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
  mov cl, 0x20 ; 20 reads, 2 per line - 16 lines, 32 reads
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
  call conv_pos2mem

  mov word [_PLAYER_MEM_], di

  rdtsc
  shr ax, 0x1
  jnc .skip_jump
  sub di, 320
  .skip_jump:

  mov dx, [_PLAYER_MIRROR_]
  call draw_sprite


; =========================================== KEYBOARD INPUT ==================
check_keyboard:
  mov ah, 01h         ; BIOS keyboard status function
  int 16h             ; Call BIOS interrupt
  jz .no_key_press           ; Jump if Zero Flag is set (no key pressed)

  mov ah, 00h         ; BIOS keyboard read function
  int 16h             ; Call BIOS interrupt


  mov di, [_PLAYER_MEM_]
  add di, 320*4+5
  mov byte al, [_PLAYER_MIRROR_]
  shr al, 1
  jnc .skip_adjust
    sub di, 2
  .skip_adjust:

  .check_enter:
  cmp ah, 1ch         ; Compare scan code with enter
  jne .check_up
    jmp restart_game
  .check_up:
  cmp ah, 48h         ; Compare scan code with up arrow
  jne .check_down
    sub di, 320*6
    call check_water
    jz .no_key
    sub word [_PLAYER_POS_],0x0100


  .check_down:
  cmp ah, 50h         ; Compare scan code with down arrow
  jne .check_left
    add di, 320*6
    call check_water
    jz .no_key
    add word [_PLAYER_POS_],0x0100

  .check_left:
  cmp ah, 4Bh         ; Compare scan code with left arrow
  jne .check_right
    sub di, 8
    call check_water
    jz .no_key
    dec word [_PLAYER_POS_]
    mov byte [_PLAYER_MIRROR_], 0x01

  .check_right:
  cmp ah, 4Dh         ; Compare scan code with right arrow
  jne .no_key
    add di, 6
    call check_water
    jz .no_key
    inc word [_PLAYER_POS_]
    mov byte [_PLAYER_MIRROR_], 0x00

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

        mov cx, [si+1]
        call random_move

        call check_bounds
        cmp ax, 0x1
        jnz .can_not_move

        call check_friends
        cmp ax, 0x1
        jnz .can_not_move

        call conv_pos2mem
        call check_water
        jnz .can_not_move

        .move_to_new_pos:
          mov word [si+1], cx
        .can_not_move:

      .skip_explore:
      mov byte al, [si+5]   ; State
      and ax, 0x2
      cmp ax, 0x2
      jnz .skip_waiting
        call check_player
        cmp ax, 0x0
        jz .wait_more
          mov byte [si+3],0x00
          xor byte [si+4],0x01
          mov byte [si+5],0x09
       .wait_more:
      .skip_waiting:

    .skip_entity:
    add si,0x6
    pop cx
  loop .next_entity

jmp skip_me

ai_entities_old:
  mov cx, [EntityCount]
  mov si, _ENTITIES_
  .next:
    push cx
    ;push si

    cmp byte [si], 0x3  ; Fish
    jne .skip_entity

    mov word cx, [si+1]  ; Pos
    call conv_pos2mem
    ;sub di, 320*4

    cmp byte  [si+4], 1  ; Mirror
    jnz .skip_adjust
      sub di, 2
    .skip_adjust:

    mov byte al, [si+5]   ; State
    and ax, 0x1
    cmp ax, 0x1
    jnz .skip_explore
; EXPLORE
      rdtsc
      and ax, SPEED_EXPLORE
      cmp ax, SPEED_EXPLORE
      jnz .skip_move

        rdtsc
        and ax, 0x3
        cmp ax, 0x3
        jnz .check_y
          sub cl,1
          cmp byte [si+4], 0x01
          jz .skip_right
          add cl, 0x2
          .skip_right:
          jmp .savepos
        .check_y:
        rdtsc
        and ax, 0x10
        cmp ax, 0x10
        jnz .skip_move
          sub ch, 1
          rdtsc
          and ax, 0x1
          jz .skip_down
            add ch, 0x2
          .skip_down:

        .savepos:

          call check_bounds
          cmp ax, 0x1
          jz .is_ok
          cmp byte [si+5], 0x9 ; served, back
          jnz .skip_move
          mov byte [si+5], 0x0 ; disable
          jmp .skip_move
          .is_ok:

          call check_friends
          cmp ax, 0x1
          jnz .skip_move

          call conv_pos2mem
          call check_water
          jnz .skip_save
            mov word [si+1], cx
            jmp .skip_move
        .skip_save:
          ; check if not served yet
          mov byte al, [si+5]
          and al, 0x8
          cmp al, 0x8
          jz .skip_set_wait
          mov byte [si+3],0x0e ; second fish sprite
          mov byte [si+5],0x02 ; waiting
          .skip_set_wait:
          mov word cx, [si+1]
          call conv_pos2mem
          ;sub di, 320*4
        .skip_move:

    .skip_explore:
; WAITING
     cmp byte [si+5], 0x2
     jnz .skip_waiting

       call check_player
       cmp ax, 0x0
       jz .no_player
          mov byte [si+3],0x00
          xor byte [si+4],0x01
          mov byte [si+5],0x09
       .no_player:
    .skip_waiting:

    .skip_entity:
    ;pop si
    add si, 0x6
    pop cx
    dec cx
  jnz .next


;skip_me:

; =========================================== SORT ENITIES ===============


; SORT
; 0, 1, 3, 4, 5
; 6, 7, 9, 10, 11
sort_entities:
  mov dx, [EntityCount]
  dec dx
  mov si, _ENTITIES_
  .sort_loop:
    mov cx, dx
    .next_entitie:
      mov word ax, [si+1]
      mov word bx, [si+7]
      cmp ah, bh
      jle .skip_swap
        mov word [si+1], bx
        mov word [si+7], ax

        mov byte al, [si]
        mov byte bl, [si+6]
        mov byte [si], bl
        mov byte [si+6], al

        mov byte al, [si+3]
        mov byte bl, [si+9]
        mov byte [si+3], bl
        mov byte [si+9], al

        mov byte al, [si+4]
        mov byte bl, [si+10]
        mov byte [si+4], bl
        mov byte [si+10], al

        mov byte al, [si+5]
        mov byte bl, [si+11]
        mov byte [si+5], bl
        mov byte [si+11], al

        .skip_swap:

      add si, 0x6
    loop .next_entitie

skip_me:

; =========================================== DRAW ENITIES ===============
draw_entities:
  mov si, _ENTITIES_
  mov cx, [EntityCount]
  .next:
    push cx
    push si

    cmp byte [si+5], 0x0
    jz .skip_entitie

    mov word cx, [si+1]
    call conv_pos2mem
    ;sub di, 320*4

    mov byte dl, [si+4]
    jnz .skip_adjust
      sub di, 4
    .skip_adjust:

    mov byte bl, [si+5]

    xor ax,ax
    mov byte al, [si+3]
    mov si, EntitiesSpr
    add si, ax
    cmp al, 0x0
    jz .skip_shift
      sub di, 320*4
    .skip_shift:
    call draw_sprite

    and bl, 0x2 ; waiting
    cmp bl, 0x2
    jne .skip_caption
      call draw_caption
    .skip_caption:

    .skip_entitie:
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

disable_speaker:
  mov bx, BEEPER_ENABLED
  cmp bx, 0x1
  jnz .beep_disabled
    in al, 0x61    ; Read the PIC chip
    and al, 0x0FC  ; Clear bit 0 to disable the speaker
    out 0x61, al   ; Write the updated value back to the PIC chip
  .beep_disabled:

; =========================================== ESC OR LOOP =====================

    in al,0x60                           ; Read keyboard
    dec al
    jnz game_loop

; =========================================== TERMINATE PROGRAM ================
exit:
    mov ax, 0x0003
    int 0x10
    ret

; =========================================== CNVERT XY TO MEM =====================
; CX - position YY/XX
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

; CX pos
random_move:
  rdtsc
  and ax, 0x3
  cmp ax, 0x3
  jnz .check_y
    sub cl,1
    cmp byte [si+4], 0x01
    jz .skip_right
      add cl, 0x2
    .skip_right:
  ret
  .check_y:
    rdtsc
    and ax, 0x10
    cmp ax, 0x10
    jnz .skip_move
      sub ch, 1
      rdtsc
      and ax, 0x1
      jz .skip_down
         add ch, 0x2
     .skip_down:
  .skip_move:
ret

; =========================================== CHECK WATER =====================
; DI - memory position to check for water
; Return: Zero if water
check_water:
  mov ax, [es:di]
  mov word [es:di], 0x0 ;DEBUG ONLY
  cmp ax, COLOR_WATER
ret

check_bounds:
; CX - Positin YY/XX
  cmp ch, 0x00
  jl .bound
  cmp ch, 0x0f
  jg .bound
  cmp cl, 0x00
  jl .bound
  cmp cl, 0x20
  jg .bound

  jmp .no_bound

  .bound:
  mov ax, 0x0
ret
  .no_bound:
  mov ax, 0x1
ret

; CX - pos
; Return: AX
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


check_player:
   mov ax, [_PLAYER_POS_]

   cmp ch, ah
   jz .pass_y
   inc ah
   cmp ch, ah
   jz .pass_y
   inc ah
   cmp ch, ah
   jz .pass_y
   mov ax, 0x0
   ret

   .pass_y:

   dec al
   cmp cl, al
   jz .pass_x
   inc al
   cmp cl, al
   jz .pass_x
   inc al
   cmp cl, al
   jz .pass_x

   mov ax, 0x0
   ret
   .pass_x:
   mov ax, 0x1
ret
; =========================================== DRAW CAPTION =====================
; DI - memory position
; Return: -
draw_caption:
  mov si, CaptionSpr
  sub di, 320*13-3
  call draw_sprite

  add di, 320*2
  mov si, IconsSpr
  call draw_sprite
ret

; BX - Frequency
set_freq:
  mov al, 0x0B6  ; Command to set the speaker frequency
  out 0x43, al   ; Write the command to the PIT chip
  mov ax, bx  ; Frequency value for 440 Hz
  out 0x42, al   ; Write the low byte of the frequency value
  mov al, ah
  out 0x42, al   ; Write the high byte of the frequency value
ret

; Run set_freq first
; Start beep
beep:
  in al, 0x61    ; Read the PIC chip
  or al, 0x03    ; Set bit 0 to enable the speaker
  out 0x61, al   ; Write the updated value back to the PIC chip
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
dw 0x8,0x56
dw 1010101010101010b
dw 1001101001100110b
dw 1010101010101001b
dw 0110011010011010b
dw 1010101010101010b
dw 0101101001101110b
dw 1010101010101010b
dw 1010011010011010b


; Light grass
dw 0x8,0x56
dw 1010101010101010b
dw 1010101010101010b
dw 1001101010100110b
dw 1010101010101010b
dw 1010100110101010b
dw 1010101010101010b
dw 1010101001101010b
dw 0110101010101010b


; Right bank
dw 0x8,0x56
dw 1010100111011111b
dw 1010101001111111b
dw 1001101001111111b
dw 1010101001111111b
dw 1010011001111111b
dw 1010101001111111b
dw 1010101001111111b
dw 1001100111011111b

; Bottom bank
dw 0x8,0x56
dw 1001101010101001b
dw 1010101010101010b
dw 1010011010011010b
dw 0101101010010111b
dw 1101010101111111b
dw 1111111111111111b
dw 0111111111110100b
dw 0001010101010000b

; Corner
dw 0x8,0x56
dw 1010100111110100b
dw 1010010111111100b
dw 1010011111111100b
dw 0101111111110100b
dw 1111111111010000b
dw 1111111101000000b
dw 0111110100000000b
dw 0000000000000000b


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

EntitiesSpr:
; Fish Swim  -  0x00
dw 0x5, 0x64
dw 0011010000110100b
dw 1101110111011101b
dw 1111011111100111b
dw 0011111110111110b
dw 1111101011111111b

; Fish Waiting   - 14 /0xe
dw 0x8, 0x64
dw 0011011100110111b
dw 0001100111011011b
dw 0011011111010111b
dw 0011111001101001b
dw 1110111001101001b
dw 1011111110010100b
dw 1010101111111000b
dw 0010111011101000b


; Palm Tree - 34 / 0x22
dw 0x10, 0x27
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

; grass - 70/0x46
dw 0x5,0x2a
dw 0000001110000010b
dw 0010001100001000b
dw 0010111100111011b
dw 1011111111111100b
dw 0000111111110000b

; monkey - 84/0x54
dw 0x7,0x6e
dw 0010101000000000b
dw 1000000000101000b
dw 0110000010111000b
dw 0001101010010100b
dw 0000101001000000b
dw 0000010100010000b
dw 0001000100010000b


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
db 00000000b,00000000b,00000000b,00000000b  ; 1101 ???
db 00000000b,00000000b,00000000b,00000000b  ; 1111 empty-filler

; Custom Level mady in smol.p1x.in/4bitleveleditor

LevelData:
dw 0010001111111111b,1111111100100011b
dw 0100010111111111b,1111111101000101b
dw 1111111111111111b,1111111111111111b
dw 1111111111111111b,1111111111111111b
dw 1111111111110000b,1111111111111111b
dw 1111111111111010b,1111111111111111b
dw 1111111111111010b,1111111111111111b
dw 1111111111111010b,1111111111111111b
dw 1111111111111010b,1111111111111111b
dw 1111111111110001b,1111111111111111b
dw 1111111111111111b,1111111111111111b
dw 1111111111111111b,1111111111111111b
dw 1111111111111111b,1111111111111111b
dw 1111111111111111b,1111111111111111b
dw 0010001111111111b,1111111100100011b
dw 0100010111111111b,1111111101000101b

EntityCount:
dw 15

EntityData:
db 4
dw 0x0000
db 4
dw 0x001F
db 0x3
dw 0x0300
db 3
dw 0x031F
db 2
dw 0x050D
db 2
dw 0x060C
db 1
dw 0x060D
db 2
dw 0x060E
db 2
dw 0x070D
db 2
dw 0x070E
db 4
dw 0x080C
db 3
dw 0x0C00
db 3
dw 0x0C1F
db 4
dw 0x0F00
db 4
dw 0x0F1F


; End of Level Data

Logo:
db "P1X"
; Thanks for reading the source code!
; Visit http://smol.p1x.in for more.