; GAME10 - Mysteries of the Forgotten Isles
; game10.asm
;
; Description:
; Logic 2D game in VGA graphics, w PC Speaker sound.
;
; Size category: 4096 bytes / 4KB
; Bootloader: 512 bytes
; Author: Krzysztof Krystian Jankowski
; Web: smol.p1x.in/assembly/forgotten-isles/
; License: MIT

org 0x100
use16

jmp start

include 'tunes.asm'
include 'brushes.asm'
include 'tiles.asm'
include 'levels.asm'
include 'vectors.asm'
include 'palettes.asm'


BEEP_BITE equ 3
BEEP_PICK equ 15
BEEP_PUT equ 20
BEEP_GOLD equ 5
BEEP_STEP equ 25
BEEP_WEB equ 30

; =========================================== MEMORY ADDRESSES =================

_BASE_ equ 0x2000
_PLAYER_ENTITY_ID_ equ _BASE_ ; 2 bytes
_REQUEST_POSITION_ equ _BASE_ + 0x02 ; 2 bytes
_HOLDING_ID_ equ _BASE_ + 0x04       ; 1 byte
_SCORE_ equ _BASE_ + 0x05            ; 1 byte
_SCORE_TARGET_ equ _BASE_ + 0x06     ; 1 byte
_GAME_TICK_ equ _BASE_ + 0x07        ; 2 bytes
_GAME_STATE_ equ _BASE_ + 0x09       ; 1 byte
_WEB_LOCKED_ equ _BASE_ + 0x0a       ; 1 byte
_LAST_TICK_ equ _BASE_ + 0x0b        ; 2 bytes
_CURRENT_TUNE_ equ _BASE_ + 0x0d     ; 2 bytes
_NEXT_TUNE_ equ _BASE_ + 0x0f        ; 2 bytes
_NOTE_TIMER_ equ _BASE_ + 0x11       ; 1 byte
_NOTE_TEMPO_ equ _BASE_ + 0x12       ; 1 byte
_VECTOR_COLOR_ equ _BASE_ + 0x13     ; 2 bytes
_ENTITIES_ equ 0x1a00         ; 11 bytes per entity, 64 entites cap, 320 bytes

_DBUFFER_MEMORY_ equ 0x3000   ; 64k bytes
_BG_BUFFER_MEMORY_ equ 0x4000 ; 64k bytes
_VGA_MEMORY_ equ 0xA000       ; 64k bytes
_TICK_ equ 1Ah                ; BIOS tick

_ID_ equ 0      ; 1 byte
_POS_ equ 1     ; 2 bytes
_POS_OLD_ equ 3 ; 2 bytes
_SCREEN_POS_ equ 5; 2 bytes
_MIRROR_ equ 7  ; 1 byte
_STATE_ equ 8   ; 1 bytes
_DIR_ equ 9     ; 1 byte
_ANIM_ equ 10    ; 1 byte ; 11 bytes total

; =========================================== MAGIC NUMBERS ====================

ENTITY_SIZE  equ 11
MAX_ENTITIES equ 64
ENTITIES_SPEED equ 2
LEVEL_START_POSITION equ 320*68+32
COLOR_SKY equ 0x3c3c
COLOR_WATER equ 0x3434
SCORE_POSITION equ 320*24+32
INTRO_TIME equ 240
PRE_GAME_TIME equ 64
POST_GAME_TIME equ 32
WEB_LOCK equ 2
COLOR_TRANSPARENT equ 0x0F

ID_PLAYER equ 0
ID_PALM equ 1
ID_SNAKE equ 2
ID_ROCK equ 3
ID_SKULL equ 4
ID_BRIDGE equ 5
ID_CHEST equ 6
ID_GOLD equ 7
ID_SPIDER equ 10
ID_CRAB equ 11
ID_BUSH equ 12

STATE_DEACTIVATED equ 0
STATE_FOLLOW equ 2
STATE_STATIC equ 4
STATE_EXPLORING equ 8
STATE_INTERACTIVE equ 16

GSTATE_INTRO equ 2
GSTATE_PREGAME equ 4
GSTATE_GAME equ 8
GSTATE_POSTGAME equ 16
GSTATE_END equ 32
GSTATE_WIN equ 64
GSTATE_OUTRO equ 128

start:

; =========================================== INITIALIZATION ===================

    mov ax, 0x13         ; Init VGA 320x200x256
    int 0x10             ; Video BIOS interrupt

    mov ax, cs           ; All segments point to the same memory in .COM
    mov ss, ax
    mov sp, 0xFFFE       ; Stack grows downward from near the top of memory

  set_keyboard_rate:
    xor ax, ax
    xor bx, bx
    mov ah, 03h         ; BIOS function to set typematic rate and delay
    mov bl, 1Fh         ; BL = 31 (0x1F) for maximum repeat rate (30 Hz) and 0 delay
    int 16h             ; Call BIOS

