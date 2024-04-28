; GAME 2 - Ganja Farmer 512b
; by Krzysztof Krystian Jankowski ^ P1X
;

[bits 16]
[org 0x7c00]

; ======== SETTINGS ========

SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200
SPRITE_WIDTH equ 5
SPRITE_HEIGHT equ 8
MAX_ENEMIES equ 16
MAX_BULLETS equ 12
BULLET_SPEED equ 4
COOLDOWN_WEAPON_TIME equ 2
COOLDOWN_ENEMY_TIME equ 128
FIELD_POS equ 320*160+60
SPRITE_DUDE equ 0
SPRITE_HELI equ 1
SPRITE_MARINE equ 2
COLOR_SKY equ 77    ; Blue
COLOR_WEED equ 192  ; Darkest green
COLOR_GRASS equ 45  ; Light green
COLOR_DUDE equ 16*9-12   ; Brownish
COLOR_MIL equ 16*7+14     ; Dark green
COLOR_HELI equ 32   ; White gradient

; ======== MEMORY MAP ========

VGA equ 0xA000
TIMER equ 0x046C                ; BIOS timer
MEM_BASE equ 0x1000
LIFE equ MEM_BASE               ; 1 bytes
PIXEL_MASK equ MEM_BASE+2       ; 2 bytes
PLAYER_POS equ MEM_BASE+4       ; 2 bytes
SPRITE_COLOR equ MEM_BASE+6     ; 2 bytes
SPRITE_POS equ MEM_BASE+8       ; 2 bytes
PLAYER_DIR equ MEM_BASE+10      ; 2 bytes
COOLDOWN_WEAPON equ MEM_BASE+12 ; 2 bytes
COOLDOWN_ENEMY equ MEM_BASE+14  ; 2 bytes
ENEMIES equ MEM_BASE+16         ; 32 bytes
BULLETS equ MEM_BASE+48         ; 64 bytes

; ======== GRAPHICS INITIALIZATION ========

start:
    xor ax,ax    ; Init segments
    mov ds, ax
    mov ax, VGA
    mov es, ax
    mov ax, 13h     ; Init VGA 
    int 10h

; ======== GAME RESET/INIT ========

game_reset:
    xor ax, ax          ; Clear AX register (value 0x0)
    mov si, MEM_BASE
    mov cx, 64          ; Number of iterations (64 bytes)
    write_loop:
        mov word [si], ax       ; Write zero to the memory location
        inc si                  ; Move to the next memory address
        loop write_loop         ; Repeat until all 64 bytes are written

    mov byte [LIFE], 16
    mov word [PIXEL_MASK], 0x8000
    mov word [PLAYER_POS], 320*180+160
    mov word [COOLDOWN_ENEMY], COOLDOWN_ENEMY_TIME*4

; ======== GAME LOOP  ========

game_loop:

; ======== DRAWING SKY / GROUND ========

draw_bg:
    xor di, di                  ; Reset DI
    mov cx, SCREEN_WIDTH*125    ; Repeat 125 lines
    mov al, COLOR_SKY           ; Set color to sky
    rep stosb                   ; Push line to screen buffer
    mov cx, SCREEN_WIDTH*75    ; Repeat 125 lines
    mov al, COLOR_GRASS           ; Set color to sky
    rep stosb                   ; Push line to screen buffer 

; ======== DRAWING FIELD ========
    
draw_field:
    mov word [SPRITE_POS], FIELD_POS
    mov byte cl, 16                 ; Level size = columns
    .next_column:
        push cx                     ; Save counter
        mov bx, SPRITE_DUDE-24      ; Get random data for weed sprite
        xor bx, cx                  ; Shuffle data
        mov byte [SPRITE_COLOR], COLOR_WEED
        cmp byte [LIFE], cl
        jbe .skip
        call draw_sprite
        .skip:
        add word [SPRITE_POS], 12   ; Move next sprite by 12px
        pop cx                      ; Load counter
        loop .next_column                ; Loop to next column

    cmp byte [LIFE], 1              ; Check if lifes available
    jb game_reset
    
; ======== PLAYER LOGIC ========

move_player:
    cmp byte [PLAYER_DIR], 0
    je .move_right
    .move_left:
        dec word [PLAYER_POS]
        dec word [PLAYER_POS]
        jmp .done_move
    .move_right:
        inc byte [PLAYER_POS]
        inc byte [PLAYER_POS]
    .done_move:
        cmp byte [PLAYER_POS], 70
        jge .finish
        cmp byte [PLAYER_POS], 245
        jle .finish
        xor byte [PLAYER_DIR], 1
    .finish:

; ======== DRAWING PLAYER ========

draw_player:
    mov ax, [PLAYER_POS]
    mov word [SPRITE_POS], ax
    mov bx, SPRITE_DUDE
    mov byte [SPRITE_COLOR], COLOR_DUDE
    call draw_sprite

; ======== DRAWING & LOGIC ENEMIES ========

