; GAME 2 - Ganja Farmer in Boot Sector!
; by Krzysztof Krystian Jankowski ^ P1X
;

[bits 16]
[org 0x7c00]

; ======== SETTINGS ========

BUFFER equ 0x1000
TIMER equ 046Ch
SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200
SPRITE_WIDTH equ 5
SPRITE_HEIGHT equ 8

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


; ======== GAME LOOP  ========

game_loop:

; ======== DRAW SKY / GROUND ========

draw_bg:
    xor di, di              ; Reset DI
    mov cx, SCREEN_HEIGHT   ; Repeat for full screen height
    
    .draw_line:
                            ; Decide on start color
    mov bx, COLOR_SKY       ; Set color to sky
    cmp cx, 75              ; Check vertical postion
    jge .continue           ; Not yet, continue sky
    mov bx, COLOR_GRASS     ; Else it's grass
    ; cmp cx, 20              ; Check ground
    ; jge .continue           ; Not yet, continue grass
    ; mov bx, COLOR_GROUND    ; Else it's ground
    .continue:
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
    xor ax,ax
    mov word [sprite_pos],  FIELD_POS
    mov di, ax
    mov si, level_data
    lodsw       ; Load level data
    mov dx,ax   ; Save in DX
    mov word [pixel_mask], 1000000000000000b
    mov cx, 16  ; Level size
    .column:
        push cx
            
        mov ax, dx                ; Load byte into AL and increment SI
        and ax, [pixel_mask]      ; Test the leftmost bit
        cmp ax, [pixel_mask]
        jnz .dead_plant           ; 0 - plant alive, 1 - plant dead
        mov bx, SPRITE_WEED
        jmp .draw
        .dead_plant:
        mov bx, SPRITE_DEAD_WEED
        .draw:
        add word [sprite_pos], 10
        mov byte [sprite_color], COLOR_WEED
        push dx     ; Save level data
        call draw_sprite
        pop dx      ; Load level data
        shr word [pixel_mask], 1
        pop cx
        loop .column
        
   
    move_player:

    cmp byte [player_dir], 0
    je .move_right
        dec byte [player_pos]
        dec byte [player_pos]
        ; add byte [player_pos], 4
    jmp .done
    .move_right:
        inc byte [player_pos]
        inc byte [player_pos]
        ; sub byte [player_pos], 4
    .done:


    cmp byte [player_pos], 0x01
    jge .continue
    cmp byte [player_pos], 0xA8
    jle .continue
    
    xor byte [player_dir], 1
    
    .continue:

    draw_player:
    mov ax, 320*180+80
    add al, [player_pos]
    mov word [sprite_pos], ax
    mov bx, SPRITE_DUDE
    mov byte [sprite_color], COLOR_DUDE
    call draw_sprite


    ; mov byte al, [player_pos]

    ; draw_bus:
    ; mov cx, 3               ; 3 sprites
    ; mov bx, SPRITE_BUS    ; First sprite
    ; xor ax, ax              ; Clear AX
    ; draw_bus_sprite:
    ;     push cx             ; Save loop counter
    ;     push ax             ; Save shift
    ;     mov word cx, 320*180+80
    ;     add cl, [player_pos]
    ;     add cx, 320*8-5
    ;     mov word [sprite_pos], cx      ; Position
    ;     add word [sprite_pos], ax           ; Add shift
    ;     mov byte [sprite_color], COLOR_BUS  ; Color
    ;     call draw_sprite                    ; Send colors to frame buffer
    ;     inc bx              ; Change to next sprite
    ;     pop ax              ; Get shift
    ;     add ax, 5           ; Move 5px (for next sprite)
    ;     pop cx              ; Load loop counter
    ;     loop draw_bus_sprite

    xor ax,ax
    mov ax, [enemy_pos]
    push ax

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
            mov word cx, [enemy_pos]
            mov word [sprite_pos], cx           ; Position
            add word [sprite_pos], ax           ; Add shift
            mov byte [sprite_color], COLOR_HELI ; Color
            call draw_sprite                    ; Send colors to frame buffer
            inc bx              ; Change to next sprite
            pop ax              ; Get shift
            add ax, 5           ; Move 5px (for next sprite)
            pop cx              ; Load loop counter
            loop draw_heli_sprite

        add byte [enemy_pos], 40

        pop cx
        loop draw_enemy

    pop ax
    inc ax
    mov word [enemy_pos], ax