restart_game:
  mov word [_GAME_TICK_], 0x0
  mov byte [_GAME_STATE_], GSTATE_INTRO
  mov byte [_SCORE_], 0x0
  mov byte [_HOLDING_ID_], 0x0
  mov byte [_WEB_LOCKED_], 0x0
  mov word [_CURRENT_TUNE_], tune_intro
  mov word [_NEXT_TUNE_], tune_intro           ; loop intro tune
  mov byte [_NOTE_TIMER_], 0x0

; =========================================== SPAWN ENTITIES ==================
; Expects: entities array from level data
; Returns: entities in memory array

spawn_entities:
  mov si, EntityData
  mov di, _ENTITIES_

  .next_entitie:
    mov bl, [si]       ; Get first word (ID)
    cmp bl, 0x0        ; Check for last entity marker
    jz .done

    dec bl             ; Conv level id to game id

    inc si
    mov al, [si]       ; Get amount in group
    inc si             ; mov to the next word (first entitie in group)
    mov cl, al         ; Set loop

    cmp bl, ID_GOLD    ; Check if gold coin
    jnz .not_gold
    mov [_SCORE_TARGET_], cl ; Count each gold as score target
    .not_gold:

    .next_in_group:
      mov byte [di], bl           ; Save sprite id
      mov ax, [si]                ; Get position
      mov [di+_POS_], ax          ; Save position
      mov [di+_POS_OLD_], ax      ; Save old position

      push cx
      push di
      mov cx, ax
      call conv_pos2mem
      mov ax, di
      pop di
      pop cx
      mov [di+_SCREEN_POS_], ax

      mov byte [di+_MIRROR_], 0x0 ;  Save mirror (none)
      mov byte [di+_STATE_], STATE_STATIC ; Save basic state
      mov byte [di+_DIR_], 0x0 ; Save basic state
      mov byte [di+_ANIM_], 0x0

      cmp bl, ID_SNAKE
      jz .set_explore
      cmp bl, ID_CRAB
      jz .set_explore
      cmp bl, ID_SPIDER
      jz .set_explore
      jmp .skip_explore
      .set_explore:   ; Set explore state to alive entities
        mov byte [di+_STATE_], STATE_EXPLORING
      .skip_explore:

      cmp bl, ID_PALM
      jz .set_rand_mirror
      cmp bl, ID_BUSH
      jz .set_rand_mirror
      jnz .skip_mirror
      .set_rand_mirror:  ; Random X mirror, for foliage
        xor al, ah
        and al, 0x01
        mov byte [di+_MIRROR_], al
      .skip_mirror:

      cmp bl, ID_BRIDGE
      jz .set_interactive
      cmp bl, ID_GOLD
      jz .set_interactive
      cmp bl, ID_ROCK
      jz .set_interactive
      cmp bl, ID_CHEST
      jz .set_interactive
      jmp .skip_interactive
      .set_interactive:  ; Set interactive entities
        mov byte [di+_STATE_], STATE_INTERACTIVE
      .skip_interactive:

      add si, 0x02                  ; Move to the next entity in code
      add di, ENTITY_SIZE           ; Move to the next entity in memory
    loop .next_in_group
  jmp .next_entitie
  .done:

mov word [_PLAYER_ENTITY_ID_], _ENTITIES_ ; Set player entity id to first entity


; =========================================== DRAW BACKGROUND ==================

push _BG_BUFFER_MEMORY_
pop es                                  ; as target
xor di,di
xor si,si

draw_bg:
  mov ax, COLOR_SKY               ; Set starting sky color
  mov dl, 0xf                  ; 10 bars to draw
  .draw_sky:
    mov cx, 320*2           ; 3 pixels high
    rep stosw               ; Write to the doublebuffer
    inc ax                  ; Increment color index for next bar
    xchg al, ah             ; Swap colors
    dec dl
    jnz .draw_sky

  .draw_ocean:
    mov ax, COLOR_WATER               ; Set starting sky color
    mov dl, 0x4                  ; 10 bars to draw
    .line:
      mov cx, 320*16          ; 3 pixels high
      rep stosw               ; Write to the doublebuffer
      dec al                  ; Increment color index for next bar
      xchg al, ah             ; Swap colors
      dec dl
      jnz .line

    mov cx, 320*6
    rep stosw

    
; =========================================== GAME LOGIC =======================

