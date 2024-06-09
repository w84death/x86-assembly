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
LIFE equ BASE_MEM+0x00                      ; Number of lifes, 1 byte
LEVEL equ BASE_MEM+0x01                     ; Current level, 2 bytes
PLAYER_POS equ BASE_MEM+0x03                  ; Ship position, 2 bytes
PLAYER_POS_I equ BASE_MEM+0x05                ; Ship position increment, 2 bytes
PLAYER_DIR equ BASE_MEM+0x07                ; Ship direction, 1 byte

; =========================================== MAGIC NUMBERS ====================

SCREEN_WIDTH equ 320                        ; 320x200 pixels
SCREEN_HEIGHT equ 200
SCREEN_CENTER equ SCREEN_WIDTH*SCREEN_HEIGHT/2+SCREEN_WIDTH/2 ; Center
PLAYER_START_POS equ SCREEN_WIDTH*180+SCREEN_WIDTH/2          ; Player start position

SPRITE_SIZE equ 8                           ; 8 pixels per sprite line
SPRITE_LINES equ 8                          ; 7 lines per sprite  
PALETTE_SIZE equ 0x1E                       ; 30 colors 

; =========================================== BOOTSTRAP ========================

_start:
    xor ax, ax                              ; Clear AX
    mov ds, ax                              ; Set DS to 0
    mov ax, 0x13                            ; Init VGA 320x200x256
    int 0x10                                ; Video BIOS interrupt  
    
    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop es                                  ; as target




restart_game:
    mov word [LEVEL], 0x18                  ; Starting level
    mov byte [LIFE], 0x03                   ; Starting lifes
    mov word [PLAYER_POS], PLAYER_START_POS ; Starting ship position

; =========================================== MAIN GAME LOOP ===================

game_loop:


; =========================================== DRAW BACKGROUND ==================

draw_bg:
    mov ax, 0x4040                          ; Set color 0x10
    mov dx, 12                              ; We have 8 bars
    .draw_bars:
        mov cx, 320*200/64                  ; One bar of 320x200
        rep stosw                           ; Write to the doublebuffer
        inc ax                              ; Increment color index for next bar
        xchg al, ah                         ; Swap colors 
        dec dx                              ; Decrement bar counter
        jnz .draw_bars                      ; Repeat for all bars


    mov cx, 320*200/3                       ; Half of the screen    
    rep stosw                               ; Write to the doublebuffer

; =========================================== DRAW SPRITE ======================

draw_logo:
    mov bx, 0x00                            ; Set color 0x1E
    mov si, p1x_sprite                         ; Set sprite data
    mov di, SCREEN_CENTER-4                 ; Set sprite position
    call draw_sprite                        ; Draw the sprite

    mov bx, 0x2a
    mov si, parrot_sprites
    mov di, SCREEN_CENTER+16
    call draw_sprite

    mov bx, 0x2b
    mov si, parrot_sprites+8
    mov di, SCREEN_CENTER+28
    call draw_sprite

    mov bx, 0x28
    mov si, parrot_sprites+16
    mov di, SCREEN_CENTER+40
    call draw_sprite

    mov bx, 0x29
    mov si, parrot_sprites+24
    mov di, SCREEN_CENTER+52
    call draw_sprite

draw_parrot:
    
    mov di, [PLAYER_POS]                     ; Set sprite position
    mov al, [PLAYER_DIR]
    mov ah, 0                               ; Clear AH
    mov si, ax                              ; Set SI to rotation
    shl si, 1                               ; Shift left
    add di, [MLT + si]                      ; Movement Lookup Table
    mov word [PLAYER_POS], DI                 ; Save new position  
    
    mov bx, 8
    mul bx
    
    mov si, parrot_sprites                         ; Set sprite data
    add si, ax
    mov bx, 0x29                            ; Set color 0x1E
    call draw_sprite  

; =========================================== KEYBOARD INPUT ===================

handle_keyboard:
    in al, 60h                              ; Read keyboard

    cmp al, 0x48                            ; Up pressed
    jne .no_up
        and byte [PLAYER_DIR], 0xfd         ; Set second bit to 0         
    .no_up:
    cmp al, 0x50                            ; Down pressed
    jne .no_down
        or byte [PLAYER_DIR], 0x02          ; Set second bit to 1
    .no_down:   
    cmp al, 0x4D                            ; Right pressed
    jne .no_right
        or byte [PLAYER_DIR], 0x01          ; Set first bit to 1
    .no_right:    
    cmp al, 0x4B                            ; Left pressed
    jne .no_left
        and byte [PLAYER_DIR], 0xfe         ; Set first bit to 0
    .no_left:

; =========================================== VGA BLIT =========================

vga_blit:
    push es
    push ds

    push VGA_MEMORY_ADR                     ; Set VGA memory
    pop es                                  ; as target
    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop ds                                  ; as source
    mov cx, 0x7D00                          ; Half of 320x200 pixels
    xor si, si                              ; Clear SI
    xor di, di                              ; Clear DI
    rep movsw                               ; Push words (2x pixels)

    pop ds
    pop es

; =========================================== DELAY CYCLE ======================

delay_timer:
    mov ax, [TIMER]                         ; Get current timer value
    inc ax                                  ; Increment it by 1 cycle (42ms)
    .wait:
        cmp [TIMER], ax                     ; Compare with the current timer
        jl .wait                            ; Loop until equal



; =========================================== END OF GAME LOOP =================

jmp game_loop                               ; Repeat the game loop

; =========================================== DRAWING SPRITE PROCEDURE =========

draw_sprite:
    mov dx, SPRITE_LINES                    ; Number of lines in the sprite
    .draw_row: 
        mov al, [si]                        ; Get sprite row data
        mov cx, 8                           ; 8 bits per row
        .draw_pixel:
            shl al, 1                       ; Shift left to get the pixel out
            jnc .skip_pixel                 ; If carry flag is 0, skip
            mov [es:di], bl                 ; Carry flag is 1, set the pixel
        .skip_pixel:
            inc di                          ; Move to the next pixel position
            loop .draw_pixel                ; Repeat for all 8 pixels in the row
        inc si
    add di, 312                             ; Move to the next line
    dec dx                                  ; Decrement row count
    jnz .draw_row                           ; Draw the next row
    ret


; =========================================== DATA =============================

MLT dw -321, -319, 319, 321                 ; Movement Lookup Table 
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

food_sprites:

arrows_sprites:

; =========================================== BOOT SECTOR ======================
times 507 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X'            ; P1X signature 4b
dw 0xAA55