xor ax,ax
mov si, bullets
mov cx, 6
draw_bullets:
push cx
    lodsb
    push ax
    mov bx, 320
    imul ax,bx
    mov di, ax
    add di, 80
    pop ax
    cmp ax, 2
    jle .skip

    ; reduse bullets life
    dec byte [si-1]
    dec byte [si-1]
    
    lodsb 
    add di, ax
    
    xor ax,ax
    mov [es:di], ax         ; Write back to video memory
    jmp .next
    .skip:
    
    mov byte [si-1], 178
    mov byte al, [player_pos]
    mov byte [si], al
    
    inc si
    ; spawn new bullet
    
    .next:
pop cx
loop draw_bullets

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
        mov byte [player_dir], 1
        .test_right:
        cmp ah, 0x4D    ; Right
        jne .no_move
        ; shr word [player_slot], 1
        mov byte [player_dir], 0
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
    mov ax, [sprite_pos]    ; Load sprite position (assuming it's a byte offset)
    mov di, ax              ; Store in DI for ES:DI addressing
    mov cx, SPRITE_HEIGHT               ; Number of rows (each byte is a row in this example)
    mov byte [pixel_mask], 10000000b
   
.draw_row:
    push cx                 ; Save CX (rows left)
    cmp cx, 5
    jge .last_color
    dec byte [sprite_color]
    .last_color:
    
    mov ax, SPRITE_WIDTH               ; Sprite offset (assuming 4 bytes per sprite)
    mul bx                  ; AX = 4 * sprite number
    mov si, sprites
    add si, ax              ; SI points to the start of the sprite data
    mov cx, SPRITE_WIDTH              ; rows
    mov ah, 0               ; Clear AH to use it for bit testing
.read_pixel:
    lodsb                   ; Load byte into AL and increment SI
    and al, [pixel_mask]      ; Test the leftmost bit
    cmp al, [pixel_mask]
    jnz .next_pixel          ; If the bit is 0, skip drawing
.draw_pixel:
    xor ax,ax
    mov byte al, [sprite_color]    ; Apply XOR with sprite color to AX
    mov [es:di], ax         ; Write back to video memory
.next_pixel:
    inc di                  ; Move to next pixel in the row
    loop .read_pixel        ; Repeat for each bit in the byte
    shr byte [pixel_mask], 1 ; Shift left to test the next bit
    add di, 320 - SPRITE_WIDTH         ; Move DI to the start of the next line (assuming screen width is 320 pixels)
    pop cx                  ; Restore CX (rows left)
    loop .draw_row          ; Process next row
ret

; ======== DATA ========

.data:
player_pos db 0x50
player_dir db 0
sprite_color db 0 ; Temporary sprite color
pixel_mask db 0,0 ; Mask for testing binary data
level_data dw 1111111111111111b
sprite_pos dw 0   ; Temporary sprite position
enemy_pos dw 320*10

; ======== BULLETS ========
bullets:
db 0,80
db 5,80
db 10,80
db 80,80
db 85,80
db 90,80

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

; db 01111110b    ; Zjarobus
; db 01011110b    
; db 01011101b
; db 01011101b
; db 01111110b
; db 01111110b    
; db 01011110b    ; Middle
; db 01011110b
; db 01011110b
; db 01111110b    
; db 01001110b    ; Front
; db 01001101b
; db 00101101b
; db 00011110b
; db 00000110b

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

times 506 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X', 0            ; P1X signature 4b
dw 0xAA55                  ; Boot signature at the end of 512 bytes