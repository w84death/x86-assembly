; GAME 2 - Ganja Farmer in Boot Sector!
; by Krzysztof Krystian Jankowski ^ P1X
;

[bits 16]
[org 0x7c00]

; ======== SETTINGS ========

BUFFER equ 0x1000
TIMER equ 046Ch
SPRITE_WIDTH equ 5
SPRITE_HEIGHT equ 8
SPRITE_COLOR equ 15
COLOR_WEED equ 72
COLOR_GROUND equ 102
COLOR_DUDE equ 36
COLOR_MIL equ 41
COLOR_SHADOW equ 78
COLOR_CLOUD equ 30
SKY_NIGHT equ 174
SKY_DAY equ 78
SPRITE_WEED equ 0
SPRITE_DEAD_WEED equ 1
SPRITE_DUDE equ 2
SPRITE_CLOUD equ 3
SPRITE_CLOUD2 equ 4
SPRITE_CLOUD3 equ 5

FIELD_POS equ 320*176+80
DUDE_POS equ 320*160+155

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

draw_sky:
    xor di,di           ; Reset buffer pos to 0
    mov cx, 10           ; Gradient levels
    mov bx, SKY_DAY
    .next_color:
        push cx                  ; Save outer loop counter
        mov cx, 20               ; Band size
        mov dx, 320
        add bl, 2
        mov al, bl
    .draw_grad_line:
        push cx                  ; Save inner loop counter
        mov cx, dx               ; Set CX to 320 for rep stosb
        rep stosb
        pop cx
        loop .draw_grad_line
        pop cx 
        dec bx
        loop .next_color

draw_ground:
    mov di, 320*150
    mov cx, 30           ; Gradient levels
    mov bx, COLOR_GROUND
    .draw_grad_line:
        push cx                  ; Save inner loop counter
        mov al, bl
        mov cx, dx               ; Set CX to 320 for rep stosb
        rep stosb
        pop cx
        loop .draw_grad_line


; ======== DRAWING SPRITES ========


; Draw weed field
draw_field:
    mov word [sprite_pos],  FIELD_POS
    mov di, ax
    mov si, level_data

    mov cx, 2
    .row
        push cx
        push ax
         

        mov cx, 8
        .column:
            push cx
            push si
            
            lodsb                   ; Load byte into AL and increment SI
            and al, [pixel_mask]      ; Test the leftmost bit
            cmp al, [pixel_mask]
            jnz .dead_plant    
            mov bx, SPRITE_WEED
            jmp .draw
            .dead_plant:
            mov bx, SPRITE_DEAD_WEED
            .draw
            add word [sprite_pos], 10
            mov byte [sprite_color], COLOR_WEED
            
            call draw_sprite
            
            shr byte [pixel_mask], 1

            pop si
            pop cx
            loop .column
        
        mov byte [pixel_mask], 10000000b
        inc si
        pop ax
        inc ax
        pop cx
        loop .row

   
    mov word [sprite_pos], DUDE_POS
    mov bx, SPRITE_DUDE
    mov byte [sprite_color], COLOR_DUDE
    call draw_sprite

    mov word [sprite_pos], DUDE_POS
    sub word [sprite_pos], 320*12
    mov bx, SPRITE_CLOUD
    mov byte [sprite_color], COLOR_CLOUD
    call draw_sprite

    mov word [sprite_pos], DUDE_POS
    sub word [sprite_pos], 320*24
    mov bx, SPRITE_CLOUD2
    mov byte [sprite_color], COLOR_CLOUD
    call draw_sprite

    mov word [sprite_pos], DUDE_POS
    sub word [sprite_pos], 320*48
    mov bx, SPRITE_CLOUD3
    mov byte [sprite_color], COLOR_CLOUD
    call draw_sprite

    ; ======== KEYBOARD ========

    .handle_keyboard:
        mov ah, 0x01            ; Check if a key has been pressed
        int 0x16
        jz .no_kb               ; Jump if no key is in the keyboard buffer
        xor ax,ax            ; Get the key press
        int 0x16
        
        ; REMOVE ME
        ; cmp ah, 0x01            ; Check if the scan code is for the [Esc] key
        ; je  restart_game
        ; cmp ah, 0x1C            ; Check if the scan code is for the [Enter] key
        ; je  next_level
        ; /REMOVE ME


    .no_kb:


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
sprite_pos dw 320*180+80   ; Middle of the screen
sprite_color db 15
pixel_mask db 10000000b

level_data:
    db 11001101b
    db 01111110b


sprites:
    db 00101000b    ; Weed
    db 11000101b
    db 00111111b
    db 01001001b
    db 01010000b

    db 00000010b    ; Dead Weed
    db 00000101b
    db 00000111b
    db 00000101b
    db 00000000b

    db 00000100b    ; Dude
    db 11101011b
    db 10111110b
    db 11101011b
    db 00000100b

    db 00000000b    ; Cloud Small
    db 00010000b
    db 00101000b
    db 00010000b
    db 00000000b

    db 00000100b    ; Cloud Big
    db 00001010b
    db 00011101b
    db 00001110b
    db 00000100b

    db 00111100b    ; Cloud Bigger
    db 01101010b
    db 11110101b
    db 01111010b
    db 00011100b

; ======== LEVELS ========


; ======== BOOTSECTOR  ========

times 506 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X', 0            ; P1X signature 4b
dw 0xAA55                  ; Boot signature at the end of 512 bytes