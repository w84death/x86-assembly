; GAME6 - BIT OF A TREASURE
; Description:
;   Logic game with isometric perspective.
;   Collect the treasure and avoid the walls.
;   Swap level designs to find the best path.
;
; Controls:
;   Arrow keys - move the player
;   Enter - toggle level designs (4 in total)
;   ESC - restart the game after failed move
;
;   The game is written in x86 assembly language and runs in 16-bit real mode.
;   The game uses VGA 320x200x256 colors mode, doublebuffering.
;   Minimum CPU is Intel 386.
;
; Author: Krzysztof Krystian Jankowski
; Date: 2024-06/15 -> 06/16
; License: MIT

use16                                     ; 16-bit mode
org 0x100                                  ; Boot sector origin
;cpu 386                                     ; Minimum CPU is Intel 386

; =========================================== MEMORY ===========================

VGA_MEMORY_ADR equ 0xA000                   ; VGA memory address
DBUFFER_MEMORY_ADR equ 0x8000               ; Doublebuffer memory address
SCREEN_BUFFER_SIZE equ 0xFA00               ; Size of the VGA buffer size
TIMER equ 0x046C                            ; BIOS timer

BASE_MEM equ 0x7e00                         ; Base memory address
; LIFE equ BASE_MEM+0x00                      ; Number of lifes,1 byte
LEVEL equ BASE_MEM+0x01                     ; Current level,2 bytes
PLAYER_POS equ BASE_MEM+0x03                ; Ship position,2 bytes
PLAYER_TIMER equ BASE_MEM+0x05              ; Movement timer,2 bytes
PLAYER_DIR equ BASE_MEM+0x07                ; Ship direction,1 byte
LEVEL_DATA equ BASE_MEM+0x08                ; Level data,512 bytes

; =========================================== MAGIC NUMBERS ====================

SCREEN_WIDTH equ 320                        ; VGA 13h Resolution:
SCREEN_HEIGHT equ 200                       ; 320x200 pixels
SCREEN_CENTER equ SCREEN_WIDTH*SCREEN_HEIGHT/2+SCREEN_WIDTH/2 ; Center

LEVEL_START_POS equ 168+320*40              ; Level start position
PLAYER_START_POS equ LEVEL_START_POS+320*10-14      ; Player start position
TREASURE_START_POS equ LEVEL_START_POS+320*114-14   ; Treasure start position
SPRITE_SIZE equ 8                           ; 8 pixels per sprite line
SPRITE_LINES equ 8                          ; 8 lines per sprite
LEVEL_COLS equ 16                           ; 16 columns per level
LEVEL_ROWS equ 16                           ; 16 rows per level

COLOR_BACKGROUND equ 0x999b                 ; Color for background
COLOR_TILE_MOVABLE equ 0x58                 ; Color for movable tile
COLOR_TILE_NONMOVABLE equ 0x7e              ; Color for non-movable tile
COLOR_TILE_WALL equ 0x36                    ; Color for shaded wall tile
COLOR_TILE_WALL_LIGH equ 0x35               ; Color for wall tile
COLOR_BALL_MAIN equ 0x3d                    ; Color for the player ball
COLOR_BALL_LIGH equ 0x6c                    ; Color for shading the ball
COLOR_BALL_DEAD equ 0x30                    ; Color for dead ball
COLOR_TREASURE equ 0x5a                     ; Color for the treasure





; =========================================== BOOTSTRAP ========================

_start:
    ;xor ax,ax                               ; Clear AX
    ;mov ds,ax                               ; Set DS to 0
    mov ax,0x13                             ; Init VGA 320x200x256
    int 0x10                                ; Video BIOS interrupt

    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop es                                  ; as target

; =========================================== LEVEL DESIGNS ====================

create_levels:
    mov ax,0x1337                           ; Seed for random number
    mov bx,0xabcd                           ; Second seed
    mov cx,0x80                             ; Number of level lines (64)
    .fill_line:
        add bx,di                           ; Change second seed with line number
        ror ax,4                            ; Rotate first seed
        xor ax,bx                           ; XOR with second seed
        mov word [LEVEL_DATA+di],ax         ; Store the procedural level line
        inc di                              ; Move to the next line
        loop .fill_line

; =========================================== GAME LOOP ========================

restart_game:
    mov word [LEVEL],0x00                   ; Reset level
    mov word [PLAYER_POS],PLAYER_START_POS  ; Reset player position
    mov byte [PLAYER_TIMER],0x00            ; Reset player timer

; =========================================== REAL-TIME GAME LOOP ==============

game_loop:

; =========================================== DRAW BACKGROUND ==================

draw_bg:
    mov ax,COLOR_BACKGROUND                 ; Set background color (2 bytes)
    mov cx,SCREEN_BUFFER_SIZE               ; Set buffer size to fullscreen
    rep stosw                               ; Fill the buffer with color

