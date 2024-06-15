; GAME6 - ISOMETRIC MAYHEM
; Description: Simple shooter game with isometric graphics
; Author: Krzysztof Krystian Jankowski
; Date: 2024-06-15
bits 16                                     ; 16-bit mode          
org 0x7c00                                  ; Boot sector origin
cpu 286                                     ; Minimum CPU is Intel 286

; =========================================== MEMORY ===========================

VGA_MEMORY_ADR equ 0xA000                   ; VGA memory address
DBUFFER_MEMORY_ADR equ 0x9000               ; Doublebuffer memory address
SCREEN_BUFFER_SIZE equ 0xFA00               ; Size of the VGA buffer size
TIMER equ 0x046C                            ; BIOS timer

BASE_MEM equ 0x7e00                         ; Base memory address
LIFE equ BASE_MEM+0x00                      ; Number of lifes,1 byte
LEVEL equ BASE_MEM+0x01                     ; Current level,2 bytes
PLAYER_POS equ BASE_MEM+0x03                ; Ship position,2 bytes
PLAYER_TIMER equ BASE_MEM+0x05              ; Movement timer,2 bytes
PLAYER_DIR equ BASE_MEM+0x07                ; Ship direction,1 byte
TREASURE_POS equ BASE_MEM+0x08              ; Flower position,2 bytes
LEVEL_DATA equ BASE_MEM+0x0A                ; Level data, 512 bytes

; =========================================== MAGIC NUMBERS ====================

SCREEN_WIDTH equ 320                        ; 320x200 pixels
SCREEN_HEIGHT equ 200
SCREEN_CENTER equ SCREEN_WIDTH*SCREEN_HEIGHT/2+SCREEN_WIDTH/2 ; Center
LEVEL_START_POS equ 168+320*40              ; Level start position    
PLAYER_START_POS equ LEVEL_START_POS+320*10-14 ; Player start position
TREASURE_START_POS equ LEVEL_START_POS+320*114-14 ; Treasure start position
SPRITE_SIZE equ 8                           ; 8 pixels per sprite line
SPRITE_LINES equ 8                          ; 7 lines per sprite  
LEVEL_COLS equ 16                           ; 16 columns per level
LEVEL_ROWS equ 16                           ; 16 rows per level
COLOR_BACKGROUND equ 0x4040                 ; Color for background
COLOR_LOGO equ 0x0f                         ; Color for logo
COLOR_TILE_MOVABLE equ 0x58                 ; Color for movable tile
COLOR_TILE_NONMOVABLE equ 0x7d              ; Color for non-movable tile
COLOR_TILE_WALL equ 0x36                    ; Color for shaded wall tile
COLOR_TILE_WALL_LIGH equ 0x35               ; Color for wall tile
COLOR_BALL_MAIN equ 0x3d                    ; Color for the player ball
COLOR_BALL_LIGH equ 0x6c                    ; Color for shading the ball
COLOR_TREASURE equ 0x0f                     ; Color for the treasure

; =========================================== BOOTSTRAP ========================

_start:
    xor ax,ax                               ; Clear AX
    mov ds,ax                               ; Set DS to 0
    mov ax,0x13                             ; Init VGA 320x200x256
    int 0x10                                ; Video BIOS interrupt  
    
    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop es                                  ; as target

create_levels:
    xor di,di
    mov ax, 0x1212
    mov bx, 0xabcd
    mov cx, 0xff
    .l:
    
    add bx, di
    ror ax, 4
    xor ax, bx
    
    mov word [LEVEL_DATA+di], ax
    inc di
    loop .l

restart_game:
    mov word [LEVEL],0x00                   ; Starting level
    mov word [PLAYER_POS],PLAYER_START_POS  ; Starting player position
    mov byte [PLAYER_TIMER], 0x00           ; Reset player timer  
        
; =========================================== MAIN GAME LOOP ===================

game_loop:

; =========================================== DRAW BACKGROUND ==================

draw_bg:
    mov ax,COLOR_BACKGROUND                 ; Set color 0x10
    mov cx,SCREEN_BUFFER_SIZE              ; Set buffer size
    rep stosw

