[bits 16]
[org 0x7c00]

TIMER equ 046Ch
BUFFER equ 0x1000       ; 64000
MEM_BASE equ 0x7e00
LEVEL_DATA equ MEM_BASE   ; 2 
PIXEL_MASK equ MEM_BASE+2   ; 2
PLAYER_POS equ MEM_BASE+4   ; 2
SPRITE_COLOR equ MEM_BASE+6 ; 2
SPRITE_POS equ MEM_BASE+8  ; 2
PLAYER_DIR equ MEM_BASE+10 ; 2
BULLETS equ MEM_BASE+12      ; 64


; ======== SETTINGS ========

SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200

SPRITE_WIDTH equ 5
SPRITE_HEIGHT equ 8

MAX_BULLETS equ 64

COLOR_WEED equ 72
COLOR_GROUND equ 42
COLOR_GRASS equ 43
COLOR_DUDE equ 36
COLOR_MIL equ 41
COLOR_SHADOW equ 78
COLOR_CLOUD equ 30
COLOR_BUS equ 45 ; 36
COLOR_SKY equ 76
COLOR_HELI equ 32

SPRITE_WEED equ 0
SPRITE_DEAD_WEED equ 1
SPRITE_DUDE equ 2
SPRITE_MARINE equ 3
SPRITE_PARASHUTE equ 4
SPRITE_BUS equ 6
SPRITE_HELI equ 5

FIELD_POS equ 320*160+80
DUDE_POS equ 320*174+155
BUS_POS equ 320*182+150

; ======== GRAPHICS INITIALIZATION ========

start:
    mov ax, 0x0000    ; Init segments
    mov ds, ax
    mov ax, 0xA000
    mov es, ax
    mov ax, 13h     ; Init VGA 
    int 10h
    
    mov ax, BUFFER
    mov es, ax

game_reset:
mov word [LEVEL_DATA], 0xFFFF
mov word [PIXEL_MASK], 0x8000
mov word [PLAYER_POS], 320*180+160

; ======== GAME LOOP  ========

game_loop:

; ======== DRAW SKY / GROUND ========

draw_bg:
    xor di, di              ; Reset DI
    mov cx, SCREEN_HEIGHT   ; Repeat for full screen height
    
    .draw_line:
                            ; Decide on start color
    mov bx, COLOR_SKY       ; Set color to sky
    ; cmp cx, 75              ; Check vertical postion
    ; jge .continue           ; Not yet, continue sky
    ; mov bx, COLOR_GRASS     ; Else it's grass

    ; .continue:
                            ; Gradient
    mov ax, cx              ; Copy line number to AX
    and ax, 0xFF            ; Clear all but 0xFF
    shr ax, 4               ; Shift 4 times = div by 16 (200/16 = 12px band)
    add bx, ax              ; Shift current color intex (BX)

                            ; Drawing
    push cx                 ; Save loop counter
    mov al, bl              ; Set color (from BX)
    mov cx, SCREEN_WIDTH    ; Set length (full screen width line)
    rep stosb               ; Send colors to frame buffer
    pop cx                  ; Load loop counter
    loop .draw_line

; ======== DRAWING SPRITES ========
    
; Draw weed field
draw_field:
    mov word [SPRITE_POS], 320*160+80
    mov word [PIXEL_MASK], 0x8000   ; 16 positions
    mov cx, 16  ; Level size
    .column:
        push cx
   
        mov dx, [LEVEL_DATA]
        mov ax, dx                ; Load byte into AL and increment SI
        and ax, [PIXEL_MASK]      ; Test the leftmost bit
        cmp ax, [PIXEL_MASK]
            jnz .dead_plant           ; 0 - plant alive, 1 - plant dead
            mov bx, SPRITE_WEED
            jmp .draw    
        .dead_plant:
            mov bx, SPRITE_DEAD_WEED
        .draw:
        mov byte [SPRITE_COLOR], COLOR_WEED
        call draw_sprite
        add word [SPRITE_POS], 10
        shr word [PIXEL_MASK], 1
        
        pop cx
        loop .column
        
   
    move_player:

    cmp byte [PLAYER_DIR], 0
    je .move_right
        dec word [PLAYER_POS]
        dec word [PLAYER_POS]
        ; add byte [player_pos], 4
    jmp .done
    .move_right:
        inc byte [PLAYER_POS]
        inc byte [PLAYER_POS]
        ; sub byte [player_pos], 4
    .done:


    cmp byte [PLAYER_POS], 80
    jge .continue
    cmp byte [PLAYER_POS], 240
    jle .continue
    
    xor byte [PLAYER_DIR], 1
    
    .continue:

    draw_player:
    mov ax, [PLAYER_POS]
    mov word [SPRITE_POS], ax
    mov bx, SPRITE_DUDE
    mov byte [SPRITE_COLOR], COLOR_DUDE
    call draw_sprite

    
    mov cx, 4
    draw_enemy:
        push cx
        
        draw_heli:    
        mov cx, 2               ; 2 sprites
        mov bx, SPRITE_HELI     ; First sprite
        xor ax, ax              ; Clear AX
        draw_heli_sprite:
            push cx             ; Save loop counter
            push ax             ; Save shift
            mov word cx, 320*10
            mov word [SPRITE_POS], cx           ; Position
            add word [SPRITE_POS], ax           ; Add shift
            mov byte [SPRITE_COLOR], COLOR_HELI ; Color
            call draw_sprite                    ; Send colors to frame buffer
            inc bx              ; Change to next sprite
            pop ax              ; Get shift
            add ax, 5           ; Move 5px (for next sprite)
            pop cx              ; Load loop counter
            loop draw_heli_sprite
    
        pop cx
        loop draw_enemy