game_loop:
  push ds

  push _BG_BUFFER_MEMORY_
  pop ds
  xor si, si

  push _DBUFFER_MEMORY_
  pop es               
  xor di, di

  mov cx, 0x7D00
  rep movsw

  pop ds


; =========================================== INTRO ====================

test byte [_GAME_STATE_], GSTATE_INTRO
jz skip_game_state_intro

  

  call draw_clouds

  
  mov word [_VECTOR_COLOR_], 0x5e5f

  mov ax, [_GAME_TICK_]
  cmp ax, 0xf
  jl .skip_logo_draw

  mov bp, 320*65+80
  mov si, LogoVector
  call draw_vector

  .skip_logo_draw:

  mov word [_VECTOR_COLOR_], 0x7879
  mov si, PalmVector
  mov bp, 320*80
  call draw_vector

  ; mov bp, 320*80+210
  ; call draw_vector

  mov word [_VECTOR_COLOR_], 0x1215
  mov si, P1XVector
  mov bp, 320*150+140
  call draw_vector

  mov ah, 01h         ; BIOS keyboard status function
  int 16h             ; Call BIOS interrupt
  jz .no_key_press
  .start_game:

  mov byte [_GAME_STATE_], GSTATE_PREGAME
  add byte [_GAME_STATE_], GSTATE_GAME
  mov word [_GAME_TICK_], 0x0
  call draw_level
  .no_key_press:

skip_game_state_intro:

; =========================================== PRE-GAME =======================

test byte [_GAME_STATE_], GSTATE_PREGAME
jz skip_game_state_pregame

pre_game:
    mov di, 320*52
    mov ax, [_GAME_TICK_]
    cmp ax, PRE_GAME_TIME
    jg .start_game
    shr ax, 1
    add di, ax
    mov bx, 0x1
    call draw_ship
    jmp skip_game_state_pregame

  .start_game:
    mov byte [_GAME_STATE_], GSTATE_GAME
    mov word [_GAME_TICK_], 0x0

  .clear_kb_buffer:
    mov ah, 0x01
    int 0x16
    jz .cleared
      mov ah, 0x00
      int 0x16
      jmp .clear_kb_buffer

   .cleared:

skip_game_state_pregame:

; =========================================== GAME ====================

test byte [_GAME_STATE_], GSTATE_GAME
jz skip_game_state_game

; =========================================== STOP SOUND ====================
stop_game_sound:
  test byte [_GAME_STATE_], GSTATE_PREGAME
  jnz .skip_stop_sound
  test byte [_GAME_STATE_], GSTATE_POSTGAME
  jnz .skip_stop_sound
    call stop_beep
  .skip_stop_sound:


test byte [_GAME_STATE_], GSTATE_PREGAME
jnz skip_keyboard
test byte [_GAME_STATE_], GSTATE_POSTGAME
jnz skip_keyboard

; =========================================== DRAW SHIP =======================

draw_ship_in_game:
  mov di, 320*52+32
  xor bx, bx
  call draw_ship

; =========================================== KEYBOARD INPUT ==================

check_keyboard:
  mov ah, 01h         ; BIOS keyboard status function
  int 16h             ; Call BIOS interrupt
  jz .no_key_press           ; Jump if Zero Flag is set (no key pressed)

  mov ah, 00h         ; BIOS keyboard read function
  int 16h             ; Call BIOS interrupt

  mov si, [_PLAYER_ENTITY_ID_]
  mov cx, [si+_POS_]   ; Load player position into CX (Y in CH, X in CL)
  mov bx, [si+_POS_OLD_]
  cmp cx, bx
  jnz .no_key_press


  .check_spacebar:
  cmp ah, 39h         ; Compare scan code with spacebar
  jne .check_up
    cmp byte [_HOLDING_ID_], 0x0
    jz .set_request_position_to_player
    mov byte [_HOLDING_ID_], 0x0
    jmp .no_key_press
    .set_request_position_to_player:
      mov word [_REQUEST_POSITION_], cx
    jmp .no_key_press
  .check_up:
  cmp ah, 48h         ; Compare scan code with up arrow
  jne .check_down
    cmp ch, 0x0
    jz .invalid_move
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
    ; cmp cl, 0x0
    ; jz .invalid_move
    dec cl
    mov byte [si+_MIRROR_], 0x1
    jmp .check_move


  .check_right:
  cmp ah, 4Dh         ; Compare scan code with right arrow
  jne .no_key_press
    inc cl
    mov byte [si+_MIRROR_], 0x0
    ;jmp .check_move

  .check_move:
    call check_friends
    jz .no_move
    call check_water_tile
    jz .no_move
    call check_bounds
   jz .no_move

    .move:
    cmp byte [_WEB_LOCKED_], 0
    jz .skip_web_check
      dec byte [_WEB_LOCKED_]
      mov bl, BEEP_WEB
      call beep
      jmp .no_move
    .skip_web_check:
    mov word [si+_POS_], cx
    mov bl, BEEP_STEP
    call beep

    .no_move:
    mov word [_REQUEST_POSITION_], cx

  .no_key_press:
  .invalid_move:

skip_keyboard:

; =========================================== AI ENITIES ===============

ai_entities:
  mov si, _ENTITIES_
  mov cl, MAX_ENTITIES
  .next_entity:
    push cx

    cmp byte [si+_STATE_], STATE_EXPLORING
    jnz .skip_explore

    mov ax, [si+_POS_]
    mov bx, [si+_POS_OLD_]
    cmp ax, bx
    jnz .skip_explore

      .explore:
        mov cx, [si+_POS_]
        mov al, [si+_DIR_]

        .check_horizontal:
        cmp al, 0
        jnz .go_left
        .go_right:
           inc cl
           jmp .check_mirror
        .go_left:
         cmp al, 1
         jnz .check_vertical
           dec cl
           jmp .check_mirror

        .check_vertical:
        cmp al, 2
        jnz .go_up
        .go_down:
          inc ch
          jmp .check_mirror
        .go_up:
         cmp al, 3
         jnz .check_mirror
           dec ch

        .check_mirror:
          mov byte [si+_MIRROR_], 0x0
          cmp byte cl, [si+_POS_]
          jg .skip_mirror_x
          mov byte [si+_MIRROR_], 0x1
          .skip_mirror_x:

        call check_bounds
        jz .can_not_move

        call check_friends
        jz .can_not_move

        call check_water_tile
        jz .can_not_move

        .move_to_new_pos:
          mov word [si+_POS_], cx
          jmp .after_move

        .can_not_move:

        .check_if_crab:
        cmp byte [si+_ID_], ID_CRAB
        jnz .not_a_crab
          xor byte [si+_DIR_], 1
          jmp .skip_random_bounce
        .not_a_crab:

        .random_bounce:
           in al, 0x40
           add ax, [_GAME_TICK_]
           and al, 0x3
           mov byte [si+_DIR_], al

        .skip_random_bounce:

        .check_if_player:
          cmp cx, [_REQUEST_POSITION_]
          jnz .no_bite
            cmp byte [_HOLDING_ID_], 0x0
            jnz .continue_game
              mov byte [_HOLDING_ID_], 0xff
              mov bl, BEEP_BITE
              call beep

              cmp byte [si+_ID_], ID_SNAKE
              jz .snake_bite
              cmp byte [si+_ID_], ID_SPIDER
              jz .spider_web
              cmp byte [si+_ID_], ID_CRAB
              jz .crab_bite
              jmp .continue_game

              .crab_bite:                 ; Crab
              .snake_bite:                ; Snake
              mov byte [_GAME_STATE_], GSTATE_END
              mov word [_CURRENT_TUNE_], tune_end
              mov word [_NEXT_TUNE_], tune_end
              mov byte [_NOTE_TIMER_], 0x0
              mov byte [_NOTE_TEMPO_], 0xa
              jmp .skip_item

              .spider_web:                ; Spider
                  mov byte [_WEB_LOCKED_] , WEB_LOCK
              jmp .continue_game

            .continue_game:
              mov byte [_HOLDING_ID_], 0x00
              jmp .skip_item
          .no_bite:
          .after_move:
    .skip_explore:

    cmp byte [si+_STATE_], STATE_INTERACTIVE
    jnz .skip_item
      mov cx, [si+_POS_]
      cmp cx, [_REQUEST_POSITION_]
      jnz .skip_item

      cmp byte [si+_ID_], ID_BRIDGE
      jz .check_bridge
      cmp byte [si+_ID_], ID_CHEST
      jnz .skip_check_interactions

      .check_interactions:
        cmp byte [_HOLDING_ID_], ID_GOLD
        jnz .skip_item
        inc byte [_SCORE_]
        mov bl, BEEP_GOLD
        call beep
        jmp .clear_item

      .check_bridge:
        cmp byte [_HOLDING_ID_], ID_ROCK
        jnz .skip_item
        mov byte [si+_STATE_], STATE_DEACTIVATED
      .clear_item:
          mov byte [_HOLDING_ID_], 0xff
          jmp .skip_item
      .skip_check_interactions:

      cmp byte [_HOLDING_ID_], 0x0  ; Check if player is holding something
      jnz .skip_item
      .pick_item:
        mov byte [si+_STATE_], STATE_FOLLOW
        mov word [_REQUEST_POSITION_], 0x0
        mov byte cl, [si+_ID_]
        mov byte [_HOLDING_ID_], cl
        mov bl, BEEP_PICK
        call beep
    .skip_item:

    .put_item_back:
    cmp byte [si+_STATE_], STATE_FOLLOW
    jnz .no_follow

      cmp byte [_HOLDING_ID_], 0x0
      jnz .check_kill
        mov byte [si+_STATE_], STATE_INTERACTIVE
        mov word [_REQUEST_POSITION_], 0x0
        jmp .beep

      .check_kill:
      cmp byte [_HOLDING_ID_], 0xff
      jnz .skip_kill
        mov byte [si+_STATE_], STATE_DEACTIVATED
        mov byte [_HOLDING_ID_], 0x0
      .beep:
      mov bl, BEEP_PUT
      call beep
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
  mov cl, MAX_ENTITIES-1  ; We'll do n-1 passes
  .outer_loop:
    push cx
    mov si, _ENTITIES_

    .inner_loop:
      push cx
      mov bx, [si+_POS_]  ; Get Y of current entity
      mov dx, [si+ENTITY_SIZE+_POS_]  ; Get Y of next entity

      cmp bh, dh      ; Compare Y values
      jle .no_swap

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

        mov cx, ENTITY_SIZE
        .swap_loop:
          mov al, [si]
          xchg al, [di]
          mov [si], al
          inc si
          inc di
          loop .swap_loop
        sub si, ENTITY_SIZE

      .no_swap:
      add si, ENTITY_SIZE
      pop cx
      loop .inner_loop

    pop cx
    loop .outer_loop

