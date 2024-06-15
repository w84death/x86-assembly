; GAME4 - PARROT GAME
; Description: A simple space ship game
; Author: Krzysztof Krystian Jankowski
; Date: 2024-06-09
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
PLAYER_POS equ BASE_MEM+0x03                  ; Ship position,2 bytes
PLAYER_POS_I equ BASE_MEM+0x05                ; Ship position increment,2 bytes
PLAYER_DIR equ BASE_MEM+0x07                ; Ship direction,1 byte

; =========================================== MAGIC NUMBERS ====================

SCREEN_WIDTH equ 320                        ; 320x200 pixels
SCREEN_HEIGHT equ 200
SCREEN_CENTER equ SCREEN_WIDTH*SCREEN_HEIGHT/2+SCREEN_WIDTH/2 ; Center
PLAYER_START_POS equ SCREEN_WIDTH*108+SCREEN_WIDTH/2-4 ; Player start position
LEVEL_START_POS equ 168+320*40              ; Level start position    
SPRITE_SIZE equ 8                           ; 8 pixels per sprite line
SPRITE_LINES equ 8                          ; 7 lines per sprite  
LEVEL_COLS equ 16                           ; 16 columns per level
LEVEL_ROWS equ 16                           ; 16 rows per level
COLOR_BACKGROUND equ 0x1010                 ; Color for background
COLOR_LOGO equ 0x0f                         ; Color for logo
COLOR_TILE_MOVABLE equ 0x43                 ; Color for movable tile
COLOR_TILE_NONMOVABLE equ 0x7d              ; Color for non-movable tile
COLOR_TILE_WALL equ 0x36                    ; Color for shaded wall tile
COLOR_TILE_WALL_LIGH equ 0x35               ; Color for wall tile

; =========================================== BOOTSTRAP ========================

_start:
    xor ax,ax                               ; Clear AX
    mov ds,ax                               ; Set DS to 0
    mov ax,0x13                             ; Init VGA 320x200x256
    int 0x10                                ; Video BIOS interrupt  
    
    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop es                                  ; as target

restart_game:
    mov word [LEVEL],0x00                   ; Starting level
    mov byte [LIFE],0x03                    ; Starting lifes
    mov word [PLAYER_POS],PLAYER_START_POS  ; Starting player position

; =========================================== MAIN GAME LOOP ===================

game_loop:


; =========================================== DRAW BACKGROUND ==================

draw_bg:
    mov ax,COLOR_BACKGROUND                 ; Set color 0x10
    mov dx,12                               ; We have 12 bars
    .draw_bars:
        mov cx,320*200/64                   ; One bar of 320x200
        rep stosw                           ; Write to the doublebuffer
        inc ax                              ; Increment color index for next bar
        xchg al,ah                          ; Swap colors 
        dec dx                              ; Decrement bar counter
        jnz .draw_bars                      ; Repeat for all bars


    mov cx,320*200/3                        ; Half of the screen    
    rep stosw                               ; Write to the doublebuffer

; =========================================== DRAW LOGO ========================

draw_p1x_logo:
    mov bx,COLOR_LOGO                       ; Set logo color
    mov si,p1x_sprite                       ; Set sprite data address
    mov di,320*4+320-12                     ; Set sprite position
    call draw_sprite

; =========================================== DRAW LEVEL =======================

draw_level:
    mov si,level                            ; Set level data address
    add si,[LEVEL]                          ; Add current level offset
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

; =========================================== DRAW PLAYER ======================
    
draw_parrot:
    mov di,[PLAYER_POS]                     ; Get player position in VGA memory
    mov al,[PLAYER_DIR]                     ; Get player direction to AL
    mov ah,0                                ; And clear AH
    mov bx,8
    mul bx                                  ; Calculate offset for sprite data 
    mov si,parrot_sprites                   ; Set sprite data start address
    add si,ax                               ; Add sprite data offset
    mov bx,0x29                             ; Set color
    call draw_sprite

; =========================================== KEYBOARD INPUT ===================

handle_keyboard:
    in al,60h                               ; Read keyboard

    cmp al,0x48                             ; Up pressed
    jne .no_up
        and byte [PLAYER_DIR],0xfd          ; Set second bit to 0 
        call update_player_pos        
    .no_up:
    cmp al,0x50                             ; Down pressed
    jne .no_down
        or byte [PLAYER_DIR],0x02           ; Set second bit to 1
        call update_player_pos
    .no_down:   
    cmp al,0x4D                             ; Right pressed
    jne .no_right
        or byte [PLAYER_DIR],0x01           ; Set first bit to 1
        call update_player_pos
    .no_right:    
    cmp al,0x4B                             ; Left pressed
    jne .no_left
        and byte [PLAYER_DIR],0xfe          ; Set first bit to 0
        call update_player_pos
    .no_left:

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
    mov ah,0                                ; And clear AH
    mov si,ax                               ; Set SI to rotation
    shl si,1                                ; Shift left
    add di,[MLT + si]                       ; Movement Lookup Table
    mov word [PLAYER_POS],di                ; Save new position 
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
db 0x00,0xD5,0x75,0xD2,0x95,0x95,0x95,0x00  ; P1X

parrot_sprites:
db 0x01,0x73,0x57,0x3F,0x1C,0x36,0x74,0xF0  ; Parrot direction 0
db 0x80,0xCE,0xEA,0xFC,0x38,0x6C,0x2E,0x0F  ; Parrot direction 1
db 0xF4,0x76,0x3C,0x1C,0x7F,0x57,0x63,0x01  ; Parrot direction 2
db 0x2F,0x6E,0x3C,0x3C,0xFE,0xEA,0xC6,0x80  ; Parrot direction 3

tiles:
db 0x03,0x0F,0x3F,0xFF,0xFF,0x3F,0x0F,0x03  ; Tile ground left
db 0xC0,0xF0,0xFC,0xFF,0xFF,0xFC,0xF0,0xC0  ; Tile ground right
db 0x3C,0xFF,0xE7,0xFF,0xFF,0xFF,0xFF,0x3C  ; Tile wall base/shaded
db 0x00,0x18,0x66,0x18,0x70,0x70,0x70,0x18  ; Tile wall light
; db 0xC0,0xB0,0x8C,0x83,0xC1,0x31,0x0D,0x43  ; Tile wall horizontal
; db 0x03,0x0D,0x31,0xC1,0x83,0x8C,0xB0,0xC0  ; Tile wall vertical

level:
dw 1111111111111111b
dw 1000000011111111b
dw 1001100000000011b
dw 1001110001100011b
dw 1000000001100011b
dw 1000000000000011b
dw 1100000000000011b
dw 1100111000001111b
dw 1100111000001111b
dw 1100000000000011b
dw 1100000000000011b
dw 1111000001100011b
dw 1111110001100011b
dw 1100000001100011b
dw 1100000111111011b
dw 1111111111111111b

; =========================================== BOOT SECTOR ======================

times 507 - ($ - $$) db 0                   ; Pad remaining bytes
p1x db 'P1X'                                ; P1X signature 4b
dw 0xAA55                                   ; Boot signature