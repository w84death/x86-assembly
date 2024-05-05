; GAME 3 - Fly Escape
; by Krzysztof Krystian Jankowski ^ P1X
;

[bits 16]
[org 0x7c00]

; ======== MEMORY MAP ========
VGA equ 0xA000
TIMER equ 0x046C        ; BIOS timer
BUFFER equ 0x1000       ; 64000 bytes
MEM_BASE equ 0x7e00     ; Memory position after the code
LIFE equ MEM_BASE       ; 1 byte
LEVEL equ MEM_BASE+1    ; 1 byte
SPRITE equ MEM_BASE+2   ; 2 bytes
COLOR equ MEM_BASE+4    ; 1 bytes
RND equ MEM_BASE+5      ; 2 bytes
ENTITIES equ MEM_BASE+12    ; A lot

; ======== SETTINGS ========

SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200

SPRITE_SIZE equ 8
SPRITE_LINES equ 7
MAX_ENEMIES equ 4
MAX_FLOWERS equ 3

COLOR_BG equ 20
COLOR_SPIDER equ 0
COLOR_FLOWER equ 13
COLOR_FLY equ 77

SPRITE_FLY equ 0
SPRITE_SPIDER equ 7
SPRITE_FLOWER equ 14

FLY_START_POS equ 320*100+160

; ======== GRAPHICS INITIALIZATION ========

start:
    xor ax,ax       ; Init segments (0)
    mov ds, ax
    mov ax, VGA     ; Set VGA memory
    mov es, ax      ; as target
    mov ax, 13h     ; Init VGA 
    int 10h
    
    mov ax, BUFFER  ; Set double buffer
    mov es, ax      ; as target

; ======== GAME RESET/INIT ========

game_reset:
    mov byte [LIFE], 3                      ; Starting lifes
    mov word [RND], 0xfaaf                  ; Seed for pseudo random numbers
    .set_player_entitie:                    ; First controlable by player
    mov byte [ENTITIES], SPRITE_FLY         ; Sprite ID (position in memory)
    mov byte [ENTITIES+1], COLOR_FLY        ; Color
    mov byte [ENTITIES+2], 0                ; Direction
    mov word [ENTITIES+3], FLY_START_POS    ; Position

; inc byte [LEVEL] 

next_level:
    inc byte [LEVEL]        ; 0 -> 1st
    mov si, ENTITIES+5      ; Set memory position after player
    mov ax, MAX_ENEMIES     ; Enemies per level
    mov byte bl, [LEVEL]        ; Multiply by level number
    imul ax, bx              
    mov cx, ax              ; Set loop counter
    .next_entitie:
        MOV byte [SI], SPRITE_SPIDER        ; Sprite ID (position in memory)
        MOV byte [SI+1], COLOR_SPIDER       ; Color
        mov byte al, [RND]                  ; Get random number
        and al, 7                           ; Clip 0-7
        mov byte [si+2], al                 ; Set direction
        mov word ax, [RND]                  ; Get random number
        mov word [si+3], ax                 ; Set position
        shr word [RND],1                    ; Set next random number
        add si, 5                           ; Move to next memory position
    loop .next_entitie

    mov cx, MAX_FLOWERS
    .spawn_flowers:
        MOV byte [SI], SPRITE_FLOWER
        MOV byte [SI+1], COLOR_FLOWER
        mov word ax, [RND] 
        shr word [RND],1
        mov word bx, [RND] 
        imul ax, bx
        mov word [si+3], ax
        shr word [RND],1
        add si, 5
    loop .spawn_flowers

; ======== GAME LOOP  ========

game_loop:

; ======== CLEAR / DRAW BACKGROUND ========

draw_bg:
    xor di,di
    mov ah, 128
    MOV DX, 8       ; We have 8 bars
    .draw_bars:
        PUSH DX
        MOV CX, 320*25   ; 40 pixels per bar * 200 lines = 8000 pixels per bar
    .draw_line:
        MOV AL, AH      ; Set pixel to current color index
        STOSB           ; Write AL to ES:DI and increment DI
        LOOP .draw_line
    POP DX
    inc AH  ; Increment color index for next bar
    DEC DX
    JNZ .draw_bars

; ======== DRAW ENTITES ========

draw_entities:
    mov cx, MAX_ENEMIES+1+MAX_FLOWERS            ; Number of entitiea to process
    ; mov ax, MAX_ENEMIES             ; Enemies per level
    ; mov byte bl, [LEVEL]            ; Multiply by level number
    ; imul ax, bx
    ; add ax, MAX_FLOWERS
    ; mov cx, ax
    mov si, ENTITIES                ; Start index for positions
    .next:
        push cx
        push si
        xor ax,ax
        mov byte al, [si]           ; Sprite
        mov word [SPRITE], ax       
        mov byte al, [si+1]         ; Color
        mov byte [COLOR], al
        mov byte al, [si+2]         ; Direction
        mov di, [SI+3]              ; Position
        .move_player_and_enemies:
            cmp byte [SPRITE], SPRITE_SPIDER
            ja .draw_entitie
            .move_entitie_forward:
                movzx si,al                 
                shl si, 1
                add di, [MLT + si] ; Movement Lookup Table
        .draw_entitie:
            push di
            mov byte BL, [COLOR]
            mov si, sprites
            add word si, [SPRITE]
            call draw_sprite
            pop di
        pop si
        mov word [si+3], DI         ; Save new position

        .random_rotate:
            mov ax, [TIMER]
            and ax, 47
            cmp ax, 0
            jg .skip_now
            inc byte [si+2]
            and byte [si+2],7
            .skip_now:

        add si, 5                   ; Move to the next entitie data
        pop cx
        loop .next                  ; Repeat
    
; ======== CHECKING KEYBOARD ========

handle_keyboard:
    mov ah, 0x01            ; Check if a key has been pressed
    int 0x16
    jz .no_move             ; No press
    xor ax,ax               ; Get the key press
    int 0x16
    .rotate_player:
        mov byte bl, [ENTITIES+2]   ; Get current rotation 0-7
        inc bl                      ; Move rotation clockvise
        and bl, 7                   ; Limit 0..7
        mov byte [ENTITIES+2], bl   ; Save back
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
        MOV byte [ES:DI], BL    ; Set the pixel

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

; spider
db 00000000b
db 00111000b
db 01010100b
db 01111100b
db 10101010b
db 10101010b
db 10000010b

; flower
db 00011100b
db 00110110b
db 00011100b
db 01101000b
db 00111100b
db 00001000b
db 00001000b




; ======== BOOTSECTOR  ========

times 507 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X'            ; P1X signature 4b
dw 0xAA55