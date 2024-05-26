; GAME 3 - Fly Escape
; by Krzysztof Krystian Jankowski ^ P1X
;
; Version 1.0 - 18 MAY 2024
; Version 1.1 - 19 MAY 2024
; Version 2.0 - 25 MAY 2024
; Version 2.1 - 26 MAY 2024

bits 16                                     ; 16-bit mode          
org 0x7c00                                  ; Boot sector origin
cpu 286                                     ; Minimum CPU is Intel 286

; =========================================== MEMORY ===========================

VGA_MEMORY_ADR equ 0xA000                   ; VGA memory address
DBUFFER_MEMORY_ADR equ 0x1000               ; Doublebuffer memory address
SCREEN_BUFFER_SIZE equ 0xFA00               ; Size of the VGA buffer size
TIMER equ 0x046C                            ; BIOS timer

BASE_MEM equ 0x7e00                         ; Base memory address
LIFE equ BASE_MEM+0x00                      ; Number of lifes, 1 byte
LEVEL equ BASE_MEM+0x01                     ; Current level, 2 bytes
SPRITE equ BASE_MEM+0x03                    ; Current sprite, 2 bytes
COLOR equ BASE_MEM+0x05                     ; Current color, 1 byte
PLAYER equ BASE_MEM+0x06                    ; Player data, 5 bytes of:
                                            ;       sprite ID, 1 byte
                                            ;       color, 1 byte
                                            ;       rotation, 1 byte
                                            ;       position, 2 bytes
ENTITIES equ BASE_MEM+0x0B                  ; 5 bytes per entitie

; =========================================== MAGIC NUMBERS ====================

SCREEN_WIDTH equ 320                        ; 320x200 pixels
SCREEN_HEIGHT equ 200
SCREEN_CENTER equ SCREEN_WIDTH*SCREEN_HEIGHT/2+SCREEN_WIDTH/2 ; Center

SPRITE_SIZE equ 8                           ; 8 pixels per sprite line
SPRITE_LINES equ 7                          ; 7 lines per sprite  
MAX_ENTITIES equ 128                        ; Maximum number of entities           
ENEMIES_PER_LEVEL equ 4                     ; Number of enemies per level

COLOR_BG equ 20                             ; Background color
COLOR_SPIDER equ 0                          ; Spider color    
COLOR_FLOWER equ 10                         ; Flower color
COLOR_FLY equ 77                            ; Fly color

SPRITE_FLY equ 0                            ; Fly sprite ID (position in memory)
SPRITE_SPIDER equ 14                        ; Spider sprite ID
SPRITE_FLOWER equ 28                        ; Flower sprite ID


; =========================================== BOOTSTRAP ========================

_start:
    xor ax, ax                              ; Clear AX
    mov ds, ax                              ; Set DS to 0
    mov ax, 0x13                          ; Init VGA 320x200x256
    int 0x10                                ; Video BIOS interrupt  
    
    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop es                                  ; as target

; =========================================== GAME INITIALIZATION / RESET ======

restart_game:
    mov byte [LIFE], 0x04                   ; Starting lifes
    mov word [LEVEL], 0x00                  ; Starting level
    mov word [PLAYER+1], (0x06 << 8) | COLOR_FLY ; Set player color and sprite   
    mov si, ENTITIES                        ; Set memory position to entites
    mov cx, MAX_ENTITIES                    ; Number of enemies
    .clear_entites:
        mov byte [si], 0                    ; Clear sprite ID
        add si, 5                           ; Move to next memory position
    loop .clear_entites                     ; Loop for all enemies

; =========================================== LEVEL INITIALIZATION / NEXT LEVEL

next_level:
    mov word [PLAYER+3], SCREEN_CENTER      ; Set player initial position
    inc word [LEVEL]                        ; 0 -> 1st level
    mov si, ENTITIES                        ; Set memory position to entites
    mov bx, [LEVEL]                         ; Current level number
    imul cx, bx, ENEMIES_PER_LEVEL          ; Multiply enemies by level number
    .next_entitie:
        cmp cx, 1                           ; Check counter
        ja .spawn_spider                    ; Spawn spider on all others
        .spawn_flower:                      ; Spawn flower on first entitie
        mov word [si], (COLOR_FLOWER << 8) | SPRITE_FLOWER  
                                            ; Set sprite ID and color for flower
        jmp .spawn_done
        .spawn_spider:
        mov word [si], (COLOR_SPIDER << 8) | SPRITE_SPIDER  
                                            ; Set sprite ID and color for spider
        .spawn_done:
        mov byte al, [TIMER]                ; Get random number
        add ax, si                          ; Add memory position
        and ax, SCREEN_BUFFER_SIZE          ; Clip screen size
        mov word [si+3], ax                 ; Set position
        add ax, si                          ; Add memory position
        and al, 7                           ; Clip rotation
        mov byte [si+2], al                 ; Set direction
    add si, 5                               ; Move to next memory position
    loop .next_entitie                      ; Repeat for all enemies