mov si, BULLETS
mov cx, MAX_BULLETS
draw_bullets:
push cx
    lodsw 

    cmp ax, 320
    ja .next
        mov ax, [PLAYER_POS]
        mov word [si-2], ax
        jmp .done
    .next:

    sub ax, 320
    mov word [si-2], ax

    push si
    push di
    mov si, BUFFER
    mov di, ax
    xor ax,ax
    mov [es:di], ax         ; Write back to video memory
    pop di
    pop si
    
pop cx
loop draw_bullets
.done:
    ; ======== KEYBOARD ========

    handle_keyboard:
        mov ah, 0x01            ; Check if a key has been pressed
        int 0x16
        jz .no_move               ; Jump if no key is in the keyboard buffer
        xor ax,ax            ; Get the key press
        int 0x16
        .test_left:
        cmp ah, 0x4B    ; Left
        jne  .test_right
        ; shl word [player_slot], 1
        mov byte [PLAYER_DIR], 1
        .test_right:
        cmp ah, 0x4D    ; Right
        jne .no_move
        ; shr word [player_slot], 1
        mov byte [PLAYER_DIR], 0
        .no_move:



    ; ======== BLIT ========

    blit:
        push es
        push ds
        mov ax, 0xA000  ; VGA memory
        mov bx, BUFFER  ; Buffer memory
        mov es, ax
        mov ds, bx
        mov cx, 32000   ; Half of the buffer
        xor si, si
        xor di, di
        rep movsw
        pop ds
        pop es

    ; ======== DELAY ========

    delay_timer:
        mov ax, [TIMER]
        inc ax
        .wait:
            cmp [TIMER], ax
            jl .wait

jmp game_loop

; ======== PROCEDURES ========

draw_sprite:
    mov ax, [SPRITE_POS]    ; Load sprite position (assuming it's a byte offset)
    mov di, ax              ; Store in DI for ES:DI addressing
    mov cx, SPRITE_HEIGHT               ; Number of rows (each byte is a row in this example)
    mov byte [PIXEL_MASK], 0x80 ; 8 positions
   
.draw_row:
    push cx                 ; Save CX (rows left)
    cmp cx, 5
    jge .last_color
    dec byte [SPRITE_COLOR]
    .last_color:
    
    mov ax, SPRITE_WIDTH               ; Sprite offset (assuming 4 bytes per sprite)
    mul bx                  ; AX = 4 * sprite number
    mov si, sprites
    add si, ax              ; SI points to the start of the sprite data
    mov cx, SPRITE_WIDTH              ; rows
    mov ah, 0               ; Clear AH to use it for bit testing
.read_pixel:
    lodsb                   ; Load byte into AL and increment SI
    and al, [PIXEL_MASK]      ; Test the leftmost bit
    cmp al, [PIXEL_MASK]
    jnz .next_pixel          ; If the bit is 0, skip drawing
.draw_pixel:
    xor ax,ax
    mov byte al, [SPRITE_COLOR]    ; Apply XOR with sprite color to AX
    mov [es:di], ax         ; Write back to video memory
.next_pixel:
    inc di                  ; Move to next pixel in the row
    loop .read_pixel        ; Repeat for each bit in the byte
    shr byte [PIXEL_MASK], 1 ; Shift left to test the next bit
    add di, 320 - SPRITE_WIDTH         ; Move DI to the start of the next line (assuming screen width is 320 pixels)
    pop cx                  ; Restore CX (rows left)
    loop .draw_row          ; Process next row
ret

; ======== SPRITES ========

sprites:
db 00101000b    ; Weed
db 11000100b
db 00111111b
db 01001000b
db 01010000b

db 00000011b    ; Dead Weed
db 00000001b
db 00001111b
db 00000011b
db 00000001b

db 00000100b    ; Dude
db 11101011b
db 10111110b
db 11101011b
db 00000100b

db 00000000b    ; Marine
db 00000000b
db 00000000b
db 00000000b
db 00000000b

db 00000000b    ; Parashute
db 00000000b
db 00000000b
db 00000000b
db 00000000b

db 00011100b    ; Heli
db 10001000b
db 10001000b
db 10011000b
db 10111100b
db 01111100b
db 10101100b
db 10101100b
db 10011000b
db 10000000b

; ======== BOOTSECTOR  ========

times 507 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X'            ; P1X signature 4b
dw 0xAA55