; =========================================== DRAW ENITIES ===============

draw_entities:
  mov si, _ENTITIES_
  mov cl, MAX_ENTITIES
  .next:
    push cx
    push si

    cmp byte [si+_STATE_], STATE_DEACTIVATED
    jz .skip_entity

    test byte [_GAME_STATE_], GSTATE_PREGAME
    jnz .hide_player
    test byte [_GAME_STATE_], GSTATE_POSTGAME
    jnz .hide_player
    jmp .skip_hide_player
    .hide_player:
      cmp byte [si+_ID_], ID_PLAYER
      jz .skip_entity
      cmp byte [si+_ID_], ID_CHEST
      jz .skip_entity
    .skip_hide_player:

    ; smooth move here
    mov ax, [si+_POS_OLD_]
    mov cx, [si+_POS_]
    cmp cx, ax
    jz .in_position

       xor bx, bx

       cmp al, cl
       jl .move_left
       jg .move_right
       cmp ah, ch
       jl .move_down
       jg .move_up

       jmp .in_position

        .move_left:
        add bx, ENTITIES_SPEED
        jmp .save_move

        .move_right:
        sub bx, ENTITIES_SPEED
        jmp .save_move

        .move_down:
        add bx, 320*ENTITIES_SPEED
        jmp .save_move

        .move_up:
        sub bx, 320*ENTITIES_SPEED
        jmp .save_move

       .save_move:
       mov cx, [si+_POS_]
       call conv_pos2mem
       mov dx, di
       add [si+_SCREEN_POS_], bx
       mov di, [si+_SCREEN_POS_]
       cmp dx, di
       jnz .pos_calculated
       mov cx, [si+_POS_]
       mov [si+_POS_OLD_], cx
       mov byte [si+_ANIM_], 0x0
       cmp byte [si+_ID_], ID_PLAYER
       jnz .skip_step_beep
       mov bl, BEEP_STEP
       call beep
       .skip_step_beep:


    .in_position:
    call conv_pos2mem  ; screen pos in DI
    .pos_calculated:
    cmp byte [si+_STATE_], STATE_FOLLOW
    jnz .skip_follow
      push si
      mov si, [_PLAYER_ENTITY_ID_]
      mov cx, [si+_POS_]   ; Load player position into CX (Y in CH, X in CL)
      mov di, [si+_SCREEN_POS_]
      sub di, 320*14          ; Move above player
      pop si
      mov word [si+_POS_], cx ; Save new position to holding item
      jmp .skip_draw_shadow
    .skip_follow:


    .draw_shadow:
    test byte [si+_STATE_], STATE_EXPLORING
    jnz .skip_draw_shadow
    cmp byte [si+_ID_], ID_PLAYER
    jz .skip_draw_shadow
    cmp byte [si+_ID_], ID_BRIDGE
    jz .skip_draw_shadow
    push si
    push di
    mov si, ShadowBrush
    add di, 320*5+1
    call draw_sprite
    pop di
    pop si
    .skip_draw_shadow:

    mov byte al, [si]       ; Get brush id in AL
    mov ah, al              ; Save a copy in AH

    shl al, 0x2
    mov bx, BrushRefs       ; Get brush reference table
    add bl, al              ; Shift to ref (id*2 bytes)
    mov dx, [bx]            ; Get brush data address

    push dx                 ; Save address for SI

    add al, 0x2               ; offest is at next byte (+2)
    movzx bx, al              ; Get address to BX
    add di, [BrushRefs + bx]  ; Get shift and apply to destination position
    mov dl, [si+_MIRROR_]     ; Get brush mirror flag

    cmp ah, ID_PLAYER
    jnz .skip_player_anim
      mov ax, [si+_POS_]
      cmp ax, [si+_POS_OLD_]
      mov ah, ID_PLAYER
      jz .skip_player_anim
        xor byte [si+_ANIM_], 0x1
    .skip_player_anim:

    mov dh, [si+_ANIM_]       ; Get anination frame

    pop si                  ; Get address
    call draw_sprite

    cmp ah, ID_PLAYER
    jnz .skip_player_draw
      mov si, IndieTopBrush
      sub di, 320*4

      cmp dh, 0x1       ; move head down on second frame
      jnz .skip_anim_move
        add di, 320
      .skip_anim_move:

      cmp byte [_HOLDING_ID_], 0x0
      jz .skip_player_holding
         mov si, IndieTop2Brush
      .skip_player_holding:

      xor dh, dh
      call draw_sprite

      cmp byte [_WEB_LOCKED_], 0
      jz .skip_web_draw
        mov si, WebBrush
        add di, 320*6
        call draw_sprite
      .skip_web_draw:
    .skip_player_draw:

    cmp ah, ID_GOLD
    jnz .skip_gold_draw
      mov ax, [_GAME_TICK_]
      add ax, cx
      and ax, 0x4
      cmp ax, 0x2
      jl .skip_gold_draw
      xor dx, dx ; no mirror
      mov si, GoldBrush
      call draw_sprite
    .skip_gold_draw:

    cmp ah, ID_CRAB
    jnz .skip_crab
      mov dx, 0
      mov si, CrabClawBrush
      add di, 8
      call draw_sprite
      mov dx, 1
      sub di, 320+16
      call draw_sprite
    .skip_crab:

    cmp ah, ID_CHEST
    jnz .skip_chest
     xor dx,dx
      cmp byte [_HOLDING_ID_], ID_GOLD
      jnz .skip_open_chest
        mov si, ChestTopBrush
        sub di, 320*3+8
        call draw_sprite

        mov si, ArrowBrush
        sub di, 320*8-8
        mov ax, [_GAME_TICK_]
        and ax, 0x1
        imul ax, 320*2
        add di, ax
        call draw_sprite
        jmp .skip_chest
        .skip_open_chest:
            mov si, ChestCloseBrush
            sub di, 320
            call draw_sprite
    .skip_chest:

    .skip_entity:
    pop si
    add si, ENTITY_SIZE
    pop cx
    dec cx
  jg .next

