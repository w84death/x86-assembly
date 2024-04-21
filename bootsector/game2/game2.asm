[bits 16]
[org 0x7c00]

; ======== SETTINGS ========

BUFFER equ 0x1000
TIMER equ 046Ch

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
        ; cmp ah, 0x1C            ; Check if the scan code is for the [Esc] key
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

; ======== DATA ========

.data:
player_pos dw 0

sprites:
    db 11010100b
    db 00111111b
    db 01001100b
    db 00010000b


; ======== LEVELS ========


; ======== BOOTSECTOR  ========

times 506 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X', 0            ; P1X signature 4b
dw 0xAA55                  ; Boot signature at the end of 512 bytes