draw_level_indicator:
    mov cx,[LEVEL]                          ; Get current level number
    inc cx                                  ; Increment by 1 to avoid 0
    mov bx,COLOR_TILE_MOVABLE               ; Set sprite color
    mov si,tiles+8                          ; Set sprite data addr (right tile)
    .draw_icon:
        call draw_sprite
        add di,12                           ; Move 12px right for next icon
        loop .draw_icon

; =========================================== DRAW LEVEL =======================

draw_level:
    mov si,LEVEL_DATA                       ; Set level data address
    mov ax,[LEVEL]                          ; Get current level for offset
    mov bx,0x20                             ; Level data offset
    mul bx                                  ; Multiply by offset
    add si,ax                               ; Add current level offset
    mov dx,LEVEL_ROWS                       ; Number of rows in the level
    mov di,LEVEL_START_POS                  ; Set level start position
    .draw_row:
        mov ax,[si]                         ; Get level row data
        mov cx,LEVEL_COLS                   ; 16 bits per row
        .draw_tile_box:
            shl ax,1                        ; Shift left to get the tile out
            jc .color_non_movable           ; If carry flag is 0,draw ground
                mov bx,COLOR_TILE_MOVABLE   ; Set sprite color
                jmp .draw_the_tile          ; Skip to draw the tile
            .color_non_movable:
                mov bx,COLOR_TILE_NONMOVABLE; Set sprite color
            .draw_the_tile:
            push si
            xor si,si                       ; Set sprite ID to 0
            add di,320*4-17                 ; Isometric offset
            call draw_tile
            pop si

            inc di                          ; Move to the next tile position
            loop .draw_tile_box
        inc si
        inc si                              ; Shift source by 2 bytes
    add di,-320*60+136                      ; Move to the next row,iso offset
    dec dx                                  ; Decrement row count
    jnz .draw_row                           ; Draw the next row

; =========================================== DRAW TREASURE ====================

draw_treasure:
    xor bx,bx                               ; Set color to black
    mov si,treasure_sprite                  ; Set sprite data address
    mov word di,TREASURE_START_POS          ; Set sprite position
    call draw_sprite                        ; Draw rigth silhouette
    dec di
    dec di                                  ; Move 2px left
    call draw_sprite                        ; Draw left silhouette
    inc di                                  ; Move 1px right (centered)
    mov bx,COLOR_TREASURE                   ; Set color to treasure
    call draw_sprite                        ; Draw treasure

; =========================================== CHECK COLLISIONS ==============

check_collisions:
    mov si,[PLAYER_POS]                     ; Get player position
    add si,320*4+5                          ; Move raycast to center
    mov al,[es:si]                          ; Get pixel color at raycast
    cmp al,COLOR_TREASURE                   ; Check if it matches treasure color
    je .collision_treasure                  ; Jump if collision with treasure
    cmp al,COLOR_TILE_MOVABLE               ; Check if it matches movable color
    jne .collision_wall                     ; Jump if collision with non-movable
    jmp .collision_done                     ; No collision

    .collision_wall:
        mov ax,COLOR_BALL_DEAD              ; Set color to dead ball
        call draw_player                    ; Draw dead ball Do not draw ball...
    .collision_treasure:                    ; ...after finding treasure
        call vga_blit                       ; Copy doublebuffer to VGA
        .waint_for_space:                   ; If game snded,wait for ESC key
            in al,0x60                      ; Read keyboard
            cmp al,0x39                     ; Check if key is pressed
            jne .waint_for_space
        jmp restart_game
    .collision_done:

; =========================================== DRAW PLAYER ======================

xor ax,ax                                   ; Set dead color to 0
call draw_player

; =========================================== KEYBOARD INPUT ===================

check_player_timer:
    cmp byte [PLAYER_TIMER],0x00            ; Check if player can move
    jne .dec_timer

    .handle_keyboard:
        in al,60h                           ; Read keyboard
        mov bl,0x0f                         ; Set default direction to stopped

     ; For COM file
        cmp al, 0x01
        jne .no_esc
        ; Return to text mode 0x03
        mov ax, 0x0003
        int 0x10
        ; Terminate program
        mov ax, 0x4C00
        int 0x21
        .no_esc:
     ; For COM file

        cmp al,0x1C                         ; Enter pressed
        jne .no_enter
            inc word [LEVEL]                ; Increase level desing number
            and word [LEVEL],0x03           ; Loop 0..3
            mov bl,0xff                     ; Set direction to stopped
        .no_enter:
        cmp al,0x48                         ; Up pressed
        jne .no_up
            xor bl,bl                       ; Set direction to 0
        .no_up:
        cmp al,0x50                         ; Down pressed
        jne .no_down
        mov bl,0x03                         ; Set direction to 3
        .no_down:
        cmp al,0x4D                         ; Right pressed
        jne .no_right
            mov bl,0x01                     ; Set direction to 1
        .no_right:
        cmp al,0x4B                         ; Left pressed
        jne .no_left
            mov bl,0x02                     ; Set direction to 2
        .no_left:
        cmp bl, 0x0f                        ; Check if nothing was pressed
        jz .done                            ; Skip if nothing was pressed

        .set_timer:
            mov byte [PLAYER_DIR], bl       ; Save player direction
            mov byte [PLAYER_TIMER],0x04    ; Sat player timer for moving

    .dec_timer:
        dec byte [PLAYER_TIMER]             ; Decrement player timer
        call update_player_pos              ; Update player position
    .done:

; =========================================== VGA BLIT =========================

call vga_blit                               ; Update screen

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

; =========================================== END OF GAME LOOP =================

jmp game_loop                               ; Repeat the game loop



; =========================================== PROCEDURES ======================


; =========================================== UPDATE PLAYER POSITION =========

update_player_pos:
    pusha
    mov di,[PLAYER_POS]                     ; Get player position in VGA memory
    mov al,[PLAYER_DIR]                     ; Get player direction to AL
    cmp al,0xff                             ; Check if set to stopped
    je .done
    mov ah,0                                ; And clear AH
    mov si,ax                               ; Set SI to rotation
    shl si,1                                ; Shift left
    add di,[MLT + si]                       ; Movement Lookup Table
    mov word [PLAYER_POS],di                ; Save new position
    .done:
    popa
    ret

; =========================================== DRAW PLAYER PROCEDURE ============

draw_player:
    mov di,[PLAYER_POS]                     ; Get player position in VGA memory
    mov si,ball_sprites                     ; Set sprite data start address
    mov bx,COLOR_BALL_MAIN                  ; Set color
    add  bx,ax                              ; Add alternative (dead) color
    call draw_sprite
    add si,8                                ; Move to the next sprite (shading)
    mov bx,COLOR_BALL_LIGH                  ; Set shading color
    call draw_sprite
    ret

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
    ret

; =========================================== DRAWING SPRITE PROCEDURE =========

draw_sprite:
    pusha
    mov dx,0x08                     ; Number of lines in the sprite
    .draw_row:
        mov al,[si]                         ; Get sprite row data
        mov cx,0x08                  ; 8 bits per row
        .draw_pixel:
            shl al,1                        ; Shift left to get the pixel out
            jnc .skip_pixel                 ; If carry flag is 0,skip
            mov [es:di],bl                  ; Carry flag is 1,set the pixel
        .skip_pixel:
            inc di                          ; Move to the next pixel position
            loop .draw_pixel                ; Repeat for all 8 pixels in the row
        inc si
    add di,320-SPRITE_SIZE                  ; Move to the next line
    dec dx                                  ; Decrement row count
    jnz .draw_row                           ; Draw the next row
    popa
    ret

; =========================================== DRAWING TILE PROCEDURE ===========

draw_tile:
    add si,tiles                            ; Set tile data address
    call draw_sprite
    add si,8                                ; Move to the next tile
    add di,8                                ; Move position by one sprite
    call draw_sprite
    cmp bx,COLOR_TILE_MOVABLE               ; Check if the tile is movable
    je .skip_box
        push di

        mov bx,COLOR_TILE_WALL
        add si,8                                ; Move to the next tile sprite
        sub di,320*2+4                          ; Set position (centered)
        call draw_sprite

        mov bx,COLOR_TILE_WALL_LIGH
        add si,8                                ; Move to the next tile sprite
        call draw_sprite

        pop di
    .skip_box:
    ret

; =========================================== DATA =============================

MLT dw -322,-318,318,322                    ; Movement Lookup Table
                                            ; 0 - up/left
                                            ; 1 - up/right
                                            ; 2 - down/left
                                            ; 3 - down/right

treasure_sprite db 0x3C,0xE7,0xFF,0x7E,0x7E,0x3C,0x18,0x3C  ; Treasure sprite

ball_sprites db 0x3C,0x66,0x9F,0xBF,0xFF,0x7E,0x3C,0x00  ; Ball sprite
db 0x00,0x2A,0x01,0x25,0x9B,0x46,0x3C,0x00  ; Ball sprite shading

tiles db 0x03,0x0F,0x3F,0xFF,0xFF,0x3F,0x0F,0x03  ; Tile ground left part
db 0xC0,0xF0,0xFC,0xFF,0xFF,0xFC,0xF0,0xC0  ; Tile ground right part
db 0x3C,0xFF,0xE7,0xFF,0xFF,0xFF,0xFF,0x3C  ; Tile wall
db 0x00,0x18,0x66,0x18,0x70,0x70,0x70,0x18  ; Tile wall light

; =========================================== BOOT SECTOR ======================

;times 507 - ($ - $$) db 0                   ; Pad remaining bytes
p1x db 'P1X'                                ; P1X signature 4b
;dw 0xAA55                                   ; Boot signature