skip_draw_entities:

  call draw_clouds

; =========================================== CHECK SCORE =======================

test byte [_GAME_STATE_], GSTATE_PREGAME
jnz skip_score
test byte [_GAME_STATE_], GSTATE_POSTGAME
jnz skip_score

check_score:
  mov di, SCORE_POSITION
  mov al, [_SCORE_TARGET_]
  mov ah, [_SCORE_]
  cmp al, ah
  jg .continue_game
    add byte [_GAME_STATE_], GSTATE_POSTGAME
    mov word [_GAME_TICK_], 0x0
    mov word [_CURRENT_TUNE_], tune_win
    mov word [_NEXT_TUNE_], tune_win
    mov byte [_NOTE_TIMER_], 0x0
    mov byte [_NOTE_TEMPO_], 0x2
  .continue_game:

; =========================================== DRAW SCORE ========================

draw_score:
  xor cl, cl
  .draw_spot:
      mov si, SlotBrush
      call draw_sprite
      cmp cl, ah
      jge .skip_gold_draw
        mov si, GoldBrush
        call draw_sprite
      .skip_gold_draw:
    add di, 0xa
    inc cl
    cmp al, cl
  jnz .draw_spot

skip_score:
skip_game_state_game:


; =========================================== POST GAME =========================

test byte [_GAME_STATE_], GSTATE_POSTGAME
jz skip_game_state_postgame
draw_post_game:
  mov ax, [_GAME_TICK_]
  shr ax, 1
  cmp ax, POST_GAME_TIME
  jnz .move_ship
    mov byte [_GAME_STATE_], GSTATE_END+GSTATE_WIN
  .move_ship:
  mov di, 320*52+32
  add di, ax
  mov bx, 0x1
  call draw_ship
  ; call play_tune