; =========================================== MAIN GAME LOOP ===================

game_loop:

; =========================================== DRAW BACKGROUND ==================

draw_bg:
    xor di,di                               ; Clear DI                     
    xor bx,bx                               ; Clear BX
    mov bx, [LEVEL]                         ; Get current level number
    imul ax, bx, 0x0404                     ; Multiply level by 0x0404
    add ax, 0xa0a0                          ; Shift colors by 10
    mov dx, 8                               ; We have 8 bars
    .draw_bars:
        mov cx, 320*200/16                   ; One bar of 320x200
        rep stosw                           ; Write to the doublebuffer
        inc ax                              ; Increment color index for next bar
        xchg al, ah                         ; Swap colors 
        dec dx                              ; Decrement bar counter
        jnz .draw_bars                      ; Repeat for all bars

; =========================================== DRAW LEVEL =======================

    xor di, di                              ; Clear DI - top left corner
    mov al, 0x0f                            ; Set color to 15
    mov cl, bl
    rep stosw                               ; Write to the doublebuffer
                                            ; 2x pixels per level

; =========================================== DRAW ENTITIES ====================

draw_entities:
    mov cx, MAX_ENTITIES                    ; Number of enemies to check
    mov si, ENTITIES                        ; Start index for positions
    .next:
        push cx                             ; Save counter
        push si                             ; Save position
        xor ax,ax                           ; Clear AX
        mov byte al, [si]                   ; Sprite frame
        cmp al, 0                           ; Check if it's not empty
        je .skip_this_one                   ; Skip if empty 
        mov word [SPRITE], ax               ; Set sprite frame
        mov ax, [TIMER]                     ; Get timer value
        and al, 2                           ; Limit to 0..1
        jnz .ok                             ; If 1, add frame
        add word [SPRITE], 7                ; Move to the second sprite frame
        .ok:
        mov byte al, [si+1]                 ; Get color
        mov byte [COLOR], al                ; Set color
        mov di, [SI+3]                      ; Get position
        .move_player_and_enemies:
            cmp byte [SPRITE], SPRITE_SPIDER; Check if it's a spider
            ja .draw_entitie                ; Do not move if not a spider
            .move_entitie_forward:
                xor ax,ax                   ; Clear AX
                mov al, [si+2]              ; Direction  
                mov si, ax                  ; Set SI to direction
                shl si, 1                   ; Shift left
                add di, [MLT + si]          ; Movement Lookup Table
                cmp di, SCREEN_BUFFER_SIZE  ; Check if out of bounds
                jb .draw_entitie            ; No clip below
                and di, SCREEN_BUFFER_SIZE  ; Clip screen size 
        .draw_entitie:
            push di                         ; Save position
            mov byte BL, [COLOR]            ; Set color
            mov si, sprites                 ; Set sprites data position
            add word si, [SPRITE]           ; Shift to the current sprite
            call draw_sprite                ; Draw the sprite
            pop di                          ; Restore position


        .skip_this_one:                     ; Jump to here to pop si, cx
                                            ; wihtout additional code
        pop si                              ; Restore position
        mov word [si+3], di                 ; Save new, updated position

        .random_rotate:
            mov ax, [TIMER]                 ; Get timer value
            add ax, di                      ; Add position
            and ax, 66                      ; Wait until 66
            jg .skip
            mov byte al, [TIMER]            ; Get random number
            add ax, si                      ; Add memory position
            and al, 7                       ; Clip rotation 0..7
            mov byte [si+2], al             ; Save direction
            .skip:
        add si, 5                           ; Move to the next entitie data
        pop cx
        loop .next
 
; =========================================== COLLISION CHECKING ===============