draw_enemies:
    mov si, ENEMIES
    mov cx, MAX_ENEMIES
    .draw_next_enemy:
        push cx
        lodsw 
        cmp ax, 320*160     ; Marine landed y=160 px
        ja .spawn_enemy
        cmp ax,0
        jz .try_spawn
        cmp ax, 320*32      ; Heli vs Marine y line
        mov bx, SPRITE_HELI
        ja .enemy_marine
        .enemy_heli:
            mov cx, 4   ; Move right 2px
            mov byte [SPRITE_COLOR], COLOR_HELI ; Color
            .move_down:
                mov dx, [TIMER]
                and dx, 8
                cmp dx, 8
                jnz .ok
                add cx, 320
                .ok:
            jmp .update_pos
        .enemy_marine:
            inc bx      ; Marine sprite (next)
            mov cx, 640 ; Move down 2px
            mov byte [SPRITE_COLOR], COLOR_MIL ; Color
        .update_pos:
            add ax, cx  ; Update pos
            mov word [si-2], ax ; Save pos to memory
        .draw:
            mov word [SPRITE_POS], ax   ; Set sprite position
            push si
            call draw_sprite                    ; Send colors to frame BULLETS_BUFFER
            pop si
            jmp .next
        .spawn_enemy:
            cmp ax, 0xFFFF
            jz .try_spawn
            dec byte [LIFE]
            mov word [si-2], 0xFFFF
            .try_spawn:
                cmp word [COOLDOWN_ENEMY], 1
                dec word [COOLDOWN_ENEMY]
                ja .next
            .reset_enemy_pos:
                mov word [COOLDOWN_ENEMY], COOLDOWN_ENEMY_TIME
                mov word [si-2], 320*10
        .next:
        
        pop cx
        loop .draw_next_enemy
    .done:


; ======== WEAPON COOLDOWN_WEAPON LOGIC ========

update_weapon_cooldown:    
    cmp word [COOLDOWN_WEAPON], 0
    je .finish
    dec word [COOLDOWN_WEAPON]
    .finish:

; ======== DRAWING & LOGIC BULLETS ========

draw_bullets:
    mov si, BULLETS
    mov cx, MAX_BULLETS
    .next_bullet:
        push cx
        lodsw                   ; Load position from memory
        cmp ax, 320*4           ; Check top of the screen
        ja .update_pos          ; Bigger Y, just move
        .spawn_new_bullet:
            cmp word [COOLDOWN_WEAPON], 0  ; Check COOLDOWN_WEAPON
            ja .skip_bullet         ; Not yet. Skip
            .new_bullet:            ; Spawn new bullet
                mov word [COOLDOWN_WEAPON], COOLDOWN_WEAPON_TIME
                mov ax, [PLAYER_POS]
                mov word [si-2], ax ; Update pos in memory
        .update_pos:
            sub ax, 320*BULLET_SPEED       ; Moove by 3px up
            mov word [si-2], ax ; Update pos in memory
            
        .check_collision:
            mov dx, ax          ; Save bullet pos
            add dx, 320*8       ; Bottom of the sprite
            pusha
            mov si, ENEMIES
            mov cx, MAX_ENEMIES
            .enemy_check_loop:
            lodsw               ; Read enemy
            sub ax, dx          ; 
            cmp ax, 8          ; Check hit
            ja .next
            mov word [si-2], 0 ; Kill enemy
            .next:
            loop .enemy_check_loop             
            popa
        .draw:
            pusha
            mov si, VGA
            mov di, ax  ; Position
            xor ax,ax   ; Color black
            mov word [es:di], ax  ; Write 2 pixels to video memory
            popa
        .skip_bullet:
    pop cx
    loop .next_bullet

; ======== CHECKING KEYBOARD ========

handle_keyboard:
    mov ah, 0x01            ; Check if a key has been pressed
    int 0x16
    jz .no_move               ; Jump if no key is in the keyboard BULLETS_BUFFER
    xor ax,ax            ; Get the key press
    int 0x16
    .test_left:
    cmp ah, 0x4B    ; Left
    jne  .test_right
    mov byte [PLAYER_DIR], 1
    .test_right:
    cmp ah, 0x4D    ; Right
    jne .no_move
    mov byte [PLAYER_DIR], 0
    .no_move:


; ======== DELAY CYCLE ========

delay_timer:
    mov ax, [TIMER]
    inc ax
    .wait:
        cmp [TIMER], ax
        jl .wait

jmp game_loop

game_over:

; ======== END GAME LOOP ========

; ======== PROCEDURES ========

draw_sprite:
    mov di, [SPRITE_POS]              ; Store in DI for ES:DI addressing
    mov cx, SPRITE_HEIGHT               ; Number of rows (each byte is a row in this example)
    mov byte [PIXEL_MASK], 0x80 ; 8 positions
   
    .draw_row:
        push cx                 ; Save CX (rows left)
        mov ax, SPRITE_WIDTH    
        mul bx                  ; sprite width * sprite number
        mov si, sprites
        add si, ax              ; SI points to the start of the sprite data
        mov cx, SPRITE_WIDTH       ; rows
        xor ah, ah               ; Clear AH to use it for bit testing
        .read_pixel:
            lodsb                   ; Load byte into AL and increment SI
            and al, [PIXEL_MASK]      ; Test the leftmost bit
            cmp al, [PIXEL_MASK]
            jnz .next_pixel          ; If the bit is 0, skip drawing
        .draw_pixel:
            xor ax,ax
            mov byte al, [SPRITE_COLOR]    ; Apply XOR with sprite color to AX
            mov ah, al
            mov word [es:di], ax         ; Write back to video memory
        .next_pixel:
            inc di                  ; Move to next pixel in the row
            inc di
            loop .read_pixel        ; Repeat for each bit in the byte
            shr byte [PIXEL_MASK], 1 ; Shift left to test the next bit
            add di, 320 - SPRITE_WIDTH*2         ; Move DI to the start of the next line (assuming screen width is 320 pixels)
            dec byte [SPRITE_COLOR]
        pop cx                  ; Restore CX (rows left)
        loop .draw_row          ; Process next row
    ret

; ======== SPRITES ========

sprites:
db 01100000b    ; Dude
db 00010011b 
db 10111100b
db 11111111b
db 00001100b    

db 01001000b    ; Heli
db 01001000b    
db 01011100b
db 01011100b
db 01011100b

db 01110000b    ; Marine
db 11001011b
db 10011100b
db 11001011b
db 01110000b

; ======== BOOTSECTOR  ========

times 507 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X'            ; P1X signature 4b
dw 0xAA55