skip_game_state_postgame:

; =========================================== GAME END ==========================

test byte [_GAME_STATE_], GSTATE_END
jz skip_game_state_end
  ; call play_tune
  mov di, 320*100+154
  mov si, SkullBrush
  test byte [_GAME_STATE_], GSTATE_WIN
  jz .draw_icon
  mov si, GoldBrush
  .draw_icon:
  call draw_sprite
skip_game_state_end:

; =========================================== VGA BLIT PROCEDURE ===============

vga_blit:
    push es
    push ds

    push _VGA_MEMORY_                     ; Set VGA memory
    pop es                                  ; as target
    push _DBUFFER_MEMORY_                 ; Set doublebuffer memory
    pop ds                                  ; as source
    xor si,si                               ; Clear SI
    xor di,di                               ; Clear DI
    
    mov cx,0x7D00                           ; Half of 320x200 pixels
    rep movsw                               ; Push words (2x pixels)

    pop ds
    pop es


; =========================================== GAME TICK ========================

wait_for_tick:
    xor ax, ax          ; Function 00h: Read system timer counter
    int _TICK_          ; Returns tick count in CX:DX
    mov bx, dx          ; Store the current tick count
.wait_loop:
    int _TICK_          ; Read the tick count again
    cmp dx, bx
    je .wait_loop       ; Loop until the tick count changes

inc word [_GAME_TICK_]  ; Increment game tick

; =========================================== ESC OR LOOP ======================

  in al, 0x60                  ; Read keyboard
  dec al                      ; Decrement AL (esc is 1, after decrement is 0)
  jnz game_loop               ; If not zero, loop again

; =========================================== TERMINATE PROGRAM ================

  exit:

; =========================================== BEEP STOP ========================

  call stop_beep
  mov ax, 0x4c00
  int 0x21
  ret                       ; Return to BIOS/DOS


; =========================================== BEEP PC SPEAKER ==================
; Set the speaker frequency
; Expects: BX - frequency value
; Return: -

beep:
  ;xor bh, bh
  mov al, 0xB6  ; Command to set the speaker frequency
  out 0x43, al   ; Write the command to the PIT chip
  mov ah, bl    ; Frequency value
  out 0x42, al   ; Write the low byte of the frequency value
  mov al, ah
  out 0x42, al   ; Write the high byte of the frequency value
  in al, 0x61    ; Read the PIC chip
  or al, 0x03    ; Set bit 0 to enable the speaker
  out 0x61, al   ; Write the updated value back to the PIC chip
ret

stop_beep:
  in al, 0x61    ; Read the PIC chip
  and al, 0x0FC  ; Clear bit 0 to disable the speaker
  out 0x61, al   ; Write the updated value back to the PIC chip
ret

; =========================================== PLAY TUNE ========================
play_tune:
  cmp byte [_NOTE_TIMER_], 0x0
  jz .new_note
    dec byte [_NOTE_TIMER_]
    jmp .done
  .new_note:
    inc word [_CURRENT_TUNE_]
    mov si, [_CURRENT_TUNE_]
    mov bl, [si]
    cmp bl, 0
    jnz .skip_loop
      mov ax, [_NEXT_TUNE_]
      mov word [_CURRENT_TUNE_], ax     ; Loop to begining of the tune
      mov si, ax
      mov bl, [si]
    .skip_loop:
    mov byte al, [_NOTE_TEMPO_]
    mov byte [_NOTE_TIMER_], al
    call beep
  .done:
ret

draw_clouds:
  mov word [_VECTOR_COLOR_], 0x5456
  mov bp, [_GAME_TICK_]
  shr bp, 4
  mov si, CloudsVector
  call draw_vector
ret
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

; =========================================== CHECK BOUNDS =====================
; Expects: CX - Position YY/XX (CH: Y coordinate, CL: X coordinate)
; Returns: AX - Zero if hit bound, 1 if no bounds at this location

check_bounds:
  xor ax, ax             ; Assume bound hit (AX = 0)
  cmp ch, 0x0f
  ja .return
  cmp cl, 0x1f
  ja .return
  inc ax                 ; No bound hit (AX = 1)
.return:
  test ax, 1             ; Set flags based on AX
  ret

; =========================================== CHECK FRIEDS =====================
; Expects: CX - Position YY/XX
;         DL - skip check
; Return: AX - Zero if hit entity, 1 if clear

check_friends:
  push si
  push cx
  xor bx, bx
  mov ax, cx

  mov cx, MAX_ENTITIES
  mov si, _ENTITIES_
  .next_entity:
    cmp byte [si+_STATE_], STATE_FOLLOW
    jle .skip_this_entity
    cmp word [si+_POS_], ax
    jz .hit
    .skip_this_entity:
    add si, ENTITY_SIZE
  loop .next_entity

  jmp .done

  .hit:
  mov bx, 0x1
  cmp bx, 0x1

  .done:
  pop cx
  pop si

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