check_collisions:
    mov di, [PLAYER+3]                      ; Get player position
    mov bx, SPRITE_LINES                    ; Number of rows to check
    .check_row:     
        mov cx, 8                           ; Number of columns to check
        mov si, di                          ; Set SI to player position
        .check_column:      
            mov al, [es:si]                 ; Get pixel color at player position
            cmp al, COLOR_SPIDER            ; Check if it matches spider color
            je .collision_spider            ; Jump if collision with spider
            cmp al, COLOR_FLOWER            ; Check if it matches flower color
            je .collision_flower            ; Jump if collision with flower
            inc si                          ; Move to the next column
        loop .check_column      
        add di, 320                         ; Move to the next row
    dec bx                                  ; Decrement row counter
    jnz .check_row
    jmp .collision_done                     ; No collision

    .collision_flower:
        jmp next_level                      ; Advance to the next level

    .collision_spider:
        mov word [PLAYER+3], SCREEN_CENTER  ; Reset player position
        dec byte [LIFE]                     ; Decrease life
        jnz .collision_done                 ; If lifes left, continue
        .waint_for_esc:                     ; If no lifes left, wait for ESC
            in al, 60h                      ; Read keyboard
            cmp al, 0x01                    ; Check if ESC key is pressed
            jne .waint_for_esc
        jmp restart_game

    .collision_done:

; =========================================== PLAYER MOVEMENT ==================

handle_player:
    mov di, [PLAYER+3]                      ; Position
    mov byte bl, [PLAYER+1]                 ; Color
    mov byte al, [PLAYER+2]                 ; Rotation
    mov ah, 0                               ; Clear AH
    mov si, ax                              ; Set SI to rotation
    shl si, 1                               ; Shift left
    add di, [MLT + si]                      ; Movement Lookup Table
    add di, [MLT + si]                      ; Second time for faster movement
    mov word [PLAYER+3], DI                 ; Save new position
    mov si, sprites+SPRITE_FLY              ; Sprite
    mov byte al, [TIMER]                    ; Get random number
    and al, 2                               ; Last bit  
    jnz .ok                                 ; If 1, add frame
    add si, 7                               ; Move to the second srite frame
    .ok:
    call draw_sprite                        ; Draw player sprite

; =========================================== DRAW LIFES =======================

    mov byte cl, [LIFE]                     ; Set lifes
    sub di, 320*9                           ; Move to the top
    mov ax, 0x040c                          ; Set color to red and light red
    rep stosw                               ; Write to the doublebuffer 
                                            ; 2x pixels per life

; =========================================== KEYBOARD INPUT ===================

handle_keyboard:
    in al, 60h                              ; Read keyboard
    cmp al, 0x39                            ; Check if Spacebar is pressed
    jne .no_rotate
        inc byte [PLAYER+2]                 ; Move rotation clockvise
        and byte [PLAYER+2], 7              ; Limit 0..7
    .no_rotate:

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

%ifdef IS_286
%else
delay_timer:
    mov ax, [TIMER]                         ; Get current timer value
    inc ax                                  ; Increment it by 1 cycle (42ms)
    .wait:
        cmp [TIMER], ax                     ; Compare with the current timer
        jl .wait                            ; Loop until equal

%endif

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

MLT dw -320,-319,1,321,320,319,-1,-321      ; Movement Lookup Table
sprites:
db 0x60, 0x96, 0x49, 0x32, 0x5C, 0x7D, 0x1E ; Fly sprite frame 0
db 0x00, 0x00, 0x1E, 0x72, 0x5C, 0x7D, 0x1E ; Frame 1
db 0x06, 0x77, 0xAF, 0xFE, 0x2A, 0x49, 0x49 ; Spider sprite frame 0
db 0x06, 0x77, 0xAF, 0xFE, 0x2B, 0xD4, 0x14 ; Frame 1
db 0x1C, 0x36, 0x1C, 0x48, 0x3F, 0x08, 0x08 ; Flower sprite frame 0
db 0x38, 0x6C, 0x38, 0x09, 0x7E, 0x08, 0x08 ; Frame 1

; =========================================== BOOTSECTOR =======================

times 507 - ($ - $$) db 0                   ; Pad remaining bytes
db 'P1X'                                    ; P1X signature 3b
dw 0xAA55                                   ; Boot signature    