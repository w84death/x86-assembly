; GAME 3 - Fly Escape
; by Krzysztof Krystian Jankowski ^ P1X
;

[bits 16]
[org 0x7c00]

cpu pentium

; ======== MEMORY MAP ========

VGA equ 0xA000
TIMER equ 0x046C                            ; BIOS timer

; ======== SETTINGS ========

SCREEN_WIDTH equ 320                        ; 320x200 pixels
SCREEN_HEIGHT equ 200
SCREEN_CENTER equ SCREEN_WIDTH*SCREEN_HEIGHT/2+SCREEN_WIDTH/2

SPRITE_SIZE equ 8                           ; 8 pixels per sprite line
SPRITE_LINES equ 7                          ; 7 lines per sprite  
MAX_ENEMIES equ 64
MAX_FLOWERS equ 8
ENEMIES_PER_LEVEL equ 4

COLOR_BG equ 20                                 
COLOR_SPIDER equ 0
COLOR_FLOWER equ 13
COLOR_FLY equ 77

SPRITE_FLY equ 0
SPRITE_SPIDER equ 14
SPRITE_FLOWER equ 28


section .bss
    BUFFER resb 64000
    LIFE resb 1
    LEVEL resw 1
    SPRITE resw 1
    COLOR resb 1
    PLAYER resb 5
    ENTITIES resb MAX_ENEMIES*5+MAX_FLOWERS*5

section .text
    global _start

; ======== GRAPHICS INITIALIZATION ========

_start:
    xor ax,ax                               ; Init segments (0)
    mov ds, ax
    mov ax, VGA                             ; Set VGA memory
    mov es, ax                              ; as target
    mov ax, 13h                             ; Init VGA 
    int 10h
    
    mov ax, BUFFER                          ; Set double buffer
    mov es, ax                              ; as target

; ======== GAME RESET/INIT ========

restart_game:
    mov byte [LIFE], 3                      ; Starting lifes
    mov word [LEVEL], 0                     ; Starting level
    mov byte [PLAYER+1], COLOR_FLY          ; Color
   
    mov si, ENTITIES                        ; Set memory position to entites
    mov cx, MAX_ENEMIES+MAX_FLOWERS         ; Number of enemies
    .clear_entites:
        mov byte [si], 0                    ; Clear sprite ID
        add si, 5                           ; Move to next memory position
    loop .clear_entites

next_level:
    mov word [PLAYER+3], SCREEN_CENTER      ; Position
    inc word [LEVEL]                        ; 0 -> 1st
    
    mov si, ENTITIES                        ; Set memory position to entites
    mov ax, ENEMIES_PER_LEVEL               ; Number of enemies per level
    mov bx, [LEVEL]                         ; Current level number
    mul bx                                  ; Multiply enemies by level number
    mov cx, ax                              ; Store the result in cx
    .next_entitie:
        MOV byte [SI], SPRITE_SPIDER        ; Sprite ID (position in memory)
        MOV byte [SI+1], COLOR_SPIDER       ; Color
        rdtsc                               ; Get random number
        and al, 7                           ; Clip rotation
        mov byte [si+2], al                 ; Set direction
        rdtsc                               ; Make it more random
        and ax, 64000                       ; Clip screen size
        mov word [si+3], ax                 ; Set position
    add si, 5                               ; Move to next memory position
    loop .next_entitie

    mov cx, [LEVEL]                         ; One more flower per level
    .spawn_flowers:
        mov byte [si], SPRITE_FLOWER
        mov byte [si+1], COLOR_FLOWER
        rdtsc                               ; Get random number
        and ax, 64000                       ; Clip screen size
        mov word [si+3], ax                 ; Set position
    add si, 5                               ; Move to next memory position
    loop .spawn_flowers

; ======== GAME LOOP  ========

game_loop:

; ======== CLEAR / DRAW BACKGROUND ========

draw_bg:
    xor di,di
    mov ax, 0x08                          ; Set color to black
    add bx, [LEVEL]
    mul bx
    add ax, 0x8080                          ; Set color to black
    mov dx, 8                               ; We have 8 bars
    .draw_bars:
        mov cx, 160*25                      ; 320x25 pixels
        rep stosw                           ; Write to the bufferr
        inc ax                              ; Increment color index for next bar
        dec dx                              ; Decrement bar counter
        jnz .draw_bars                      ; Repeat for all bars

; ======== DRAW ENTITES ========

draw_entities:
    mov word cx, MAX_ENEMIES
    mov si, ENTITIES                        ; Start index for positions
    .next:
        push cx
        push si
        xor ax,ax
        mov byte al, [si]                   ; Sprite frame
        cmp al, 0
        je .done
        mov word [SPRITE], ax  
        rdtsc                               ; Get random number
        and al, 1
        jnz .ok
        add word [SPRITE], 7                ; Move to the second sprite frame
        .ok:
        mov byte al, [si+1]                 ; Color
        mov byte [COLOR], al
        mov di, [SI+3]                      ; Position
        .move_player_and_enemies:
            cmp byte [SPRITE], SPRITE_SPIDER
            ja .draw_entitie
            .move_entitie_forward:
                movzx si, [si+2]            ; Direction            
                shl si, 1
                add di, [MLT + si]          ; Movement Lookup Table
        .draw_entitie:
            push di
            mov byte BL, [COLOR]
            mov si, sprites
            add word si, [SPRITE]
            call draw_sprite
            pop di
        pop si
        mov word [si+3], DI                 ; Save new position

        .random_rotate:
            rdtsc                           ; Randomize rotation
            and ax, 42                      ; Wait 42 cycles
            jg .skip
            rdtsc 
            and byte al, 7
            mov byte [si+2],al
            .skip:
        add si, 5                           ; Move to the next entitie data
        pop cx
        loop .next
        .done:

check_collisions:
    mov di, [PLAYER+3]                      ; Player position
    mov cx, SPRITE_LINES                               ; Number of rows to check
    .check_row:     
        push cx     
        mov cx, 8                           ; Number of columns to check
        mov si, di                          ; Current position
        .check_column:      
            push cx     
            mov al, [es:si]                 ; Get pixel color at current position
            cmp al, COLOR_SPIDER            ; Check if it matches spider color
            je .collision_spider            ; Jump if collision with spider
            cmp al, COLOR_FLOWER            ; Check if it matches flower color
            je .collision_flower            ; Jump if collision with flower
            add si, 1                       ; Move to the next column
            pop cx      
        loop .check_column      
        add di, 320                         ; Move to the next row
        pop cx
    loop .check_row
    jmp .collision_done                     ; No collision

    .collision_spider:
        mov word [PLAYER+3], SCREEN_CENTER  ; Reset player position
        dec byte [LIFE]                     ; Decrease life
        jz restart_game
        jmp .collision_done                 ; Continue if lifes left
        
    .collision_flower:
        jmp next_level

    .collision_done:
    
handle_player:
    mov di, [PLAYER+3]                      ; Position
    mov byte BL, [PLAYER+1]
    mov byte al, [PLAYER+2]
    movzx si,al                 
    shl si, 1
    add di, [MLT + si]                      ; Movement Lookup Table
    add di, [MLT + si]                      ; Second time for smoother movement
    mov word [PLAYER+3], DI                 ; Save new position
    mov si, sprites+SPRITE_FLY              ; Sprite
    rdtsc                                   ; Get random number
    and al, 1                               ; Last bit  
    jnz .ok                                 ; If 1, add frame
    add si, 7                               ; Move to the second srite frame position  
    .ok:
    call draw_sprite                        ; Draw player sprite


; ======== CHECKING KEYBOARD ========

handle_keyboard:
    mov ah, 0x01            ; Check if a key has been pressed
    int 0x16
    jz .no_move             ; No press
    xor ax,ax               ; Get the key press
    int 0x16
    .rotate_player:
        mov byte bl, [PLAYER+2]   ; Get current rotation 0-7
        inc bl                      ; Move rotation clockvise
        and bl, 7                   ; Limit 0..7
        mov byte [PLAYER+2], bl   ; Save back
    .no_move:


vga_blit:
    push es
    push ds
 
    mov ax, 0xA000  ; VGA memory
    mov bx, BUFFER  ; Buffer memory
    mov es, ax
    mov ds, bx
    mov cx, 16000   ; Quater of buffer
    xor si, si
    xor di, di
    rep movsd       ; Push double words (4x pixels)

    pop ds
    pop es

; ======== DELAY CYCLE ========

delay_timer:
    mov ax, [TIMER]
    inc ax              ; 1 cycle
    .wait:
        cmp [TIMER], ax
        jl .wait

jmp game_loop

; ======== DRAWING SPRITE PROCEDURE ========

draw_sprite:
    MOV DX, SPRITE_LINES    ; Number of lines in the sprite
    .draw_row:
        PUSH DX             ; Save DX
        MOV AL, [SI]        ; Get sprite row data
        MOV AH, 0           ; Clear AH
        MOV CX, 8           ; 8 bits per row

    .draw_pixel:
        SHL AL, 1           ; Shift left to get the next bit into carry flag
        JNC .skip_pixel     ; If carry flag is 0, skip setting the pixel
        MOV [ES:DI], BL     ; Set the pixel

    .skip_pixel:
        INC DI              ; Move to the next pixel position horizontally
        LOOP .draw_pixel    ; Repeat for all 8 pixels in the row

        POP DX              ; Restore DX
        INC SI
        ADD DI, 320         ; Move to the next line in the video buffer
        SUB DI, 8           ; Adjust DI back to the start of the line
        DEC DX              ; Decrement row count
        JNZ .draw_row       ; If there are more rows, draw the next one
    ret


; ======== DATA ========

MLT dw -320,-319,1,321,320,319,-1,-321  ; Movement Lookup Table

sprites:
; fly
db 01100000b
db 10010110b
db 01001001b
db 00110010b
db 01011100b
db 01111101b
db 00011110b

db 00000000b
db 00000000b
db 00011110b
db 01110010b
db 01011100b
db 01111101b
db 00011110b

; spider
db 00000110b
db 01110111b
db 10101111b
db 11111110b
db 00101010b
db 01001001b
db 01001001b

db 00000110b
db 01110111b
db 10101111b
db 11111110b
db 00101011b
db 11010100b
db 00010100b

; flower
db 00011100b
db 00110110b
db 00011100b
db 01101000b
db 00111100b
db 00001000b
db 00001000b

db 00111000b
db 01101100b
db 00111000b
db 01101000b
db 00111100b
db 00001000b
db 00001000b


; ======== BOOTSECTOR  ========
times 507 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X'            ; P1X signature 4b
dw 0xAA55