; =========================================== DRAWING LEVEL ====================
draw_level:
  push es
  push _BG_BUFFER_MEMORY_
  pop es                                  ; as target

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
  
  pop es
ret


; =========================================== DRAWING SHIP ====================
; in: bx - wiosla

draw_ship:
  xor dx, dx

  mov ax, [_GAME_TICK_]
  and ax, 0xf
  cmp ax, 0x6
  jl .skip_wave
    sub di, 320
  .skip_wave:
  mov si, ShipBackBrush
  call draw_sprite
  add di, 8 + 320*4
  mov si, ShipMiddleBrush
  call draw_sprite
  add di, 8
  mov si, ShipMiddleBrush
  call draw_sprite
  add di, 8
  mov si, ShipFrontBrush
  call draw_sprite

  mov si, ShipSailBrush
  sub di, 12 + 320*5
  call draw_sprite
  add di, 320*2 - 4
  call draw_sprite
  sub di, 320*7 - 3
  call draw_sprite
  add di, 320*2 - 4
  call draw_sprite
  sub di, 320*6 - 1
  call draw_sprite

  add di, 320*10 + 10
  call draw_sprite
  sub di, 320*4 + 2
  call draw_sprite

  cmp bx, 0x1
  jnz .skip_wiosla
  xor dx, dx
  mov ax, [_GAME_TICK_]
  shr ax, 3
  and ax, 0x1
  add dl, al
  sub di, ax
  sub di, ax
  sub di, ax
  mov si, WioslaBrush
  add di, 320*15-7
  call draw_sprite
  add di, 8
  call draw_sprite
  .skip_wiosla:
ret

; =========================================== DRAW VECTOR ======================
draw_vector:   
  pusha 
  .read_group:
    xor cx, cx
    mov cl, [si]
    cmp cl, 0x0
    jz .done

    inc si

    .read_line:
    push cx

    xor ax, ax
    mov al, [si]
    add ax, bp

    xor bx, bx
    mov bl, [si+2]
    add bx, bp
    mov dl, [si+1]
    mov dh, [si+3]
    mov cx, 0x1814  ; shadow color


    ; shadow
    call draw_line
    
    mov cx, [_VECTOR_COLOR_]  ; line color
    dec ax
    dec bx
    sub dh, 0x2
    sub dl, 0x2    
    call draw_line

    ; double line
    dec cl
    dec ch
    inc ax
    inc bx
    call draw_line

    add si, 2
    pop cx
    loop .read_line
    add si, 2
    jmp .read_group
  .done:
  popa
  ret

; =========================================== DRAWING LINE ====================
; ax=x0
; bx=x1
; dl=y0,
; dh=y1,
; cl=col
; Spektre @ https://stackoverflow.com/questions/71390507/line-drawing-algorithm-in-assembly#71391899
draw_line:
  pusha       
    push    ax
    mov si,bx
    sub si,ax
    sub ah,ah
    mov al,dl
    mov bx,ax
    mov al,dh
    sub ax,bx
    mov di,ax
    mov ax,320
    sub dh,dh
    mul dx
    pop bx
    add ax,bx
    mov bp,ax
    mov ax,1
    mov bx,320
    cmp si,32768
    jb  .r0
    neg si
    neg ax
 .r0:    cmp di,32768
    jb  .r1
    neg di
    neg bx
 .r1:    cmp si,di
    ja  .r2
    xchg    ax,bx
    xchg    si,di
 .r2:    mov [.ct],si
 .l0:    mov word [es:bp], cx
    add bp,ax
    sub dx,di
    jnc .r3
    add dx,si
    add bp,bx
 .r3:    dec word [.ct]
    jnz .l0
    popa
    ret
 .ct:    dw  0


; =========================================== DRAW SPRITE PROCEDURE ============
; Expects:
; DI - positon (linear)
; DL - settings: 0 normal, 1 mirrored x, 2 mirrored y, 3 mirrored x&y
; DH - frame number
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

  movzx ax, dh  ; Get frame
 imul ax, cx    ; muliply by lines
  shl ax, 0x1   ; *2 bytes per line
  add si, ax    ; Mobe to the frame memory position

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

          rol ax, 2
          mov bx, ax
          and bx, 0x3

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

; =========================================== THE END ==========================
; Thanks for reading the source code!
; Visit http://smol.p1x.in for more.


Logo:
db "P1X"    ; Use HEX viewer to see P1X at the end of binary