draw_level_indicator:
    mov cx,[LEVEL]
    inc cx
    mov bx,COLOR_TILE_WALL
    mov si,tiles+16
    mov di,320*4+132
    .draw_glyph:
        pusha
        call draw_sprite
        popa
        add di, 12
        loop .draw_glyph

; =========================================== DRAW LEVEL =======================

draw_level:
    mov si, LEVEL_DATA                     ; Set level data address
    mov ax, [LEVEL]
    mov bx, 0x20
    mul bx
    add si,ax                          ; Add current level offset

    mov dx,LEVEL_ROWS                       ; Number of rows in the level
    mov di,LEVEL_START_POS                  ; Set level start position
    .draw_row: 
        mov ax,[si]                         ; Get level row data
        mov cx,LEVEL_COLS                   ; 16 bits per row
        .draw_tile_box:
            shl ax,1                        ; Shift left to get the tile out
            jc .color_non_movable           ; If carry flag is 0,draw ground
                mov bx,COLOR_TILE_MOVABLE
                jmp .draw_the_tile
            .color_non_movable:
                mov bx,COLOR_TILE_NONMOVABLE
            
            .draw_the_tile:
            push si
            xor si,si                       ; Set sprite ID to 0
            add di,320*4-17       
            call draw_tile
            pop si

            inc di                          ; Move to the next tile position
            loop .draw_tile_box             
        inc si
        inc si
    add di,-320*60+136                      ; Move to the next row
    dec dx                                  ; Decrement row count
    jnz .draw_row                           ; Draw the next row

; =========================================== DRAW TREASURE ====================

draw_treasure:
    mov bx,COLOR_TREASURE                   ; Set sprite color
    mov si,p1x_sprite                       ; Set sprite data address
    mov word di, TREASURE_START_POS             ; Set sprite position
    call draw_sprite

; =========================================== CHECK COLLISIONS ==============

check_collisions:
    mov si, [PLAYER_POS]                      ; Get player position
    add si, 320*4+4
    mov al, [es:si]                 ; Get pixel color at player position
    cmp al, COLOR_TREASURE            ; Check if it matches flower color
    je .collision_treasure            ; Jump if collision with flower
    cmp al, COLOR_TILE_MOVABLE            ; Check if it matches spider color
    jne .collision_wall            ; Jump if collision with spider
    jmp .collision_done                     ; No collision

    .collision_treasure:
        .waint_for_esc:
            in al, 60h
            cmp al, 1
            jne .waint_for_esc
    .collision_wall:
        jmp restart_game
        
    .collision_done:

; =========================================== DRAW PLAYER ======================
    
draw_player:
    mov di,[PLAYER_POS]                     ; Get player position in VGA memory
    mov si,ball_sprites                     ; Set sprite data start address
    mov bx,COLOR_BALL_MAIN                  ; Set color
    call draw_sprite
    mov di,[PLAYER_POS]                     ; Get player position in VGA memory
    mov bx,COLOR_BALL_LIGH                  ; Set color
    call draw_sprite
    
; =========================================== KEYBOARD INPUT ===================

check_player_timer:
    cmp byte [PLAYER_TIMER],0x00               ; Check if player can move
    jne .dec_timer

    .handle_keyboard:
        in al,60h                               ; Read keyboard
        
        cmp al,0x1C                             ; Enter pressed
        jne .no_enter
            inc word [LEVEL]
            and word [LEVEL], 0x07              ; Limit to 32 levels
            mov byte [PLAYER_DIR],0x0f          ; Set second bit to 0
            jmp .set_timer
        .no_enter:
        cmp al,0x48                             ; Up pressed
        jne .no_up
            mov byte [PLAYER_DIR],0x00          ; Set second bit to 0 
            jmp .set_timer
        .no_up:
        cmp al,0x50                             ; Down pressed
        jne .no_down
            mov byte [PLAYER_DIR],0x03           ; Set second bit to 1
            jmp .set_timer
        .no_down:   
        cmp al,0x4D                             ; Right pressed
        jne .no_right
            mov byte [PLAYER_DIR],0x01           ; Set first bit to 1
            jmp .set_timer
        .no_right:    
        cmp al,0x4B                             ; Left pressed
        jne .no_left
            mov byte [PLAYER_DIR],0x02          ; Set first bit to 0
            jmp .set_timer
        .no_left:
        jmp .done

        .set_timer:
        mov byte [PLAYER_TIMER],0x04
        
    .dec_timer:
        dec byte [PLAYER_TIMER]
        call update_player_pos
    .done:

; =========================================== VGA BLIT =========================

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

delay_timer:
    mov ax,[TIMER]                          ; Get current timer value
    inc ax                                  ; Increment it by 1 cycle (42ms)
    .wait:
        cmp [TIMER],ax                      ; Compare with the current timer
        jl .wait                            ; Loop until equal

; =========================================== END OF GAME LOOP =================

jmp game_loop                               ; Repeat the game loop

update_player_pos:
    pusha
    mov di,[PLAYER_POS]                     ; Get player position in VGA memory
    mov al,[PLAYER_DIR]                     ; Get player direction to AL
    cmp al, 0x0f
    je .done
    mov ah,0                                ; And clear AH
    mov si,ax                               ; Set SI to rotation
    shl si,1                                ; Shift left
    add di,[MLT + si]                       ; Movement Lookup Table
    mov word [PLAYER_POS],di                ; Save new position 
    .done:
    popa
    ret

; =========================================== DRAWING SPRITE PROCEDURE =========

draw_sprite:
    mov dx,SPRITE_LINES                     ; Number of lines in the sprite
    .draw_row: 
        mov al,[si]                         ; Get sprite row data
        mov cx,SPRITE_SIZE                  ; 8 bits per row
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
    ret

; =========================================== DRAWING TILE PROCEDURE ===========

draw_tile: 
    add si,tiles                            ; Set tile data address
    pusha
    call draw_sprite
    popa
    add si,8                                ; Move to the next tile
    add di,8                                ; Move position by one sprite
    pusha
    call draw_sprite
    popa
    
    cmp bx,COLOR_TILE_MOVABLE               ; Check if the tile is movable
    je .skip_box

        push di
        
        mov bx,COLOR_TILE_WALL
        add si,8                                ; Move to the next tile sprite
        sub di,320*2+4                          ; Set position (centered)
        pusha
        call draw_sprite
        popa
        
        mov bx,COLOR_TILE_WALL_LIGH
        add si,8                                ; Move to the next tile sprite
        pusha
        call draw_sprite
        popa
        
        pop di
    
    .skip_box:
    ret

; =========================================== DATA =============================

MLT dw -322,-318,318,322                    ; Movement Lookup Table 
                                            ; 0 - up/left
                                            ; 1 - up/right
                                            ; 2 - down/left
                                            ; 3 - down/right      
p1x_sprite:
db 0x00,0xD5,0x75,0xD2,0x95,0x95,0x95,0x00  ; P1X 8 bytes

ball_sprites:
db 0x3C,0x66,0x9F,0xBF,0xFF,0x7E,0x3C,0x00  ; Ball sprite
db 0x00,0x00,0x02,0x01,0x05,0xAB,0x56,0x3C  ; Ball sprite shading

tiles:
db 0x03,0x0F,0x3F,0xFF,0xFF,0x3F,0x0F,0x03  ; Tile ground left part
db 0xC0,0xF0,0xFC,0xFF,0xFF,0xFC,0xF0,0xC0  ; Tile ground right part
db 0x3C,0xFF,0xE7,0xFF,0xFF,0xFF,0xFF,0x3C  ; Tile wall
db 0x00,0x18,0x66,0x18,0x70,0x70,0x70,0x18  ; Tile wall light

; =========================================== BOOT SECTOR ======================

times 507 - ($ - $$) db 0                   ; Pad remaining bytes
p1x db 'P1X'                                ; P1X signature 4b
dw 0xAA55                                   ; Boot signature