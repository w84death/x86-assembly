; GAME 2 - Ganja Farmer in Boot Sector!
; by Krzysztof Krystian Jankowski ^ P1X
;

[bits 16]
[org 0x7c00]

; ======== SETTINGS ========

BUFFER equ 0x1000
TIMER equ 046Ch
SPRITE_WIDTH equ 4
SPRITE_HEIGHT equ 8
SPRITE_COLOR equ 15

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

    ; ======== DRAW SKY ========

    draw_sky:
        xor di,di           ; Reset buffer pos to 0
        mov cx, 10           ; Gradient levels
        .draw_gradient:
        mov bx, 141    ; Sky starting color
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



    ; ======== DRAWING SPRITES ========


mov ax,word [sprite_pos]
push ax                     ; Save initial sprite position

mov bx, 0               ; Sprite id
call draw_sprite

add word [sprite_pos], 10
mov bx, 0               ; Sprite id
call draw_sprite

add word [sprite_pos], 10
mov bx, 1               ; Sprite id
call draw_sprite

add word [sprite_pos], 10
mov bx, 2              ; Sprite id
call draw_sprite

pop ax
mov word [sprite_pos], ax   ; Load initial sprite position













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
    mov ax, 4               ; Sprite offset (assuming 4 bytes per sprite)
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
    mov al, SPRITE_COLOR    ; Apply XOR with sprite color to AX
    mov [es:di], ax         ; Write back to video memory
.next_pixel:
    inc di                  ; Move to next pixel in the row
    loop .read_pixel        ; Repeat for each bit in the byte
    shr byte [pixel_mask], 1 ; Shift left to test the next bit
    add di, 316         ; Move DI to the start of the next line (assuming screen width is 320 pixels)
    pop cx                  ; Restore CX (rows left)
    loop .draw_row          ; Process next row
ret

; ======== DATA ========

.data:
sprite_pos dw 320*100+160   ; Middle of the screen
pixel_mask db 10000000b
level_data dw 0xFF

sprites:
    db 0xD4, 0x7F, 0x4C, 0x10   ; Weed

    db 11111111b    ; FF
    db 11111111b    ; FF
    db 11111111b    ; FF
    db 11111111b    ; FF

    db 11111111b    ; FF
    db 10000001b    ; FF
    db 10000001b    ; FF
    db 11111111b    ; FF

; ======== LEVELS ========


; ======== BOOTSECTOR  ========

times 506 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X', 0            ; P1X signature 4b
dw 0xAA55                  ; Boot signature at the end of 512 bytes